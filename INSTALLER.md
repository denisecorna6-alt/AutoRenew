# AutoRenew Installer — guia de teste

O Installer é um app iOS independente. Para obter o pacote de avaliação mais recente:

1. Abra [a página de execuções do workflow](https://github.com/xlightxt/AutoRenew/actions/workflows/build.yml).
2. Escolha a execução mais recente com resultado **Success** na branch codex/alpha-ecosystem-rebuild-20261031.
3. Baixe o artefato **AutoRenew-Installer-ipa-unsigned**.
4. O artefato **AutoRenew-ipa-unsigned** é o aplicativo principal AutoRenew.

## Preparar e encaminhar um IPA

1. Baixe uma versão ou importe um arquivo `.ipa`.
2. Toque em **Verificar e preparar instalação**. O app confere extensão, tamanho, assinatura inicial ZIP e calcula SHA-256 em streaming.
3. Toque em **Enviar para AltStore / SideStore** e escolha o instalador na folha de compartilhamento do iOS, se ele aparecer.
4. Conclua a assinatura e instalação no aplicativo escolhido e siga as instruções dele.

A pré-verificação não confirma que o IPA é válido, seguro, compatível ou assinado corretamente. O AutoRenew não recebe confirmação do resultado da instalação.

## Instalação assistida por Mac (IPA já assinado)

Se você tiver um Mac com Xcode, o repositório inclui `tools/install-to-iphone.sh`. Ele usa `xcrun devicectl` para solicitar instalação no iPhone:

```sh
xcrun devicectl list devices
./tools/install-to-iphone.sh <identificador-do-iphone> /caminho/para/app-assinado.ipa
```

O iPhone precisa estar pareado/confiado pelo Mac e o IPA precisa ter assinatura de desenvolvimento válida e perfil que inclua o dispositivo. Esta ferramenta não assina o IPA. A confirmação do comando não substitui o teste de abertura no aparelho.

## Assinatura local assistida por Mac (experimental)

O repositório também inclui `tools/sign-ipa-macos.sh` para assinar localmente um IPA com certificado de desenvolvimento e perfis fornecidos pelo próprio usuário. Esse fluxo ainda não está conectado ao aplicativo iOS e requer um manifesto com perfil e entitlements para cada `.app` e `.appex`.

1. Importe o `.p12` pelo app **Acesso às Chaves (Keychain Access)**; digite a senha somente no diálogo do macOS.
2. Execute `security find-identity -v -p codesigning` e copie o SHA-1 de 40 caracteres da identidade correta.
3. Prepare o manifesto conforme `Projects/AutoRenewSigningKit/SIGNING_PIPELINE.md`.
4. Execute:

   ```sh
   tools/sign-ipa-macos.sh unsigned.ipa SHA1_DA_IDENTIDADE signing-manifest.json signed.ipa
   ```

O helper valida a estrutura ZIP, a assinatura CMS dos perfis, Bundle ID, Team ID, validade, certificado e entitlements antes de assinar e verificar o pacote. Ele não recebe senha PKCS#12, não cria keychains nem envia certificados à rede. A assinatura concluída ainda precisa ser testada em iPhone físico; isso não comprova primeiro lançamento nem renovação automática.

## O que há no Installer

- Navegação de Releases públicas Stable/Beta/Alpha do AutoRenew.
- Download de IPA por asset público ou URL HTTPS direta.
- Importação de IPA pelo app Arquivos.
- Inventário local de identidades PKCS#12 e perfis mobileprovision.
- Compartilhamento de arquivos IPA.

## Importante

Os pacotes de Actions são unsigned. Eles não podem ser instalados diretamente no iPhone. O Installer ainda não assina nem instala IPAs por conta própria; nesta Alpha, ele prepara e encaminha o arquivo para um instalador compatível. A autenticação Apple ID/2FA e o motor de assinatura não estão implementados. Não coloque senha Apple ID ou códigos 2FA nesta Alpha.
