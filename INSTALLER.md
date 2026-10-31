# AutoRenew Installer — guia de teste

O Installer é um app iOS independente. O build Alpha mais recente que passou CI nesta branch foi o run [#41234393205](https://github.com/xlightxt/AutoRenew/actions/runs/41234393205), na branch codex/alpha-installer-download-hardening-20261031.

1. Abra [o workflow de build](https://github.com/xlightxt/AutoRenew/actions/workflows/build.yml).
2. Selecione o run #41234393205.
3. Baixe os artefatos AutoRenew-ipa-unsigned e AutoRenew-Installer-ipa-unsigned.
4. O primeiro contém o app principal; o segundo contém o Installer independente.

**Ambos são artefatos Actions com IPAs unsigned.** O build passou, mas não há assinatura, provisioning profile embutido, instalação validada nem primeiro lançamento. Não os trate como instaláveis diretamente.

## Preparar e encaminhar um IPA

1. Baixe uma versão pública ou importe um arquivo .ipa.
2. O download remoto é limitado a 1,5 GB durante a transferência; o catálogo de fontes JSON é limitado a 5 MB por fonte, 20 fontes, 500 apps por fonte e 50 versões por app.
3. Toque em **Inspecionar IPA e preparar encaminhamento**. O app verifica extensão, tamanho, cabeçalho ZIP e calcula SHA-256 em streaming.
4. Toque em **Enviar para AltStore / SideStore** e escolha o instalador na folha de compartilhamento do iOS, se ele aparecer.
5. Conclua a assinatura e instalação no aplicativo escolhido e siga as instruções dele.

A pré-verificação no iOS não valida o diretório central ZIP, CRC, caminhos internos, symlinks, assinatura de código, CMS do perfil ou compatibilidade com o dispositivo. Ela não certifica a segurança ou legitimidade do IPA. O AutoRenew não recebe confirmação do resultado da instalação.

## Instalação assistida por Mac (IPA já assinado)

Em um Mac com Xcode e ferramentas de linha de comando, o repositório inclui tools/install-to-iphone.sh:

~~~sh
xcrun devicectl list devices
./tools/install-to-iphone.sh <identificador-do-iphone> /caminho/para/app-assinado.ipa
~~~

Antes de extrair, o script executa tools/validate-signing-inputs.py --inspect-ipa para rejeitar traversal, symlinks, entradas duplicadas e limites ZIP excedidos. Para cada bundle .app e .appex, verifica CMS com security cms -V, decodifica o perfil, confere validade, Bundle ID, prefixo, Team ID, escopo de dispositivo e DeveloperCertificates; depois executa codesign --verify --deep --strict e solicita a instalação por xcrun devicectl.

O iPhone precisa estar pareado/confiado pelo Mac. O script não assina o IPA, não confirma que o UDID selecionado está no perfil e não prova primeiro lançamento ou funcionamento. O próprio dispositivo/Xcode ainda precisa aceitar a instalação.

## O que há no Installer

- Navegação de Releases públicas Stable/Beta/Alpha do AutoRenew.
- Download de IPA por asset público ou URL HTTPS direta, com limite de tamanho em streaming.
- Catálogo de fontes AltStore JSON com limite de tamanho e metadados.
- Importação de IPA pelo app Arquivos.
- Inventário local de identidades PKCS#12 e perfis mobileprovision.
- Compartilhamento de arquivos IPA.

## Importante

Os pacotes de Actions são unsigned e não podem ser instalados diretamente no iPhone. O Installer ainda não assina nem instala IPAs por conta própria; nesta Alpha, ele prepara e encaminha o arquivo para um instalador compatível. A autenticação Apple ID/2FA e a assinatura on-device não estão implementadas. Não coloque senha Apple ID ou códigos 2FA nesta Alpha.
