# AutoRenewProfileKit

**Inspiração:** fluxo de leitura e avaliação de provisioning profiles observado no ecossistema SideSign/SideStore. Projeto independente, sem código copiado e sem afiliação.

## Objetivo

Fornecer leitura segura e verificações explícitas para arquivos `.mobileprovision`, isolando a interpretação do CMS e dos campos plist da interface do AutoRenew.

## Primeira etapa existente

O Alpha contém `ProvisioningProfileParser`, que extrai o payload plist e lê Name, UUID, datas, TeamIdentifier, ApplicationIdentifierPrefix, ProvisionedDevices, ProvisionsAllDevices, DeveloperCertificates e Entitlements. Também avalia correspondência de Bundle ID exato ou wildcard final.

**Importante:** extrair o plist não verifica a assinatura CMS nem a cadeia de confiança. O relatório atual marca `cmsSignatureVerified = false` deliberadamente.

## Evolução

1. Extrair CMS com APIs documentadas e validar assinatura criptográfica.
2. Validar cadeia, datas, usos e certificados confiáveis.
3. Comparar Team ID, Application Identifier, Bundle ID, dispositivo e entitlements permitidos.
4. Distinguir perfis Development, Ad Hoc, App Store e Enterprise sem inferências frágeis.
5. Adicionar fixtures sintéticas e testes negativos para payload truncado, datas inválidas, wildcard e perfis incompatíveis.

## Critério de conclusão

Nenhum perfil será considerado válido apenas por ter plist legível. O resultado final precisa separar integridade CMS, confiança, validade temporal e compatibilidade do app/dispositivo.
