#!/bin/bash
set -euo pipefail
usage() {
  echo "Uso: $0 <device-identifier> <app-assinado.ipa>" >&2
  echo "Use o identificador do dispositivo já pareado no Xcode." >&2
}
if [[ $# -ne 2 ]]; then usage; exit 64; fi
DEVICE_ID="$1"
IPA_INPUT="$2"
if [[ -z "$DEVICE_ID" || ! -f "$IPA_INPUT" ]]; then
  echo "Erro: informe o identificador do iPhone e o caminho de um IPA existente." >&2
  usage
  exit 66
fi
case "$IPA_INPUT" in
  *.ipa|*.IPA) ;;
  *) echo "Erro: o arquivo precisa ter extensão .ipa." >&2; exit 65 ;;
esac
if ! command -v xcrun >/dev/null 2>&1 || ! xcrun --find devicectl >/dev/null 2>&1; then
  echo "Erro: instale o Xcode e selecione-o como ferramenta ativa (xcode-select)." >&2
  exit 69
fi
for tool in ditto codesign security python3; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "Erro: ferramenta necessária ausente: $tool" >&2
    exit 69
  }
done
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IPA_PATH="$(cd "$(dirname "$IPA_INPUT")" && pwd)/$(basename "$IPA_INPUT")"
WORK_DIR="$(mktemp -d /tmp/autorenew-install.XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

# Inspect the ZIP central directory before extraction.
python3 "$ROOT/tools/validate-signing-inputs.py" --inspect-ipa "$IPA_PATH"

echo "Extraindo o IPA validado para uma pasta temporária…"
ditto -x -k "$IPA_PATH" "$WORK_DIR"
PAYLOAD_DIR="$WORK_DIR/Payload"
if [[ ! -d "$PAYLOAD_DIR" ]]; then
  echo "Erro: o IPA não contém a pasta Payload." >&2
  exit 65
fi
APP_COUNT="$(find "$PAYLOAD_DIR" -maxdepth 1 -type d -name '*.app' | wc -l | tr -d ' ')"
if [[ "$APP_COUNT" != "1" ]]; then
  echo "Erro: esperado exatamente um app principal em Payload; encontrados: $APP_COUNT." >&2
  exit 65
fi
APP_PATH="$(find "$PAYLOAD_DIR" -maxdepth 1 -type d -name '*.app' -print -quit)"
BUNDLE_INDEX=0
while IFS= read -r -d '' BUNDLE_PATH; do
  PROFILE="$BUNDLE_PATH/embedded.mobileprovision"
  INFO="$BUNDLE_PATH/Info.plist"
  if [[ ! -f "$PROFILE" || ! -f "$INFO" ]]; then
    echo "Erro: bundle sem Info.plist ou embedded.mobileprovision: $BUNDLE_PATH" >&2
    exit 65
  fi
  # Verify CMS before decoding or trusting profile fields.
  security cms -V -i "$PROFILE" >/dev/null
  PROFILE_PLIST="$WORK_DIR/profile-$BUNDLE_INDEX.plist"
  security cms -D -i "$PROFILE" > "$PROFILE_PLIST"
  python3 - "$PROFILE_PLIST" "$INFO" <<'PY'
import datetime
import plistlib
import sys
with open(sys.argv[1], "rb") as f:
    profile = plistlib.load(f)
with open(sys.argv[2], "rb") as f:
    info = plistlib.load(f)
def fail(message):
    raise SystemExit("Erro: " + message)
expiry = profile.get("ExpirationDate")
if not isinstance(expiry, datetime.datetime):
    fail("perfil sem ExpirationDate válida")
if expiry.tzinfo is None:
    expiry = expiry.replace(tzinfo=datetime.timezone.utc)
else:
    expiry = expiry.astimezone(datetime.timezone.utc)
if expiry <= datetime.datetime.now(datetime.timezone.utc):
    fail("perfil de provisionamento expirado")
bundle_id = info.get("CFBundleIdentifier")
entitlements = profile.get("Entitlements")
teams = profile.get("TeamIdentifier")
prefixes = profile.get("ApplicationIdentifierPrefix")
if not isinstance(bundle_id, str) or not bundle_id or not isinstance(entitlements, dict):
    fail("Info.plist ou Entitlements inválidos")
if not isinstance(teams, list) or not teams:
    fail("TeamIdentifier ausente")
if not isinstance(prefixes, list):
    fail("ApplicationIdentifierPrefix ausente")
app_identifier = entitlements.get("application-identifier")
if not isinstance(app_identifier, str) or "." not in app_identifier:
    fail("application-identifier ausente")
prefix, pattern = app_identifier.split(".", 1)
if prefix not in prefixes:
    fail("prefixo do application-identifier não corresponde ao perfil")
if pattern == "*":
    matches = True
elif pattern.endswith(".*"):
    matches = bundle_id.startswith(pattern[:-1])
else:
    matches = bundle_id == pattern
if not matches:
    fail("Bundle ID não é permitido pelo perfil")
if entitlements.get("com.apple.developer.team-identifier") not in teams:
    fail("Team ID do entitlement não corresponde ao perfil")
devices = profile.get("ProvisionedDevices")
if not ((isinstance(devices, list) and len(devices) > 0) or profile.get("ProvisionsAllDevices") is True):
    fail("perfil não possui escopo de instalação em dispositivo")
certificates = profile.get("DeveloperCertificates")
if not isinstance(certificates, list) or not certificates or not all(isinstance(x, bytes) for x in certificates):
    fail("perfil não contém DeveloperCertificates válidos")
PY
  BUNDLE_INDEX=$((BUNDLE_INDEX + 1))
done < <(find "$PAYLOAD_DIR" -type d \( -name '*.app' -o -name '*.appex' \) -print0)

echo "Verificando a assinatura de código do aplicativo e extensões…"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
echo "Solicitando instalação no dispositivo selecionado…"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"
echo "Comando de instalação concluído. Verifique o resultado no iPhone; o script não confirma primeiro lançamento nem funcionamento do app."
