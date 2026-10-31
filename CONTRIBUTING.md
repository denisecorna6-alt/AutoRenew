# Contributing to AutoRenew

Obrigado por considerar contribuir!

## Prioridades atuais

1. Integrar a autenticação SideSign e o fluxo 2FA sem expor credenciais.
2. Mapear o modelo Anisette do SideSign corretamente (não converter respostas HTTP genéricas em headers inventados).
3. Integrar certificados, provisioning profiles e assinatura de IPA.
4. Implementar o transporte Minimuxer com pareamento seguro e validar no iPhone.
5. Criar testes para persistência, notificações, agendamento e erros de assinatura.

## Regras de segurança

- Nunca abra PR contendo Apple ID/senha, cookies, tokens, certificados privados, pairing files ou dados pessoais.
- Não registre segredos nos logs.
- Não declare renovação bem-sucedida até a instalação e validação terem sido confirmadas.
- Mantenha funcionalidades de rastreamento utilizáveis quando o backend de assinatura estiver indisponível.
- Teste em dispositivo real antes de marcar integração como concluída.

## Pull requests

Descreva o problema, o comportamento esperado, como testou e quais dispositivos/versões do iOS foram usados. Inclua logs sanitizados quando necessário.
