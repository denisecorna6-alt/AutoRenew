# AutoRenew — estado e roadmap

Atualizado em 2026-10-31.

## Objetivo

Construir um app iOS que acompanhe a validade de aplicativos sideloaded e, quando houver suporte técnico, autorização e um fluxo compatível, ajude o usuário a manter suas instalações organizadas com segurança.

## O que existe hoje

- Projeto SwiftUI para iOS 17+.
- Estrutura inicial de interface, configurações e logs.
- Backend demonstrativo (`StubSigningBackend`) que simula uma nova expiração; não autentica, não assina e não reinstala apps.
- Workflows de CI que geram artefatos IPA sem assinatura. O sucesso de um build ou a integridade de um ZIP não comprovam instalação ou funcionamento.
- Portal de downloads em `docs/index.html` e workflow de deploy em `.github/workflows/deploy-pages.yml`; a publicação está bloqueada porque GitHub Pages ainda não está habilitado/configurado no repositório. Consulte [DEPLOYMENT.md](DEPLOYMENT.md).
- Nenhuma Release pública publicada até esta atualização.

## O que ainda não está pronto

- Integração real de assinatura (AltSign/SideSign) e transporte/instalação (Minimuxer).
- Autenticação Apple e tratamento seguro de 2FA testados em dispositivo.
- Gestão real de certificados e provisioning profiles.
- Leitura automática da lista de apps instalados em SideStore/AltStore.
- Verificação diária de estado com fonte suportada e distinção confiável entre válido, expirado, revogado e desconhecido.
- Revogação automatizada. Para Apple IDs gratuitos, a automação pode não estar disponível; nesse caso, oferecer instruções manuais, sem contornar APIs privadas.
- Testes de ponta a ponta em iPhone físico, incluindo assinatura, instalação, renovação comprovada e recuperação de falhas.
- Portal publicado e validado por HTTP após habilitação do GitHub Pages.

## Sequência recomendada

1. **Base Alpha:** UI identificada como Alpha, avisos claros de simulação e documentação honesta.
2. **Qualidade de build:** validar bundle ID, Info.plist, executável, versão mínima e integridade do IPA; testar instalação assinada.
3. **Integração de assinatura:** avaliar APIs e bibliotecas públicas suportadas; manter segredos no dispositivo/Keychain.
4. **Pareamento e instalação:** integrar o fluxo suportado e confirmar o resultado no dispositivo.
5. **Saúde dos certificados:** monitoramento não destrutivo, com data da última verificação e estado desconhecido em caso de falha.
6. **Revogação segura:** somente certificados próprios, operação suportada oficialmente, opt-in, verificação de dependências e log de auditoria.
7. **Beta pública:** publicar somente após testes completos, assinatura/instalação verificadas e revisão da documentação.
8. **Stable:** somente depois de builds reproduzíveis, testes automatizados, validação de pacote/assinatura, notas de versão, regressões e teste físico.

## Pull requests em avaliação

- [#1 — Harden AutoRenew signing status and prepare integration](https://github.com/xlightxt/AutoRenew/pull/1): proposta para não simular sucesso enquanto o backend real não existe.
- [#3 — Add AutoRenew branding, About page and supporter information](https://github.com/xlightxt/AutoRenew/pull/3): identidade e página Sobre.
- [#5 — Harden Beta and Official IPA packaging](https://github.com/xlightxt/AutoRenew/pull/5): validação de bundle ID, executável, Info.plist e ZIP.

Essas propostas continuam sujeitas a revisão; este documento não implica aprovação ou merge.

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
- [Portal (ainda não publicado)](https://xlightxt.github.io/AutoRenew/)
