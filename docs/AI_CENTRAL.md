# Central de IAs do AutoRenew (Alpha)

## Dois modos

- **Review:** OpenAI, Claude e Gemini fazem avaliações independentes; OpenAI sintetiza os resultados.
- **Implement:** uma IA propõe um unified diff; as outras duas revisam. Se ambas aprovarem, um job separado publica uma PR em branch Alpha.

## Separação de privilégios

O modo Implement é dividido em dois jobs:

1. **propose (read-only):** faz checkout de main, lê a branch Alpha selecionada apenas como texto, chama os provedores e produz patch/relatório. Não tem permissão de escrita no GitHub; o checkout não persiste credenciais.
2. **publish (write-only):** recebe o artefato, valida novamente caminhos e tipos, aplica o patch e abre a PR. Recebe somente o token GitHub de escrita; não recebe chaves OpenAI, Anthropic ou Gemini e não executa código ou testes da branch-alvo.

Outras proteções:

- Review, propose, publish e validate fazem checkout explícito da branch principal. A branch escolhida como base é buscada separadamente.
- O patch permite somente Swift, Tests/, docs/ e README.md; bloqueia workflows, project.yml, Keychain, assinatura, certificados, provisioning, Anisette e entitlements.
- Rejeita binários, symlinks, alterações de modo, rename/copy, exclusões, caminhos fora da allowlist e paths com caracteres de controle.
- O publisher verifica também se os diretórios existentes no destino não são symlinks.
- O CI do projeto executa separadamente com permissões read-only, sem chaves de provedores.
- O antigo executor combinado foi desativado.
- Não há merge, publicação Beta/Stable, assinatura ou instalação automática.

A validação estrutural não substitui CI, revisão humana ou testes em iPhone físico.

## Segredos

No GitHub: Settings → Secrets and variables → Actions → Repository secrets:
- OPENAI_API_KEY
- ANTHROPIC_API_KEY
- GEMINI_API_KEY

O GitHub não permite ler os valores por este fluxo. A execução falha se uma chave necessária estiver ausente. As chaves só ficam no job read-only de proposta/revisão; nunca são entregues ao job com permissão de escrita. Nunca inclua Apple ID, senhas, 2FA, tokens de sessão, certificados ou chaves privadas nos campos de tarefa/contexto.

## Como executar

Depois que a central estiver integrada à branch padrão:

1. Abra Actions → AutoRenew AI Central → Run workflow.
2. Escolha Review ou Implement.
3. Informe a tarefa em task.
4. No modo Implement, escolha a IA implementadora.
5. Informe uma branch-base existente com prefixo codex/alpha-.
6. Se as duas revisões aprovarem, o job publish abre uma PR para a branch Alpha. O CI da PR valida o projeto separadamente.

A central é manual, não é um agente 24/7. As chamadas podem gerar cobrança em cada provedor. Claude/Gemini só são chamados se as respectivas chaves de API reais estiverem configuradas; não há fallback que simule esses provedores.

## Modelos padrão documentados em 31/10/2026

- OpenAI: gpt-6.1-sol (Responses API).
- Anthropic: claude-sonnet-5-5 (Messages API).
- Gemini: gemini-3.8-flash (generateContent).

Confirme disponibilidade, limites e custos diretamente nos provedores antes de uso.

## Referências oficiais

- OpenAI Models: https://developers.openai.com/api/docs/models
- OpenAI Responses: https://developers.openai.com/api/reference/resources/responses
- Anthropic Claude Sonnet 5.5: https://platform.claude.com/docs/en/models/sonnet-5-5/overview
- Anthropic Messages: https://platform.claude.com/docs/en/api/messages/create
- Gemini Models: https://ai.google.dev/gemini-api/docs/models
- Gemini generateContent: https://ai.google.dev/api/generate-content
