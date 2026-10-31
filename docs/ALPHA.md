# AutoRenew Alpha

Esta compilação de avaliação permite cadastrar manualmente aplicativos, acompanhar as datas informadas e receber lembretes locais. Ela ainda não lê apps instalados nem renova assinaturas.

## O que pode ser avaliado

- Interface SwiftUI para cadastro manual de nome, Bundle ID e data informada de expiração.
- Painel com estados calculados a partir dessa data manual.
- Catálogo de IPAs com fontes JSON no formato AltStore/SideStore (AltSources): busca, versões e download HTTPS para armazenamento local. O catálogo não assina nem instala.
- No AutoRenew Installer, pré-verificação do IPA (extensão, tamanho máximo, cabeçalho ZIP e SHA-256 em streaming) e encaminhamento pelo compartilhamento do iOS para AltStore/SideStore quando disponíveis.
- Persistência local e histórico limitado.
- Importação explícita de arquivos `.mobileprovision`, com cópia privada local, limite de 25 MB, detecção de duplicatas por SHA-256 e opção de remover a cópia importada.
- Inventário de metadados: nome do arquivo, tamanho, data de importação e hash SHA-256.
- Lembretes 48h/24h/6h antes da data cadastrada.
- Agendamento em segundo plano, sujeito às regras e decisões do iOS.

## O que NÃO está implementado

- Login Apple, autenticação de dois fatores ou integração real com SideSign/AltSign/minimuxer.
- Motor próprio de assinatura ou instalação direta dos IPAs. O encaminhamento não instala por si só: o aplicativo receptor executa sua própria assinatura e instalação.
- Leitura automática da lista de apps instalados.
- Decodificação do conteúdo CMS de provisioning profiles e extração/validação de datas, Bundle IDs, equipe, UDID ou estado de revogação.
- Reassinatura, reinstalação ou renovação real de IPA.
- Revogação de certificados, instalação silenciosa ou bypass dos limites do iOS.

O backend `StubSigningBackend` informa que a integração não está implementada. Ele não simula uma nova data de expiração, não altera a validade e não registra sucesso. Os estados no painel derivam exclusivamente das datas inseridas manualmente.

## Segurança e limites

- Esta Alpha não solicita nem persiste senha Apple ID, códigos 2FA, cookies, tokens de sessão ou chaves privadas.
- Na primeira inicialização desta versão, o app remove do Keychain o item legado `applePassword` que versões anteriores podiam ter gravado.
- O fluxo remoto Anisette V3 ainda não está implementado. A versão atual não contata servidores Anisette por padrão; um GET simples à raiz do servidor não substitui a sessão de provisionamento WebSocket e a requisição autenticada de headers.
- O cache Anisette é isolado por actor para evitar acessos concorrentes.
- Não envie credenciais em issues, logs ou mensagens.
- Não use certificados compartilhados, endpoints privados/não documentados ou automação que burle controles da Apple.
- Falhas de rede devem permanecer como estado desconhecido; nunca devem ser interpretadas como revogação.
- Contas Apple gratuitas têm limites e prazos impostos pela Apple; a Alpha não os contorna.

## Próximas etapas

1. Decodificar e validar o CMS do perfil com uma implementação compatível e documentada, sem extrair ou transmitir segredos.
2. Extrair metadados verificáveis e distinguir validade temporal de revogação (que não pode ser inferida apenas pelo arquivo local).
3. Desenvolver uma integração de instalação assistida por computador usando ferramentas Apple documentadas, ou avaliar uma integração on-device com entitlements e APIs oficialmente disponíveis; não reproduzir protocolos privados nem contornar controles do iOS.
4. Testes automatizados, depois testes em iPhone físico com logs sem dados sensíveis.
5. Avaliação de automações adicionais somente após comprovação técnica.

A Alpha não deve ser divulgada como versão de renovação automática funcional.
