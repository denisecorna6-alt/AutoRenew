# AutoRenew

Aplicativo iOS para acompanhar a validade de apps instalados por sideloading e preparar um fluxo seguro de renovação.

> **Estado atual:** projeto em desenvolvimento. A renovação real ainda não está implementada. O backend de demonstração falha explicitamente e nunca estende a validade dos apps.

## Situação funcional

| Área | Situação |
|---|---|
| Interface SwiftUI e painel | Estrutura inicial |
| Lembretes e acompanhamento | Parcial |
| Assinatura de IPA | Não conectada |
| Renovação/reinstalação automática | Não implementada |
| Monitoramento de certificados | Planejado |
| Revogação automática | Não implementada |
| Artefatos IPA de CI | Builds sem assinatura; não são releases instaláveis |

## Segurança

- Senhas, 2FA, cookies, tokens e chaves privadas nunca devem ser enviados em Issues/PRs.
- Falhas de rede resultam em estado desconhecido, nunca em revogação presumida.
- O backend de demonstração não altera a validade nem registra sucesso.
- Não usar APIs privadas/não documentadas nem contornar 2FA ou limites Apple.
- Build de simulador não comprova assinatura ou instalação em iPhone real.

Consulte [roadmap](docs/ROADMAP.md), [issues](https://github.com/xlightxt/AutoRenew/issues), [PRs](https://github.com/xlightxt/AutoRenew/pulls) e [Actions](https://github.com/xlightxt/AutoRenew/actions).
