#!/bin/bash
# Sign a development IPA locally on macOS using an identity already imported in Keychain.
# The PKCS#12 password is never passed to a command-line argument or stored by this script.
set -euo pipefail

usage() {
  echo "Uso: $0 <unsigned.ipa> <identity-sha1> <manifest.json> <output.ipa>" >&2
  echo "Importe primeiro o .p12 pelo app Acesso às Chaves (Keychain Access)." >&2
  echo "Liste identidades válidas com: security find-identity -v -p codesigning" >&2
  exit 64
}
[[ $# -eq 4 ]] || usage

IPA_INPUT="$1"
IDENTITY_SHA1="${2//:/}"
MANIFEST="$3"
OUTPUT="$4"

[[ -f "$IPA_INPUT" && -f "$MANIFEST" ]] || { echo "IPA ou manifesto ausente." >&2; exit 66; }
[[ "${IPA_INPUT##*.}" == "ipa" || "${IPA_INPUT##*.}" == "IPA" ]] || { echo "Entrada precisa ser .ipa" >&2; exit 65; }
[[ "$OUTPUT" == *.ipa || "$OUTPUT" == *.IPA ]] || { echo "Saída precisa terminar em .ipa" >&2; exit 65; }
[[ "$IDENTITY_SHA1" =~ ^[0-9A-Fa-f]{40}$ ]] || { echo "Informe o SHA-1 de 40 caracteres da identidade." >&2; exit 64; }

for tool in security codesign ditto xcrun python3 openssl shasum; do
  command -v "$tool" >/dev/null || { echo "Ferramenta ausente: $tool" >&2; exit 69; }
done

IPA_PATH="$(cd "$(dirname "$IPA_INPUT")" && pwd)/$(basename "$IPA_INPUT")"
MANIFEST_PATH="$(cd "$(dirname "$MANIFEST")" && pwd)/$(basename "$MANIFEST")"
OUTPUT_DIR="$(cd "$(dirname "$OUTPUT")" 2>/dev/null && pwd || mkdir -p "$(dirname "$OUTPUT")" && cd "$(dirname "$OUTPUT")" && pwd)"
OUTPUT_PATH="$OUTPUT_DIR/$(basename "$OUTPUT")"
[[ "$IPA_PATH" != "$OUTPUT_PATH" ]] || { echo "A saída não pode sobrescrever o IPA de entrada." >&2; exit 65; }
[[ ! -e "$OUTPUT_PATH" ]] || { echo "A saída já existe; escolha outro caminho para evitar sobrescrita." >&2; exit 73; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/autorenew-sign.XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

# Inspect the ZIP central directory and reject traversal, symlinks and ZIP bombs.
python3 "$ROOT/tools/validate-signing-inputs.py" --inspect-ipa "$IPA_PATH"

# Do not import PKCS#12 here: security import -P would expose its password in process arguments.
# The user imports the identity interactively into Keychain Access before running this script.
security find-identity -v -p codesigning > "$WORK/identities.txt"
IDENTITY_SHA1="$(printf '%s' "$IDENTITY_SHA1" | tr '[:lower:]' '[:upper:]')"
if ! awk -v wanted="$IDENTITY_SHA1" 'toupper($2) == wanted { found = 1 } END { exit !found }' "$WORK/identities.txt"; then
  echo "A identidade solicitada não aparece entre as identidades válidas do Keychain." >&2
  exit 65
fi
IDENTITY="$IDENTITY_SHA1"

ditto -x -k "$IPA_PATH" "$WORK"
PAYLOAD="$WORK/Payload"
[[ -d "$PAYLOAD" ]] || { echo "IPA não contém Payload/." >&2; exit 65; }

# Manifest JSON: bundles[{bundle_path,profile_path,entitlements_path}].
# All paths are relative to the manifest directory; external files cannot escape it.
MANIFEST_DIR="$(cd "$(dirname "$MANIFEST_PATH")" && pwd)"
python3 - "$MANIFEST_PATH" > "$WORK/bundles.tsv" <<'PY'
import json, os, sys
from pathlib import PurePosixPath

manifest_path = os.path.abspath(sys.argv[1])
root = os.path.dirname(manifest_path)
with open(manifest_path, encoding="utf-8") as f:
    doc = json.load(f)
bundles = doc.get("bundles")
if not isinstance(bundles, list) or not bundles:
    raise SystemExit("Manifesto precisa conter bundles[]")
seen = set()
for item in bundles:
    if not isinstance(item, dict):
        raise SystemExit("Entrada de bundle inválida")
    vals = [item.get(k) for k in ("bundle_path", "profile_path", "entitlements_path")]
    if not all(isinstance(v, str) and v and "\t" not in v and "\n" not in v for v in vals):
        raise SystemExit("Cada bundle precisa de bundle_path, profile_path e entitlements_path")
    bundle_path = PurePosixPath(vals[0])
    if bundle_path.is_absolute() or ".." in bundle_path.parts or "\\" in vals[0] or ":" in vals[0]:
        raise SystemExit("bundle_path precisa ser relativo e seguro")
    resolved = [os.path.realpath(os.path.join(root, v)) for v in vals[1:]]
    if any(os.path.commonpath([root, p]) != root for p in resolved):
        raise SystemExit("profile_path/entitlements_path precisam permanecer na pasta do manifesto")
    if vals[0] in seen:
        raise SystemExit("bundle_path duplicado")
    seen.add(vals[0])
    print("\t".join([vals[0], *resolved]))
PY

# Every .app and .appex must have its own profile and least-privilege entitlements.
find "$PAYLOAD" -type d \( -name '*.app' -o -name '*.appex' \) -print | sed "s#^$WORK/##" | sort > "$WORK/discovered-bundles.txt"
cut -f1 "$WORK/bundles.tsv" | sort > "$WORK/manifest-bundles.txt"
diff -u "$WORK/discovered-bundles.txt" "$WORK/manifest-bundles.txt" || {
  echo "Manifesto deve cobrir exatamente cada .app e .appex no IPA." >&2
  exit 65
}

while IFS=$'\t' read -r REL_BUNDLE PROFILE ENTITLEMENTS; do
  BUNDLE="$WORK/$REL_BUNDLE"
  [[ -d "$BUNDLE" && -f "$BUNDLE/Info.plist" && -f "$PROFILE" && -f "$ENTITLEMENTS" ]] || {
    echo "Bundle, perfil ou entitlements ausente para $REL_BUNDLE" >&2
    exit 66
  }

  # Verify the CMS signature before decoding or trusting profile fields.
  security cms -V -i "$PROFILE"
  PROFILE_PLIST="$WORK/profile-$(printf '%s' "$REL_BUNDLE" | shasum | awk '{print $1}').plist"
  security cms -D -i "$PROFILE" > "$PROFILE_PLIST"
  BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$BUNDLE/Info.plist")
  MATCHED_ID="$(python3 "$ROOT/tools/validate-signing-inputs.py" \
    --profile "$PROFILE_PLIST" --app-info "$BUNDLE/Info.plist" \
    --entitlements "$ENTITLEMENTS" --identity-list "$WORK/identities.txt" \
    --bundle-id "$BUNDLE_ID" --ipa "$IPA_PATH")"
  [[ "$MATCHED_ID" == "$IDENTITY" ]] || {
    echo "O certificado selecionado não corresponde ao perfil de $REL_BUNDLE." >&2
    exit 65
  }
  cp "$PROFILE" "$BUNDLE/embedded.mobileprovision"
done < "$WORK/bundles.tsv"

# Sign frameworks and dylibs before enclosing extension/app bundles.
while IFS= read -r nested; do
  [[ -n "$nested" ]] || continue
  codesign --force --sign "$IDENTITY" --timestamp=none "$nested"
done < <(find "$PAYLOAD" \( -type d -name '*.framework' -o -type f -name '*.dylib' \) -print | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2-)

# Sign extension bundles first, then containing apps; each bundle gets its own entitlements.
while IFS=$'\t' read -r REL_BUNDLE PROFILE ENTITLEMENTS; do
  codesign --force --sign "$IDENTITY" --entitlements "$ENTITLEMENTS" --generate-entitlement-der --timestamp=none "$WORK/$REL_BUNDLE"
done < <(awk -F '\t' '{ print length($1), $0 }' "$WORK/bundles.tsv" | sort -rn | cut -d' ' -f2-)

while IFS=$'\t' read -r REL_BUNDLE PROFILE ENTITLEMENTS; do
  codesign --verify --deep --strict --verbose=2 "$WORK/$REL_BUNDLE"
done < "$WORK/bundles.tsv"

(cd "$WORK" && ditto -c -k --sequesterRsrc --keepParent Payload "$WORK/signed.ipa")
python3 "$ROOT/tools/validate-signing-inputs.py" --inspect-ipa "$WORK/signed.ipa"
ditto -x -k "$WORK/signed.ipa" "$WORK/repacked"
while IFS=$'\t' read -r REL_BUNDLE PROFILE ENTITLEMENTS; do
  codesign --verify --deep --strict --verbose=2 "$WORK/repacked/$REL_BUNDLE"
done < "$WORK/bundles.tsv"

mv "$WORK/signed.ipa" "$OUTPUT_PATH"
echo "IPA assinado e verificado localmente: $OUTPUT_PATH"
echo "A instalação e o primeiro lançamento ainda precisam ser testados em iPhone real."
