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

## Compatibilidade de fontes

O catálogo do AutoRenew lê o formato de fontes AltStore (AltSources), que também é compatível com SideStore. Adicione o URL HTTPS de um arquivo JSON de fonte dentro da aba **Catálogo**. Use apenas fontes confiáveis.

Referências:
- [SideStore — App Sources](https://docs.sidestore.io/docs/advanced/app-sources)
- [AltStore — Make a Source](https://faq.altstore.io/developers/make-a-source)

## Limites atuais da Alpha

- O catálogo baixa e guarda os IPAs. **Ainda não assina nem instala aplicativos**.
- Login Apple, autenticação 2FA, assinatura no dispositivo, instalação e renovação automática ainda não estão implementados.
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
