# AutoRenew

Aplicativo SwiftUI (iOS 17+) em desenvolvimento para acompanhar e renovar aplicativos instalados por sideloading.

## Gerar o .ipa sem Mac

1. Abra **Actions → Build IPA → Run workflow** no GitHub.
2. Aguarde o workflow terminar.
3. Baixe o artefato **AutoRenew-ipa**.
4. Instale o IPA pelo SideStore/AltStore, que fará a assinatura de instalação com seu Apple ID.

O artefato é empacotado sem assinatura de desenvolvimento pelo Xcode; a instalação deve ser feita por um instalador de sideloading compatível.

## Gerar localmente (Mac)

`brew install xcodegen && xcodegen generate && open AutoRenew.xcodeproj`

## Estado real da integração

- **Implementado:** interface SwiftUI, lista local de apps, agendamento em foreground/background, backoff, notificações, logs, armazenamento de preferências e Keychain.
- **Ainda não implementado:** backend de assinatura real com SideSign, obtenção/renovação de certificados e provisioning profiles, assinatura de IPA e reinstalação do aplicativo.
- **Minimuxer:** requer pairing file válido e transporte de dispositivo configurado. A integração não pode ser ativada apenas adicionando a dependência.
- **Segurança:** enquanto o backend real não estiver conectado, o agendador registra a renovação como indisponível e não altera a data de expiração nem informa sucesso fictício.
- **VPN/Tunnel:** o target de Network Extension não é incluído no IPA padrão; sua ativação depende dos entitlements e da configuração de assinatura disponíveis.

## Próximas etapas

1. Integrar autenticação SideSign com fluxo de verificação de dois fatores.
2. Persistir sessão e chaves/certificados no Keychain.
3. Implementar seleção de IPA, extração, assinatura do app e extensões.
4. Definir e validar o fluxo de pareamento/instalação pelo Minimuxer no dispositivo.
5. Executar build e testes em dispositivo iOS real antes de declarar a renovação automática funcional.
