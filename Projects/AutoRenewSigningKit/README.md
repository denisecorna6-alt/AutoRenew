# AutoRenewSigningKit

**Inspiração:** organização modular de identidade, certificados, assinatura e entitlements do SideSign. Projeto independente, escrito para AutoRenew.

## Objetivo

Ser o núcleo de preparação e assinatura de código. Não deve depender de SwiftUI nem executar autenticação por endpoints privados.

## Primeira etapa existente

O Alpha contém `SigningIdentityProfileMatcher`: importa PKCS#12 em memória, confirma identidade/certificado/chave privada e compara o certificado DER com `DeveloperCertificates` do perfil. A senha é usada apenas na importação e não é persistida.

Isso é uma verificação de correspondência inicial, não uma assinatura. Ainda não verifica cadeia/revogação completa nem gera CodeDirectory/CMS de assinatura.

## Evolução

1. Gerenciamento de identidade com Keychain e operações de importação/remoção auditáveis.
2. Validação da cadeia X.509, validade, EKU e correspondência com o perfil.
3. Resolução determinística de entitlements permitidos, sem elevar privilégios.
4. Assinatura Mach-O com formato e ferramentas suportados/documentados.
5. Assinar frameworks, dylibs, extensões e demais componentes aninhados na ordem correta.
6. Verificar assinatura, recursos selados, entitlements e integridade do pacote depois de assinar.
7. Criar testes de fixtures e vetores criptográficos, incluindo falhas e perfis incompatíveis.

## Segurança

Nunca registrar senhas, chaves privadas, certificados privados, Apple ID, 2FA, tokens ou UDIDs. Não enviar material de assinatura para serviços externos. A operação deve falhar fechada quando a cadeia, perfil ou entitlements não forem confiáveis.
