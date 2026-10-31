# AutoRenewSigningKit

**Inspiração:** organização modular de identidade, certificados, assinatura e entitlements do SideSign. Projeto independente, sem código copiado ou afiliação.

## Estado implementado no Alpha

- `SigningIdentityProfileMatcher` importa PKCS#12 em memória, confirma identidade/certificado/chave privada e compara o certificado com `DeveloperCertificates` do perfil.
- `tools/sign-ipa-macos.sh` implementa um pipeline local no macOS: CMS verify via Security, validação do perfil/identidade, allowlist de entitlements, assinatura com `codesign` e verificação recursiva. A identidade deve ser importada pelo usuário no Acesso às Chaves; o helper recebe somente o SHA-1 da identidade e nunca recebe senha PKCS#12.
- O manifesto exige perfil e plist de entitlements próprios para cada app e extensão. Frameworks/dylibs são assinados antes das extensões e apps que os contêm.
- O validador não permite adicionar capabilities que o perfil não conceda; application-identifier e Team ID precisam corresponder.

## Limites técnicos

- A verificação CMS é delegada ao Security do macOS. Trust chain/revogação dependem do trust store e da política do sistema; ainda faltam vetores CMS reais e auditoria independente OCSP/CRL.
- A assinatura Mach-O é delegada a `codesign`; o projeto ainda não implementa um gerador CodeDirectory/SuperBlob próprio.
- O pipeline ainda não foi validado com certificados/perfis reais nem em iPhone físico. CI de sintaxe e testes sintéticos não equivale a assinatura real.
- O helper não importa PKCS#12, não recebe senha e não altera a lista global de keychains. A importação interativa é feita pelo Acesso às Chaves, e a chave privada permanece no keychain escolhido pelo usuário.

## Próximas etapas

1. Testar CMS válido/adulterado, certificados expirados e cadeias não confiáveis.
2. Auditar entitlements efetivos e resource envelope depois da assinatura.
3. Validar instalação e primeiro lançamento em dispositivo real.
4. Extrair a lógica para um Swift Package independente quando os contratos estiverem estáveis.

Nunca registrar senhas, chaves privadas, Apple ID, 2FA, tokens ou UDIDs. Não enviar material de assinatura a serviços externos.
