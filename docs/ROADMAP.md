# AutoRenew — estado e roadmap

Atualizado em 2026-10-31.

## Estado atual
- App iOS SwiftUI em desenvolvimento.
- O backend padrão é `StubSigningBackend` e agora falha explicitamente: não renova, não estende validade e não registra sucesso.
- A renovação real ainda não está conectada a autenticação, assinatura e instalação verificadas.
- Builds de CI sem assinatura são artefatos de teste, não releases instaláveis.

## Próximas etapas
1. Validar a base de build, testes e segurança.
2. Integrar mecanismo público e suportado de assinatura, com credenciais e chaves no dispositivo.
3. Implementar 2FA interativo e gestão de sessão no Keychain.
4. Implementar inspeção segura de IPA, profiles e entitlements.
5. Implementar transporte pareado e confirmar instalação no dispositivo.
6. Só então conectar o backend real ao coordenador de renovação.
7. Testar em iPhone físico e documentar limites de conta/assinatura.

## Segurança
- Sem APIs privadas/não documentadas, bypass de 2FA ou contorno de limites Apple.
- Sem senhas, tokens, cookies, códigos 2FA ou chaves privadas em Git/logs.
- Falha de rede é estado desconhecido, nunca evidência de revogação.
- Nenhuma revogação ou exclusão automática de certificados, profiles ou dispositivos.
- Não declarar renovação real antes de assinatura, instalação e nova validade verificadas no dispositivo.
- Não distribuir IPA nem publicar releases sem validação e autorização específicas.
