# Central de IAs do AutoRenew (Alpha)

## Dois modos

- **Review:** OpenAI, Claude e Gemini fazem avaliações independentes; OpenAI sintetiza os resultados.
- **Implement:** uma IA propõe um unified diff; as outras duas revisam. O patch só é aplicado se ambas aprovarem e abre uma PR para uma branch Alpha.

## Segurança do executor

- Os jobs Review e Implement fazem checkout explícito da branch principal, nunca da branch escolhida como base.
- O executor confiável é carregado antes de trocar para a branch Alpha. A branch-alvo é tratada como dados: os arquivos são lidos como texto e nunca se executam scripts, testes ou workflows dela no job privilegiado.
- O job Implement tem permissão de escrita em conteúdo e PR apenas durante execução manual; o job Review e o CI do projeto são read-only.
- O patch permite somente Swift, Tests/, docs/ e README.md; bloqueia workflows, project.yml, Keychain, assinatura, certificados, provisioning, Anisette e entitlements.
- Rejeita binários, symlinks, alterações de modo, rename/copy, exclusões, caminhos fora da allowlist e paths com caracteres de controle.
- O job privilegiado faz apenas validação estrutural do patch, git apply, diff staged, commit e abertura de PR. Não executa o código ou os testes da branch-alvo.
- O CI separado da PR executa XcodeGen, Python, shell, builds dos schemes e testes de simulador com token read-only e sem as chaves das APIs.
- Não faz merge, não publica Beta/Stable, não assina nem instala apps.

A PR continua sujeita a revisão humana. A validação estrutural não substitui CI, revisão de código ou testes em dispositivo.

## Segredos

No GitHub: Settings → Secrets and variables → Actions → Repository secrets:
- OPENAI_API_KEY
- ANTHROPIC_API_KEY
- GEMINI_API_KEY

O GitHub não permite ler os valores por este fluxo. A execução falha se uma chave necessária estiver ausente. Nunca inclua Apple ID, senhas, 2FA, tokens de sessão, certificados ou chaves privadas nos campos de tarefa/contexto.

## Como executar

Depois que a central estiver integrada à branch padrão:

1. Abra Actions → AutoRenew AI Central → Run workflow.
2. Escolha Review ou Implement.
3. Informe a tarefa em task.
4. No modo Implement, escolha a IA implementadora.
5. Informe uma branch-base existente com prefixo codex/alpha-.
6. Se as duas revisões aprovarem, o workflow cria uma PR para a branch Alpha. O CI da PR valida o projeto separadamente.

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
