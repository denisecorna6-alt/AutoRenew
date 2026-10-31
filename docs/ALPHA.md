# AutoRenew Alpha

Esta é uma compilação inicial de avaliação. O objetivo é validar a navegação, o painel de apps, o histórico e os lembretes antes de conectar qualquer mecanismo real de assinatura.

## O que já pode ser avaliado

- Interface SwiftUI do painel, lista de apps e histórico.
- Cadastro de apps de demonstração.
- Lembretes locais com permissão solicitada somente após tocar em **Ativar lembretes**; no máximo 60 notificações pendentes, sujeitas às regras de entrega do iOS.
- Orientação de interface declarada para iPhone em retrato/paisagem e iPad em quatro orientações.
- Mensagens explícitas de que a renovação real não está disponível.

## O que NÃO está implementado

- Cadastro de apps reais na branch principal; a lista ainda usa dados de demonstração.

- Login Apple, autenticação de dois fatores ou integração real com AltSign/SideSign/Minimuxer.
- Reassinatura, reinstalação ou renovação real de IPA.
- Leitura automática de apps instalados ou monitoramento real de certificados e perfis.
- Revogação de certificados.
- Instalação silenciosa ou bypass dos limites do iOS.

O StubSigningBackend declara isAvailable = false e falha com notImplemented. O coordenador interrompe o fluxo antes de qualquer chamada de rede; nenhuma data de validade é estendida e nenhum sucesso de renovação é registrado.

## Segurança e limites

- A interface não solicita nem armazena Apple ID, senha, códigos 2FA, cookies, tokens ou chaves privadas.
- A migração remove somente o item de Keychain legado com a conta exata applePassword e regrava um snapshot válido sem os campos antigos de Apple ID/Anisette.
- Nenhum servidor Anisette é consultado enquanto não existir um backend revisado.
- Não use certificados compartilhados ou de terceiros.
- Falhas de rede devem resultar em estado desconhecido, nunca em certificado revogado.
- Qualquer futura ação de revogação exige mecanismo documentado, autorização explícita e verificação de dependências.
- Contas Apple gratuitas têm limites e prazos impostos pela Apple; a Alpha não os contorna.

## Próxima sequência de trabalho

1. Validar a experiência e corrigir bugs da interface.
2. Definir um inventário local não sensível de perfis/certificados.
3. Adicionar monitoramento não destrutivo com estados válido, próximo do vencimento, expirado, revogado e desconhecido.
4. Avaliar apenas integrações documentadas e suportadas, sem pedir credenciais no AutoRenew.
5. Testar assinatura/instalação somente com autorização e em dispositivo físico, sem alegar sucesso antes da verificação.

A Alpha não deve ser divulgada como versão de renovação automática funcional.
