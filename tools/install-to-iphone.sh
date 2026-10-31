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
  # Validate bundle metadata and the exact selected device UDID after CMS verification.
  python3 "$ROOT/tools/validate-device-profile.py" --profile "$PROFILE_PLIST" --info "$INFO" --device-id "$DEVICE_ID"
  BUNDLE_INDEX=$((BUNDLE_INDEX + 1))
done < <(find "$PAYLOAD_DIR" -type d \( -name '*.app' -o -name '*.appex' \) -print0)

echo "Verificando a assinatura de código do aplicativo e extensões…"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
echo "Solicitando instalação no dispositivo selecionado…"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"
echo "Comando de instalação concluído. Verifique o resultado no iPhone; o script não confirma primeiro lançamento nem funcionamento do app."
