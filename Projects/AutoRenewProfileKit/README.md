# AutoRenewProfileKit

**Inspiração:** fluxo de leitura e avaliação de provisioning profiles observado no ecossistema SideSign/SideStore. Projeto independente, sem código copiado e sem afiliação.

## Estado implementado no Alpha

- `ProvisioningProfileParser` extrai o payload plist e lê Name, UUID, datas, TeamIdentifier, ApplicationIdentifierPrefix, ProvisionedDevices, ProvisionsAllDevices, DeveloperCertificates e Entitlements.
- Avalia correspondência de Bundle ID exato ou wildcard final.
- O pipeline macOS `tools/sign-ipa-macos.sh` executa `security cms -V` antes de decodificar o perfil e só então valida validade, prefixo de aplicação, Team ID, escopo de dispositivo e certificados listados.

## Separação obrigatória de estados

O parser Swift continua sendo apenas leitor de metadados e marca `cmsSignatureVerified = false`. A verificação CMS ocorre somente no helper macOS, via Security do sistema. Não se deve tratar o relatório do parser como autorização para assinar/instalar.

A confiança/revogação da cadeia depende do trust store e da política do macOS; ainda faltam fixtures CMS reais, testes de assinatura adulterada e validação independente de OCSP/CRL.

## Próximas etapas

1. Compartilhar um contrato de resultado entre o parser Swift e o verificador macOS sem confundir os estados.
2. Testar perfis expirados, payload adulterado, certificados ausentes e Team/App ID incompatíveis.
3. Distinguir Development, Ad Hoc, App Store e Enterprise com dados comprovados.
4. Extrair o código para Swift Package independente quando os contratos estiverem estáveis.

Nenhum perfil será considerado válido apenas por ter plist legível.
