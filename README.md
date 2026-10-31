# AutoRenew

**AutoRenew e AutoRenew Installer são dois aplicativos iOS separados.** O Installer é o ponto principal para obter os IPAs oficiais do projeto; o AutoRenew também tem um catálogo para fontes de aplicativos compatíveis com AltStore/SideStore.

## Baixar o AutoRenew Installer

1. Abra [GitHub Actions — Build AutoRenew + Installer](https://github.com/xlightxt/AutoRenew/actions/workflows/build.yml).
2. Entre na execução mais recente concluída com sucesso na branch Alpha.
3. Em **Artifacts**, baixe **AutoRenew-Installer-ipa-unsigned**.
4. O pacote AutoRenew está no artefato **AutoRenew-ipa-unsigned**.

> Os artefatos do GitHub Actions exigem uma conta GitHub com acesso ao repositório. Os IPAs de CI são unsigned: são pacotes de inspeção, não instaladores prontos para abrir no iPhone. Para instalação, é necessária assinatura válida e um método compatível.

## O que cada aplicativo faz

### AutoRenew Installer
- Pré-verificação local do IPA: extensão, tamanho, cabeçalho ZIP e hash SHA-256 em leitura por blocos.
- Fluxo **Verificar e preparar instalação** seguido de compartilhamento para AltStore/SideStore quando disponíveis no iOS.
- A assinatura e a instalação são executadas pelo instalador escolhido; o AutoRenew não afirma sucesso nem altera o estado do app sem confirmação.
- Aplicativo iOS independente, com Bundle ID próprio.
- Catálogo de Releases públicas do AutoRenew, separado por Stable, Beta e Alpha.
- Download de IPAs das Releases públicas, por link HTTPS e importação de arquivos locais.
- Gestão local de certificados .p12 e perfis .mobileprovision.
- Encaminhamento dos arquivos IPA pelo compartilhamento do iOS.

### AutoRenew
- Acompanhamento manual de aplicativos, prazos, histórico e lembretes.
- Aba **Catálogo** para adicionar fontes JSON compatíveis com AltStore/SideStore.
- Busca por nome, Bundle ID e fonte; lista versões e baixa IPAs HTTPS para o armazenamento privado do app.
- Compartilhamento dos IPAs baixados pelo iOS.

## Instalação assistida por Mac

Para IPAs já assinados para desenvolvimento, há um helper local para macOS que usa as ferramentas do Xcode (não envia certificado ou senha a servidores):

```sh
xcrun devicectl list devices
./tools/install-to-iphone.sh <identificador-do-iphone> /caminho/para/app-assinado.ipa
```

Requisitos: Mac com Xcode instalado, iPhone pareado/confiado pelo computador, Developer Mode quando exigido e IPA assinado com certificado/perfil compatíveis com esse dispositivo. O helper extrai o IPA, exige um único app principal, verifica a assinatura com `codesign`, verifica a assinatura CMS do perfil, confere Bundle ID/Team ID, validade e se o UDID do iPhone está autorizado no perfil antes de solicitar a instalação pelo `devicectl`.

O helper não cria certificados, não registra dispositivos, não assina IPAs e não contorna o provisionamento. O sucesso do comando também não comprova que o app abriu corretamente no iPhone.

## Assinatura local assistida por Mac (experimental)

Há um pipeline local opcional em `tools/sign-ipa-macos.sh`. Ele exige um IPA, uma identidade de desenvolvimento importada pelo usuário no Acesso às Chaves, perfis e entitlements para cada bundle e um manifesto JSON. O fluxo não é executado pelo app iOS.

1. Importe o `.p12` pelo **Acesso às Chaves (Keychain Access)**; a senha é digitada no diálogo do macOS.
2. Liste as identidades válidas com `security find-identity -v -p codesigning` e copie o SHA-1 da identidade correta.
3. Siga o modelo de manifesto em `Projects/AutoRenewSigningKit/SIGNING_PIPELINE.md`.
4. Execute `tools/sign-ipa-macos.sh unsigned.ipa SHA1_DA_IDENTIDADE signing-manifest.json signed.ipa`.

O helper verifica a estrutura ZIP, CMS dos perfis, Bundle ID, Team ID, validade, certificado e entitlements, depois assina e verifica os bundles. Não recebe senha PKCS#12, não altera a lista global de keychains e não envia material à rede. Este caminho ainda precisa ser validado com certificados/perfis reais e em iPhone físico; não equivale a renovação automática.

## Compatibilidade de fontes

O catálogo do AutoRenew lê o formato de fontes AltStore (AltSources), que também é compatível com SideStore. Adicione o URL HTTPS de um arquivo JSON de fonte dentro da aba **Catálogo**. Use apenas fontes confiáveis.

Referências:
- [SideStore — App Sources](https://docs.sidestore.io/docs/advanced/app-sources)
- [AltStore — Make a Source](https://faq.altstore.io/developers/make-a-source)

## Limites atuais da Alpha

- O catálogo baixa e guarda os IPAs. **Ainda não assina nem instala aplicativos**.
- Login Apple, autenticação 2FA, provisionamento Anisette V3, assinatura própria no dispositivo e instalação direta dentro do AutoRenew ainda não estão implementados. A Alpha oferece pré-verificação e encaminhamento para AltStore/SideStore; nenhum servidor Anisette é contatado por padrão.
- A importação de .p12 e .mobileprovision no Installer é armazenamento/gestão local; ainda não comprova compatibilidade nem produz assinatura.
- Não envie senha Apple ID, códigos 2FA, cookies, tokens ou chaves privadas.
- Não há Releases públicas oficiais até que uma publicação seja aprovada. Builds de Actions não são Releases públicas.

## Compilar e testar

O workflow constrói dois targets separados:
- AutoRenew → AutoRenew.ipa
- AutoRenewInstaller → AutoRenew-Installer.ipa

Ele executa testes unitários no simulador e publica dois artefatos unsigned para inspeção. O sucesso do build não comprova instalação real no iPhone.

Para compilar localmente em um Mac:
```sh
brew install xcodegen
xcodegen generate
xcodebuild -project AutoRenew.xcodeproj -scheme AutoRenew -destination 'platform=iOS Simulator,name=iPhone 16' test
```
