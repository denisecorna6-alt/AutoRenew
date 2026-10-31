#!/bin/bash
set -euo pipefail

usage() {
  echo "Uso: $0 <device-identifier> <app-assinado.ipa>" >&2
  echo "Liste os dispositivos conectados com: xcrun devicectl list devices" >&2
}

if [[ $# -ne 2 ]]; then
  usage
  exit 64
fi

DEVICE_ID="$1"
IPA_INPUT="$2"

if [[ -z "$DEVICE_ID" || ! -f "$IPA_INPUT" ]]; then
  echo "Erro: informe o identificador do iPhone e o caminho de um IPA existente." >&2
  usage
  exit 66
fi

if [[ "${IPA_INPUT##*.}" != "ipa" && "${IPA_INPUT##*.}" != "IPA" ]]; then
  echo "Erro: o arquivo precisa ter extensão .ipa." >&2
  exit 65
fi

if ! command -v xcrun >/dev/null 2>&1 || ! xcrun --find devicectl >/dev/null 2>&1; then
  echo "Erro: instale o Xcode e selecione-o como ferramenta ativa (xcode-select)." >&2
  exit 69
fi

if ! command -v ditto >/dev/null 2>&1 || ! command -v codesign >/dev/null 2>&1 || ! command -v security >/dev/null 2>&1; then
  echo "Erro: ferramentas de sistema do macOS não estão disponíveis." >&2
  exit 69
fi

IPA_PATH="$(cd "$(dirname "$IPA_INPUT")" && pwd)/$(basename "$IPA_INPUT")"
IPA_SIZE="$(stat -f%z "$IPA_PATH")"
if [[ "$IPA_SIZE" -le 0 || "$IPA_SIZE" -gt 1500000000 ]]; then
  echo "Erro: o IPA está vazio ou excede 1,5 GB." >&2
  exit 65
fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$ROOT/tools/validate-signing-inputs.py" --inspect-ipa "$IPA_PATH"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/autorenew-install.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "Extraindo o IPA para uma pasta temporária…"
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
if [[ ! -f "$APP_PATH/embedded.mobileprovision" ]]; then
  echo "Erro: o app não contém embedded.mobileprovision. Este IPA pode estar sem assinatura de desenvolvimento." >&2
  exit 65
fi

echo "Verificando a assinatura do aplicativo…"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
security cms -V -i "$APP_PATH/embedded.mobileprovision"
PROFILE_PLIST="$WORK/profile.plist"
security cms -D -i "$APP_PATH/embedded.mobileprovision" > "$PROFILE_PLIST"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist")
echo "Dispositivos conhecidos pelo Xcode:"
xcrun devicectl list devices --json-output "$WORK_DIR/devices.json"

python3 "$ROOT/tools/validate-install-target.py" \
  "$PROFILE_PLIST" "$BUNDLE_ID" "$WORK_DIR/devices.json" "$DEVICE_ID"

echo "Solicitando instalação no dispositivo $DEVICE_ID…"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"

echo "Comando de instalação concluído. Verifique o resultado no iPhone; o script não consegue confirmar primeiro lançamento ou funcionamento do app."
