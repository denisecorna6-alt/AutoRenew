# AutoRenew — estado e roadmap

Atualizado em 2026-10-31.

## Objetivo

Construir um app iOS que acompanhe validade de aplicativos sideloaded e, quando houver suporte técnico e autorização, ajude a manter a assinatura atualizada com segurança.

## O que existe hoje

- Projeto SwiftUI para iOS 17+.
- Estrutura de interface, configurações e logs.
- Backend de assinatura demonstrativo (`StubSigningBackend`): simula o fluxo; não assina nem renova apps.
- Workflows de CI que geram artefatos IPA sem assinatura. A validação do ZIP/Info.plist não comprova instalação ou funcionamento.
- Portal de downloads proposto em PR separado; só poderá listar arquivos de Releases publicadas.

## O que ainda não está pronto

- Integração real de assinatura (AltSign/SideSign) e transporte/instalação (Minimuxer).
- Autenticação Apple e tratamento seguro de 2FA testados em dispositivo.
- Gestão real de certificados e provisioning profiles.
- Verificação diária de estado com fonte suportada e distinção confiável entre válido, expirado, revogado e desconhecido.
- Revogação automatizada. Para Apple IDs gratuitos, a automação pode não estar disponível; nesse caso, oferecer instruções manuais, sem contornar APIs privadas.
- Testes em iPhone físico, incluindo renovação comprovada e recuperação de falhas.

## Sequência recomendada

1. **Base Alpha:** UI identificada como Alpha, avisos claros de simulação e documentação.
2. **Qualidade de build:** validar bundle ID, Info.plist, executável, versão mínima e integridade do IPA; testar instalação assinada.
3. **Integração de assinatura:** avaliar APIs e bibliotecas públicas suportadas; manter segredos no dispositivo/Keychain.
4. **Pareamento e instalação:** integrar o fluxo suportado de instalação e confirmar o resultado no dispositivo.
5. **Saúde dos certificados:** monitoramento não destrutivo, com data da última verificação e estado desconhecido em caso de falha.
6. **Revogação segura:** somente certificados próprios, operação suportada oficialmente, opt-in, verificação de dependências e log de auditoria.
7. **Beta pública:** publicar somente após testes completos e revisão da documentação.

## Regras de segurança e publicação

- Nunca pedir ou armazenar senha Apple, cookies, tokens de sessão ou chave privada em servidor.
- Nunca revogar certificado compartilhado, de terceiros ou de outra conta.
- Nunca tratar erro de rede como revogação.
- Revogar pode quebrar apps já assinados com o certificado.
- Não mesclar PRs, criar tags ou publicar Releases sem aprovação explícita do mantenedor.
- Não descrever builds unsigned como instaladores prontos nem o stub como renovação funcional.

## Acompanhe o trabalho

- [Issues](https://github.com/xlightxt/AutoRenew/issues)
- [Pull requests](https://github.com/xlightxt/AutoRenew/pulls)
- [Actions](https://github.com/xlightxt/AutoRenew/actions)
- [Releases](https://github.com/xlightxt/AutoRenew/releases)
