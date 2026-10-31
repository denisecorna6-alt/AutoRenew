# AutoRenew Alpha

Esta é uma compilação inicial de avaliação. O objetivo é validar a navegação, o painel de apps, o histórico e o fluxo de teste antes de conectar qualquer mecanismo real de assinatura.

## O que já pode ser avaliado

- Interface SwiftUI do painel, lista de apps e histórico.
- Cadastro de apps de demonstração.
- Agendamento, notificações e execução em primeiro plano/background, sujeitos às regras do iOS.
- Mensagens de estado que deixam explícito que a renovação ainda é simulada.

## O que NÃO está implementado

- Login Apple funcional, autenticação de dois fatores ou integração real com AltSign/minimuxer.
- Reassinatura, reinstalação ou renovação real de IPA.
- Leitura/monitoramento real de certificados e perfis.
- Revogação de certificados.
- Instalação silenciosa ou bypass dos limites do iOS.

O backend atual é `StubSigningBackend`: ele simula uma nova expiração de sete dias. O sucesso nos logs não significa que um app foi assinado ou instalado novamente.

## Segurança e limites

- Não envie senha Apple ID, códigos 2FA, cookies, tokens ou chaves privadas em issues, logs ou mensagens.
- Não use certificados compartilhados ou de terceiros.
- Uma falha de rede deve ser classificada como estado desconhecido, nunca como certificado revogado.
- Qualquer futura ação de revogação deve ser explícita, limitada a credenciais próprias e precedida por verificação de dependências.
- Contas Apple gratuitas têm limites e prazos impostos pela Apple; a Alpha não os contorna.

## Próxima sequência de trabalho

1. Validar a experiência e corrigir bugs da interface.
2. Implementar inventário local de perfis/certificados sem guardar segredos em servidor.
3. Adicionar monitoramento não destrutivo com estados válido, próximo do vencimento, expirado, revogado e desconhecido.
4. Integrar um fluxo de renovação suportado e documentado, condicionado a dispositivo, pareamento e autenticação do usuário.
5. Só depois avaliar revogação assistida e automações.

A Alpha não deve ser divulgada como versão de renovação automática funcional.
