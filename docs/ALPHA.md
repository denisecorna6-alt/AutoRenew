# AutoRenew Alpha

Esta compilação de avaliação valida a navegação, o painel, o histórico e os fluxos locais. Ela ainda não renova aplicativos.

## O que pode ser avaliado

- Interface SwiftUI do painel, lista de itens de demonstração e histórico.
- Preferências locais e persistência.
- Agendamento e notificações, sujeitos às regras e decisões do iOS.
- Registro transparente de tentativas não executadas.

## O que NÃO está implementado

- Login Apple, autenticação de dois fatores ou integração real com AltSign/minimuxer.
- Reassinatura, reinstalação ou renovação real de IPA.
- Inventário real de certificados/perfis e leitura confiável da validade.
- Revogação de certificados.
- Instalação silenciosa ou bypass dos limites do iOS.

O backend `StubSigningBackend` falha com `notImplemented`. Ele não simula uma nova data de expiração, não altera a validade e não registra sucesso. Os itens e datas atuais são dados de demonstração.

## Segurança e limites

- Esta Alpha não solicita nem persiste senha Apple ID, códigos 2FA, cookies, tokens de sessão ou chaves privadas.
- A tela de Ajustes não oferece campos para credenciais Apple.
- Na primeira inicialização desta versão, o app remove do Keychain o item legado `applePassword` que versões anteriores podiam ter gravado.
- Provedores Anisette configurados precisam usar HTTPS e retornar HTTP 2xx com metadados esperados.
- Não envie credenciais em issues, logs ou mensagens.
- Não use certificados compartilhados, endpoints privados/não documentados ou automação que burle controles da Apple.
- Falhas de rede devem permanecer como estado desconhecido; nunca devem ser interpretadas como revogação.
- Qualquer futura ação de revogação deve ser explícita e precedida de verificação de dependências.
- Contas Apple gratuitas têm limites e prazos impostos pela Apple; a Alpha não os contorna.

## Próximas etapas

1. Inventário local e não destrutivo de perfis/certificados reais.
2. Estados verificáveis: válido, próximo do vencimento, expirado, revogado e desconhecido.
3. Integração com fluxo de assinatura documentado e suportado, condicionado a pareamento, dispositivo e autenticação explícita.
4. Testes automatizados, depois testes em iPhone físico com logs sem dados sensíveis.
5. Avaliação de automações adicionais somente após comprovação técnica.

A Alpha não deve ser divulgada como versão de renovação automática funcional.
