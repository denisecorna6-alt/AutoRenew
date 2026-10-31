# Central de IAs do AutoRenew (Alpha)

## Objetivo

Executar três revisões independentes:
- OpenAI: coordenação e síntese crítica.
- Anthropic Claude: revisão independente, com ênfase em segurança e qualidade.
- Google Gemini: revisão independente, com ênfase em testes e compatibilidade.

## Estado e limites

Primeira versão experimental, acionada manualmente pelo GitHub Actions. Envia a tarefa e o contexto digitado pelo operador às três APIs, gera relatório Markdown e disponibiliza artefato por 14 dias.

Não altera arquivos, cria commits, abre PRs, faz merge, publica releases, instala apps nem executa comandos sugeridos pelas IAs. As respostas são recomendações até serem verificadas por uma pessoa e por testes.

Não roda em agenda e não é agente 24/7. Execuções podem gerar cobrança nas três plataformas.

## Segredos necessários

No GitHub: Settings → Secrets and variables → Actions → Repository secrets.
- OPENAI_API_KEY
- ANTHROPIC_API_KEY
- GEMINI_API_KEY

O código não imprime os valores das chaves. Nunca inclua credenciais, dados pessoais, Apple ID, tokens, certificados privados ou arquivos de provisionamento no contexto.

## Como executar

Depois que este PR for revisado e integrado à branch padrão:

1. Abra Actions.
2. Selecione AutoRenew AI Central.
3. Toque em Run workflow.
4. Escolha a branch Alpha que contém a tarefa/código relevante.
5. Preencha task e, opcionalmente, context sem segredos.
6. Inicie a execução.
7. Baixe o artefato ai-central-report no run concluído.

O workflow precisa existir na branch padrão para aparecer no menu de execução manual. Enquanto este PR não for integrado à branch padrão, apenas a validação automática por push estará disponível.

## Modelos padrão

- OpenAI: gpt-5.5
- Claude: claude-sonnet-5-5
- Gemini: gemini-3.8-flash

Os nomes são configuráveis no workflow e devem ser revistos conforme disponibilidade, preços e descontinuações.

## Segurança e governança

- Permissão do workflow: somente contents: read.
- Sem pull_request_target, sem execução privilegiada de código externo e sem permissões de escrita.
- Sem cron; cada análise é iniciada pelo usuário.
- Limites de texto e timeout de rede.
- Erros HTTP são truncados e a chave é removida da mensagem.
- Nenhuma chave é colocada em arquivos, logs intencionais ou artefatos.
- Não habilitar commits, merge ou publicação com base apenas na saída dos modelos.
- Revisar custos e limites de uso dos provedores.

## Referências oficiais

- OpenAI Chat Completions: https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create
- Anthropic Messages: https://platform.claude.com/docs/en/api/messages/create
- Gemini generateContent: https://ai.google.dev/api/generate-content
