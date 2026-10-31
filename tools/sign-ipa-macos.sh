#!/bin/bash
# Sign a development IPA locally on macOS. Never uploads credentials or artifacts.
set -euo pipefail
usage() {
  echo "Uso: P12_PASSWORD='...' $0 <unsigned.ipa> <identity.p12> <profile.mobileprovision> <entitlements.plist> <output.ipa>" >&2
  exit 64
}
[[ $# -eq 5 ]] || usage
IPA_INPUT="$1"; P12="$2"; PROFILE="$3"; ENTITLEMENTS="$4"; OUTPUT="$5"
: "${P12_PASSWORD:?Defina P12_PASSWORD no ambiente; não passe a senha na linha de comando.}"
for f in "$IPA_INPUT" "$P12" "$PROFILE" "$ENTITLEMENTS"; do [[ -f "$f" ]] || { echo "Arquivo ausente: $f" >&2; exit 66; }; done
[[ "${IPA_INPUT##*.}" == "ipa" || "${IPA_INPUT##*.}" == "IPA" ]] || { echo "Entrada precisa ser .ipa" >&2; exit 65; }
for tool in security codesign ditto xcrun python3; do command -v "$tool" >/dev/null || { echo "Ferramenta ausente: $tool" >&2; exit 69; }; done
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/autorenew-sign.XXXXXX")"
KEYCHAIN="$WORK/autorenew-signing.keychain-db"
KEYCHAIN_PASSWORD="$(openssl rand -hex 24)"
cleanup() {
  security delete-keychain "$KEYCHAIN" >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT
mkdir -p "$WORK/unpacked" "$WORK/keychain"
# Validate CMS cryptographic signature before trusting any profile fields.
security cms -V -i "$PROFILE"
security cms -D -i "$PROFILE" > "$WORK/profile.plist"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
security set-keychain-settings -lut 900 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$P12" -k "$KEYCHAIN" -P "$P12_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security >/dev/null
security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
security list-keychains -d user -s "$KEYCHAIN"
security find-identity -v -p codesigning "$KEYCHAIN" > "$WORK/identities.txt"
ditto -x -k "$IPA_INPUT" "$WORK/unpacked"
APP_COUNT="$(find "$WORK/unpacked/Payload" -maxdepth 1 -type d -name '*.app' 2>/dev/null | wc -l | tr -d ' ')"
[[ "$APP_COUNT" == "1" ]] || { echo "Esperado exatamente um Payload/*.app; encontrado: $APP_COUNT" >&2; exit 65; }
APP="$(find "$WORK/unpacked/Payload" -maxdepth 1 -type d -name '*.app' -print -quit)"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")
cp "$PROFILE" "$APP/embedded.mobileprovision"
python3 "$ROOT/tools/validate-signing-inputs.py" \
  --profile "$WORK/profile.plist" --app-info "$APP/Info.plist" \
  --entitlements "$ENTITLEMENTS" --identity-list "$WORK/identities.txt" \
  --bundle-id "$BUNDLE_ID" --ipa "$IPA_INPUT" > "$WORK/identity-sha1"
IDENTITY="$(cat "$WORK/identity-sha1")"
# Sign nested frameworks/dylibs from deepest to shallowest; app extensions are
# rejected until each extension has its own profile + least-privilege entitlements.
APPEX_COUNT="$(find "$APP" -type d -name '*.appex' | wc -l | tr -d ' ')"
if [[ "$APPEX_COUNT" != "0" ]]; then
  echo "IPA contém .appex. Assinatura bloqueada: cada extensão exige perfil e entitlements próprios; não reutilizaremos os do app principal." >&2
  exit 65
fi
while IFS= read -r nested; do
  [[ -n "$nested" ]] || continue
  codesign --force --sign "$IDENTITY" --timestamp=none "$nested"
done < <(find "$APP" \( -type d -name '*.framework' -o -type f -name '*.dylib' \) -print | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2-)
codesign --force --sign "$IDENTITY" --entitlements "$ENTITLEMENTS" --generate-entitlement-der --timestamp=none "$APP"
codesign --verify --strict --verbose=2 "$APP"
# Rebuild from the extracted root, preserving resource modes and symlinks.
mkdir -p "$(dirname "$OUTPUT")"
(cd "$WORK/unpacked" && ditto -c -k --sequesterRsrc --keepParent Payload "$WORK/signed.ipa")
mv "$WORK/signed.ipa" "$OUTPUT"
echo "IPA assinado e verificado localmente: $OUTPUT"
echo "Isso não comprova instalação/primeiro lançamento em iPhone; faça teste real no dispositivo."
