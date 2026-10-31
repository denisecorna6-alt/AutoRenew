# AutoRenew Installer — guia de teste

O Installer é um app iOS independente. Para obter o pacote de avaliação mais recente:

1. Abra [a página de execuções do workflow](https://github.com/xlightxt/AutoRenew/actions/workflows/build.yml).
2. Escolha a execução mais recente com resultado **Success** na branch codex/alpha-installer-hub-20261031.
3. Baixe o artefato **AutoRenew-Installer-ipa-unsigned**.
4. O artefato **AutoRenew-ipa-unsigned** é o aplicativo principal AutoRenew.

## O que há no Installer

- Navegação de Releases públicas Stable/Beta/Alpha do AutoRenew.
- Download de IPA por asset público ou URL HTTPS direta.
- Importação de IPA pelo app Arquivos.
- Inventário local de identidades PKCS#12 e perfis mobileprovision.
- Compartilhamento de arquivos IPA.

## Importante

Os pacotes de Actions são unsigned. Eles não podem ser instalados diretamente no iPhone. O Installer ainda não assina nem instala IPAs. A autenticação Apple ID/2FA e o motor de assinatura não estão implementados. Não coloque senha Apple ID ou códigos 2FA nesta Alpha.
