#!/bin/bash
# Sign a development IPA locally on macOS using an explicit per-bundle manifest.
set -euo pipefail
usage() {
  echo "Uso: P12_PASSWORD='...' $0 <unsigned.ipa> <identity.p12> <manifest.json> <output.ipa>" >&2
  exit 64
}
[[ $# -eq 4 ]] || usage
IPA_INPUT="$1"; P12="$2"; MANIFEST="$3"; OUTPUT="$4"
: "${P12_PASSWORD:?Defina P12_PASSWORD no ambiente; não passe a senha na linha de comando.}"
for f in "$IPA_INPUT" "$P12" "$MANIFEST"; do [[ -f "$f" ]] || { echo "Arquivo ausente: $f" >&2; exit 66; }; done
[[ "${IPA_INPUT##*.}" == "ipa" || "${IPA_INPUT##*.}" == "IPA" ]] || { echo "Entrada precisa ser .ipa" >&2; exit 65; }
for tool in security codesign ditto xcrun python3 openssl; do command -v "$tool" >/dev/null || { echo "Ferramenta ausente: $tool" >&2; exit 69; }; done
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/autorenew-sign.XXXXXX")"
KEYCHAIN="$WORK/autorenew-signing.keychain-db"
KEYCHAIN_PASSWORD="$(openssl rand -hex 24)"
cleanup() {
  security delete-keychain "$KEYCHAIN" >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT
mkdir -p "$WORK/unpacked"
# Inspect the ZIP central directory and reject traversal/symlink/oversized entries.
python3 "$ROOT/tools/validate-signing-inputs.py" --inspect-ipa "$IPA_INPUT"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
security set-keychain-settings -lut 900 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$P12" -k "$KEYCHAIN" -P "$P12_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security >/dev/null
security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
security list-keychains -d user -s "$KEYCHAIN"
security find-identity -v -p codesigning "$KEYCHAIN" > "$WORK/identities.txt"
ditto -x -k "$IPA_INPUT" "$WORK/unpacked"
PAYLOAD="$WORK/unpacked/Payload"
[[ -d "$PAYLOAD" ]] || { echo "IPA não contém Payload/." >&2; exit 65; }
# The manifest is JSON with bundles[{bundle_path,profile_path,entitlements_path}].
# All paths are relative to the manifest directory (profiles and plists may live outside the IPA).
MANIFEST_DIR="$(cd "$(dirname "$MANIFEST")" && pwd)"
python3 - "$MANIFEST" > "$WORK/bundles.tsv" <<'PY'
import json, os, sys
from pathlib import PurePosixPath
manifest_path = os.path.abspath(sys.argv[1])
root = os.path.dirname(manifest_path)
with open(manifest_path, encoding="utf-8") as f: doc = json.load(f)
bundles = doc.get("bundles")
if not isinstance(bundles, list) or not bundles: raise SystemExit("Manifesto precisa conter bundles[]")
seen = set()
for item in bundles:
    if not isinstance(item, dict): raise SystemExit("Entrada de bundle inválida")
    vals = [item.get(k) for k in ("bundle_path", "profile_path", "entitlements_path")]
    if not all(isinstance(v, str) and v and "\t" not in v and "\n" not in v for v in vals):
        raise SystemExit("Cada bundle precisa de bundle_path, profile_path e entitlements_path")
    bundle_path = PurePosixPath(vals[0])
    if bundle_path.is_absolute() or ".." in bundle_path.parts or "\\" in vals[0] or ":" in vals[0]:
        raise SystemExit("bundle_path precisa ser relativo e seguro")
    resolved = [os.path.realpath(os.path.join(root, v)) for v in vals[1:]]
    if any(os.path.commonpath([root, p]) != root for p in resolved):
        raise SystemExit("profile_path/entitlements_path precisam permanecer na pasta do manifesto")
    if vals[0] in seen: raise SystemExit("bundle_path duplicado")
    seen.add(vals[0])
    print("\t".join([vals[0], *resolved]))
PY
# Every app and app extension must have its own profile + least-privilege entitlements.
find "$PAYLOAD" -type d \( -name '*.app' -o -name '*.appex' \) -print | sed "s#^$WORK/unpacked/##" | sort > "$WORK/discovered-bundles.txt"
cut -f1 "$WORK/bundles.tsv" | sort > "$WORK/manifest-bundles.txt"
diff -u "$WORK/discovered-bundles.txt" "$WORK/manifest-bundles.txt" || {
  echo "Manifesto deve cobrir exatamente cada .app e .appex no IPA." >&2; exit 65;
}
IDENTITY=""
while IFS=$'\t' read -r REL_BUNDLE PROFILE ENTITLEMENTS; do
  BUNDLE="$WORK/unpacked/$REL_BUNDLE"
  [[ -d "$BUNDLE" && -f "$BUNDLE/Info.plist" && -f "$PROFILE" && -f "$ENTITLEMENTS" ]] || {
    echo "Bundle, perfil ou entitlements ausente para $REL_BUNDLE" >&2; exit 66;
  }
  # CMS signature is verified before decoding or trusting profile fields.
  security cms -V -i "$PROFILE"
  PROFILE_PLIST="$WORK/profile-$(printf '%s' "$REL_BUNDLE" | shasum | awk '{print $1}').plist"
  security cms -D -i "$PROFILE" > "$PROFILE_PLIST"
  BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$BUNDLE/Info.plist")
  MATCHED_ID="$(python3 "$ROOT/tools/validate-signing-inputs.py" \
    --profile "$PROFILE_PLIST" --app-info "$BUNDLE/Info.plist" \
    --entitlements "$ENTITLEMENTS" --identity-list "$WORK/identities.txt" \
    --bundle-id "$BUNDLE_ID" --ipa "$IPA_INPUT")"
  if [[ -z "$IDENTITY" ]]; then IDENTITY="$MATCHED_ID"; fi
  [[ "$MATCHED_ID" == "$IDENTITY" ]] || {
    echo "Os perfis dos bundles não correspondem à mesma identidade PKCS#12." >&2; exit 65;
  }
  cp "$PROFILE" "$BUNDLE/embedded.mobileprovision"
done < "$WORK/bundles.tsv"
# Sign every framework and dylib before enclosing .appex/.app bundles.
while IFS= read -r nested; do
  [[ -n "$nested" ]] || continue
  codesign --force --sign "$IDENTITY" --timestamp=none "$nested"
done < <(find "$PAYLOAD" \( -type d -name '*.framework' -o -type f -name '*.dylib' \) -print | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2-)
# Sign extension bundles first, then containing apps; entitlements are per bundle.
while IFS=$'\t' read -r REL_BUNDLE PROFILE ENTITLEMENTS; do
  BUNDLE="$WORK/unpacked/$REL_BUNDLE"
  codesign --force --sign "$IDENTITY" --entitlements "$ENTITLEMENTS" --generate-entitlement-der --timestamp=none "$BUNDLE"
done < <(awk -F '\t' '{ print length($1), $0 }' "$WORK/bundles.tsv" | sort -rn | cut -d' ' -f2-)
while IFS=$'\t' read -r REL_BUNDLE PROFILE ENTITLEMENTS; do
  codesign --verify --strict --verbose=2 "$WORK/unpacked/$REL_BUNDLE"
done < "$WORK/bundles.tsv"
mkdir -p "$(dirname "$OUTPUT")"
(cd "$WORK/unpacked" && ditto -c -k --sequesterRsrc --keepParent Payload "$WORK/signed.ipa")
mv "$WORK/signed.ipa" "$OUTPUT"
python3 "$ROOT/tools/validate-signing-inputs.py" --inspect-ipa "$OUTPUT"
ditto -x -k "$OUTPUT" "$WORK/repacked"
while IFS=
echo "A instalação e o primeiro lançamento ainda precisam ser testados em iPhone real."
\\t' read -r REL_BUNDLE PROFILE ENTITLEMENTS; do
  codesign --verify --strict --verbose=2 "$WORK/repacked/$REL_BUNDLE"
done < "$WORK/bundles.tsv"
echo "IPA assinado e verificado localmente: $OUTPUT"
echo "A instalação e o primeiro lançamento ainda precisam ser testados em iPhone real."
