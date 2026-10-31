# AutoRenew — projetos complementares

> **Aviso de inspiração:** estes projetos são iniciativas independentes do AutoRenew, inspiradas publicamente nas ideias de arquitetura e nos fluxos observáveis do [SideSign](https://github.com/SideStore/SideSign) e do [SideStore](https://github.com/SideStore/SideStore). Não são projetos oficiais, forks, ports nem produtos afiliados a esses projetos. O código será escrito para o AutoRenew, com APIs, testes e decisões próprias.

## Por que separar projetos

O AutoRenew principal deve continuar sendo o aplicativo e a experiência do usuário. As responsabilidades criptográficas e de empacotamento precisam ser módulos independentes, para que possam ser testadas, auditadas e reutilizadas sem misturar UI, armazenamento e assinatura.

## Projetos

| Projeto | Responsabilidade | Estado |
|---|---|---|
| [AutoRenewProfileKit](AutoRenewProfileKit/README.md) | Ler e validar metadados de provisioning profiles e compatibilidade | Parser inicial no app Alpha; extração CMS ainda não valida assinatura |
| [AutoRenewSigningKit](AutoRenewSigningKit/README.md) | Identidades, certificados, chaves, entitlements e pipeline de assinatura | Preparação inicial no Alpha; ainda não assina |
| [AutoRenewArchiveKit](AutoRenewArchiveKit/README.md) | Inspecionar, extrair e reconstruir IPA/ZIP com integridade | Planejamento; inspector atual é apenas pré-verificação ZIP |
| [AutoRenewInstallBridge](AutoRenewInstallBridge/README.md) | Encaminhar instalações por mecanismos documentados e verificáveis | Handoff para AltStore/SideStore e helper macOS em Alpha; sem instalação on-device própria |

## Como a inspiração será aplicada

- **SideSign:** separação entre importação de identidade, certificados, perfis, entitlements, assinatura de código e reconstrução do pacote.
- **SideStore:** catálogo de fontes, fluxo de download, handoff e atenção às limitações de instalação e autenticação no iOS.
- **Licenças:** o repositório SideStore inclui AGPL-3.0. O README do SideSign declara GPL-3.0, mas a árvore atual do repositório não contém um arquivo LICENSE que permita verificar o grant; trate a licença como não verificada e não copie código. Qualquer dependência futura exige revisão legal e de compatibilidade. Nenhum código ou binário foi copiado.

## Como vamos melhorar

1. Definir contratos pequenos entre módulos e manter a UI fora do núcleo criptográfico.
2. Criar testes unitários e fixtures sintéticas; nunca incluir certificados, perfis, UDIDs, tokens ou dados pessoais reais nos testes.
3. Validar CMS, cadeia de certificados, validade, revogação quando houver fonte documentada, Bundle ID, Team ID, dispositivos e entitlements antes de permitir assinatura.
4. Assinar todos os executáveis e componentes aninhados exigidos pelo formato iOS, e verificar a assinatura final antes de reconstruir/publicar o IPA.
5. Preservar metadados, permissões e estrutura do pacote, com tratamento seguro de ZIP, limites de tamanho e prevenção de path traversal.
6. Separar claramente download, pré-verificação, assinatura, instalação e renovação. Cada estado só será mostrado quando houver evidência técnica.
7. Rodar CI por módulo, testes de regressão e validação em dispositivo real antes de promover qualquer capacidade para Beta/Stable.

## Integração com o AutoRenew principal

Os projetos serão desenvolvidos em Alpha primeiro. O app principal continuará responsável por interface, catálogo, inventário de apps, notificações e coordenação. Os módulos fornecerão operações explícitas e resultados tipados. Nenhum módulo poderá alegar sucesso de renovação apenas porque um arquivo foi baixado ou uma etapa local terminou.

## Limites atuais

No estado atual, o AutoRenew não implementa assinatura completa, autenticação Apple Developer, instalação genérica no iPhone ou renovação automática funcional. Os IPAs gerados no CI são unsigned. Esta documentação é o plano de projetos; cada capacidade só será considerada entregue depois de código, testes e validação correspondentes.
