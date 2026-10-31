# Revisão técnica pública: SideInstaller

Data da análise: 2026-10-31
Projeto de referência: https://github.com/FrizzleM/SideInstaller
Site oficial informado pelo próprio projeto: https://sideinstaller.net/

Esta é uma análise do código-fonte e da documentação públicos. Não houve engenharia reversa de binário, captura de tráfego privado ou uso de endpoints não documentados no AutoRenew.

## O que o SideInstaller realmente entrega

O SideInstaller é um instalador on-device para preparar SideStore e LiveContainer. Não é apenas um catálogo de IPAs. O código está dividido em:

- ios-app/: interface SwiftUI, estado do fluxo, contas, certificados, pairing, downloads e diagnósticos.
- rust-core/: núcleo Rust exposto ao Swift por FFI; inclui sessão de conta, certificados, entitlements, pairing e integrações com bibliotecas de dispositivo.
- ios-live-activity/: progresso de instalação/pairing no Dynamic Island e tela bloqueada.
- scripts/ e workflows: compilação, publicação do pacote de origem e integração com a distribuição assinada.

O motor de instalação organiza etapas explícitas: rede/VPN, pairing, conexão com o dispositivo, autenticação, download, assinatura, instalação e finalização/importação do pairing. Cada etapa pode ficar pendente, ativa, aguardando ação do usuário, concluída ou falhar. Isso é uma referência importante para UX e recuperação de erros.

## Padrões de produto que vale adaptar

1. Fluxo guiado com estado real: mostrar a etapa atual, progresso, espera por ação humana, erro específico e como recuperar.
2. Pré-checagem antes de assinar: estimar App IDs necessários e limites antes de começar; nunca descobrir tarde que o usuário não tem capacidade disponível.
3. Diagnóstico acionável: erros com código/contexto, causa provável, passo de recuperação, logs redigidos e relatório de problema.
4. Pairing explícito: suportar importação/exportação de pairing files e deixar claras as diferenças entre pairing local/remote e versões de iOS.
5. Links de instalação com consentimento: deep links para IPA e pairing file sempre mostram a origem e pedem confirmação antes de agir.
6. Atividade em segundo plano: Live Activity e retomada de etapas quando o sistema suspende o app, respeitando os limites de cada versão do iOS.
7. Certificados e App IDs: inventário, validade, revogação e uso de certificados existentes, com avisos sobre impacto em outros apps.
8. Logs úteis sem segredos: remover senhas, tokens, cookies, dados de autenticação e pairing secrets dos relatórios.

## Arquitetura que propomos para AutoRenew

| Camada | Situação AutoRenew | Próxima evolução |
|---|---|---|
| Installer UI | Catálogo Stable/Beta/Alpha, download, importação e compartilhamento | Fluxo guiado com estados, retomada e relatórios |
| IPA validation | SHA-256, cabeçalho ZIP e política de tamanho; helper macOS com validação estrutural | Verificação de ZIP central directory, assinatura, profiles, entitlements e compatibilidade |
| Profile Kit | Parser de metadados e helper CMS macOS em Alpha | Fixtures CMS reais, cadeia de confiança e estado de revogação |
| Signing Kit | PKCS#12 matcher e helper macOS com codesign | Testar certificados reais, nested code, resource envelope e entitlements efetivos |
| Pairing | Sem pairing on-device integrado | Contrato de import/export seguro e testes por versão do iOS |
| Device bridge | Helper macOS devicectl e handoff AltStore/SideStore | Diagnóstico de dispositivos e confirmação de instalação |
| Background | Não há motor de instalação em segundo plano | Retomada e Live Activity após validação do fluxo principal |
| Telemetria | Sem telemetria remota | Relatórios locais opt-in, redigidos e exportados pelo usuário |

## Diferenças e limites importantes

- SideInstaller declara suporte on-device a iOS 27+, com pairing file necessário em versões anteriores conforme a sua documentação. Não devemos prometer compatibilidade universal.
- A implementação usa Rust FFI e componentes de pairing/device communication; copiar o comportamento completo exigiria tratar entitlements, pairing, rede local, segurança de conta e compatibilidade por versão.
- O código-fonte público menciona integração com APIs Apple Developer Services. O AutoRenew não deve reproduzir chamadas privadas/não documentadas. Precisamos de caminhos suportados e revisão de segurança antes de qualquer autenticação/assinatura on-device.
- O projeto tem licença própria: leitura/estudo e modificações de fonte são permitidos sob condições, com atribuição e uso não comercial; redistribuir/reempacotar IPAs oficiais ou monetizar requer autorização escrita. Por isso, esta análise não copia nem incorpora código ou binários.
- SideInstaller declara que não é afiliado ao SideStore. AutoRenew também deve manter clara a sua independência.

## Falhas e melhorias encontradas no Installer atual

A revisão do código Alpha identificou dois problemas concretos no catálogo do Installer:

1. Download de assets de Releases verificava HTTP 2xx, mas não conferia a URL final após redirects, limite de tamanho nem nome de arquivo IPA.
2. Download/importação com nome já existente removia o arquivo anterior, podendo destruir uma cópia válida do usuário.

A correção Alpha adiciona política de validação HTTPS e tamanho, inspeciona o arquivo baixado com IPAInspector, e cria nome único sem apagar arquivos existentes. Testes de regressão cobrem redirect inseguro, tamanho/nome inválido e preservação do arquivo anterior.

## Próximas etapas priorizadas

1. Fechar CI e testes da proteção de downloads.
2. Adicionar fluxo guiado de instalação com estados e erros específicos, sem alegar assinatura/instalação inexistentes.
3. Integrar validação de perfil e assinatura ao Installer apenas após testes reais e contratos claros.
4. Implementar importação/exportação de pairing files com armazenamento protegido e redaction.
5. Avaliar pairing on-device apenas em versões suportadas e com permissões/documentação públicas.
6. Adicionar relatórios locais opt-in e Live Activity depois de o fluxo principal estar comprovado.
7. Não ativar login Apple, assinatura remota, refresh automático ou instalação direta até uma revisão de segurança e validação em iPhone físico.

## Fontes primárias

- SideInstaller README: https://github.com/FrizzleM/SideInstaller
- SideInstaller license: https://github.com/FrizzleM/SideInstaller/blob/main/LICENSE.md
- SideInstaller releases: https://github.com/FrizzleM/SideInstaller/releases
- SideStore repository overview: https://git.sidestore.io/SideStore/SideStore

Este documento descreve inspiração e engenharia reversa de código-fonte público, não uma implementação equivalente nem uma afiliação.
