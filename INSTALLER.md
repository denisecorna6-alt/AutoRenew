# AutoRenew Installer — guia de teste

O Installer é um app iOS independente. Para obter o pacote de avaliação mais recente:

1. Abra [a página de execuções do workflow](https://github.com/xlightxt/AutoRenew/actions/workflows/build.yml).
2. Para testar a Alpha atual, abra [execução 41216556796 — CI Success](https://github.com/xlightxt/AutoRenew/actions/runs/41216556796), commit `181a2567129ef836bc0565aca9925557b54a81f2`.
3. Baixe o artefato **AutoRenew-Installer-ipa-unsigned** (SHA-256 `eb42a4141adb86183abc92a90ec3841afe6aa9fbb8706763a7d86b7d03d06c89`).
4. O aplicativo principal está em **AutoRenew-ipa-unsigned** (SHA-256 `e3ae953d748b76bef9593425728a09dcde6ba9f0b9671f2eb3b443051192ddfa`).
5. Esses artefatos expiram em 30 dias e são **unsigned**; não instalam diretamente. Para testar, use um instalador confiável que assine o pacote e aceite IPAs externos.

## Links de download do Installer

O Installer aceita o esquema próprio abaixo, após a instalação do app:

```
autorenewinstaller://install?url=https%3A%2F%2Fexample.com%2Fbuild.ipa
```

O link abre uma confirmação e baixa somente o IPA por HTTPS. Não assina, instala ou executa automaticamente. HTTP, URLs com usuário/senha, fragmentos e links que não terminam em .ipa são rejeitados.

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

## O que há no Installer

- Navegação de Releases públicas Stable/Beta/Alpha do AutoRenew.
- Deep links de download HTTPS com confirmação explícita.
- Download de IPA por asset público ou URL HTTPS direta.
- Importação de IPA pelo app Arquivos.
- Inventário local de identidades PKCS#12 e perfis mobileprovision.
- Compartilhamento de arquivos IPA.

## Importante

Os pacotes de Actions são unsigned. Eles não podem ser instalados diretamente no iPhone. O Installer ainda não assina nem instala IPAs por conta própria; nesta Alpha, ele prepara e encaminha o arquivo para um instalador compatível. A autenticação Apple ID/2FA e o motor de assinatura não estão implementados. Não coloque senha Apple ID ou códigos 2FA nesta Alpha.
