# AutoRenew — estado e roadmap

Atualizado em 2026-10-31.

## Objetivo

Construir um app iOS que acompanhe datas de validade de aplicativos sideloaded e ajude o usuário a organizar a manutenção de instalações, sem contornar limites ou mecanismos de segurança do iOS.

## O que existe hoje

- Projeto SwiftUI para iOS 17+.
- Estrutura inicial de interface, configurações e logs com dados de demonstração.
- StubSigningBackend indisponível por padrão: não autentica, não assina, não reinstala, não chama serviços Anisette e não altera datas de validade.
- Lembretes locais com permissão opt-in, limite de 60 notificações pendentes e controle de entrega pelo iOS; não há leitura automática da lista de apps instalados.
- Suporte de orientação declarado para iPhone (retrato/paisagem) e iPad (quatro orientações).
- Workflows de CI que geram artefatos IPA unsigned. Build e integridade ZIP não comprovam assinatura ou instalação.
- Portal público no [GitHub Pages](https://xlightxt.github.io/AutoRenew/), com catálogo dinâmico de Releases.
- Uma pré-release Alpha pública, alpha-2026.10.31-c1feeb6, com AutoRenew.ipa e AutoRenew-Installer.ipa, ambos unsigned. Não há Release Beta ou Stable.
- Nenhum IPA assinado, instalação em iPhone ou primeiro lançamento foi validado.

## O que ainda não está pronto

- Cadastro manual de apps reais: a interface principal ainda usa dados de demonstração; a branch Alpha com cadastro manual permanece em revisão.

- Integração real de assinatura e transporte/instalação.
- Monitoramento automático confiável do estado de certificados.
- Gestão de perfis/certificados integrada a fluxos documentados.
- Testes ponta a ponta em iPhone físico.
- Compatibilidade validada com o SDK iOS 27.2/Xcode 27.2. Official CI e Official IPA usam Xcode 26.6/iOS 26.5; o workflow legado Build IPA e o Installer Alpha ainda usam Xcode 16.4/iOS 18.5.

## Sequência recomendada

1. **Base Alpha:** UI identificada como Alpha, sem coleta de credenciais e sem simular renovação.
2. **Qualidade de build:** validar bundle ID, Info.plist, executável, versão mínima e integridade do IPA.
3. **Integração:** avaliar somente APIs públicas/documentadas e bibliotecas compatíveis com as licenças.
4. **Instalação:** validar assinatura, perfil e instalação em iPhone real, com autorização.
5. **Saúde dos certificados:** monitoramento não destrutivo, distinguindo válido, expirado, revogado e desconhecido.
6. **Beta:** somente após regressões aprovadas, assinatura e teste físico.
7. **Stable:** somente após validação completa, instalação e primeiro lançamento em dispositivo.

## Regras de segurança e publicação

- Nunca solicitar ou armazenar Apple ID, senha, códigos 2FA, cookies, tokens ou chaves privadas.
- Nunca usar endpoints privados/não documentados da Apple.
- Nunca revogar certificado compartilhado, de terceiros ou de outra conta.
- Nunca tratar erro de rede como revogação.
- Não publicar Releases sem validação completa e aprovação específica.
- Não descrever artefatos unsigned como instaladores prontos.

## Acompanhe o trabalho

- [Issues](https://github.com/xlightxt/AutoRenew/issues)
- [Pull requests](https://github.com/xlightxt/AutoRenew/pulls)
- [Actions](https://github.com/xlightxt/AutoRenew/actions)
- [Releases](https://github.com/xlightxt/AutoRenew/releases)
