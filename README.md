# AutoRenew
Scaffold SwiftUI (iOS 17+) de auto-renovação para sideloading.

## Gerar o .ipa (sem Mac)
1. Suba esta pasta para um repositório no GitHub.
2. Aba **Actions → Build IPA → Run workflow**.
3. Baixe `AutoRenew.ipa` em *Artifacts* e instale pelo SideStore/AltStore (ele assina com seu Apple ID).

## Gerar localmente (Mac)
`brew install xcodegen && xcodegen generate && open AutoRenew.xcodeproj`

## Estado
- Pronto: agendamento (BGAppRefresh/Processing/foreground), backoff, notificações 48/24/6h, Anisette com fallback+cache, logs, UI, Keychain, resolver DNS (Tunnel).
- Falta: `SigningBackend` real (AltSign + minimuxer). Hoje é um stub que apenas simula a renovação.
- Target `Tunnel` fica fora do IPA (exige Network Extension, indisponível em conta gratuita).
