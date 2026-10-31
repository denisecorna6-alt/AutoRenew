# Central de IAs do AutoRenew (Alpha)

## Dois modos

A central integrada ao branch Alpha completo possui dois modos manuais:

- **Review:** OpenAI, Claude e Gemini fazem avaliações independentes; OpenAI sintetiza os resultados e gera relatório.
- **Implement:** o usuário escolhe qual IA será implementadora. Ela propõe um unified diff; as outras duas revisam independentemente. O patch só é aplicado quando ambas respondem APPROVE. O workflow executa verificações locais e abre uma PR em outra branch Alpha.

## Limites da implementação assistida

- Só aceita branch-base com prefixo codex/alpha-.
- Cria branch `codex/alpha-ai-work-*` e PR direcionada à branch Alpha escolhida.
- A branch-base precisa conter os scripts e workflow da central; a opção padrão é `codex/alpha-ai-orchestrator-20261031`.
- Allowlist de arquivos: Swift, Tests/, docs/ e README.md.
- Bloqueia workflows, configuração de build, Keychain, assinatura, provisioning, certificados, Anisette e entitlements.
- Rejeita remoção de arquivos, patch inválido, divergência de arquivos e falha em diff check/testes locais.
- Pushes Alpha e PRs para a branch integrada acionam `build.yml`: XcodeGen, builds separados de AutoRenew e Installer, testes de simulador quando disponíveis e artefatos Actions explicitamente unsigned. O workflow de build tem somente `contents: read` e não publica Releases.
- O job implementador tem contents: write e pull-requests: write apenas durante execução manual. O job de revisão permanece read-only.
- Não faz merge, não publica Beta/Stable, não assina nem instala apps.
- A PR só deve ser considerada após o workflow `Build separate AutoRenew and Installer test packages` passar e uma pessoa revisar o resultado.

Essa é uma barreira inicial, não uma sandbox perfeita. A saída dos modelos é código não confiável; por isso a PR é obrigatória e os testes do projeto continuam necessários.

## Segredos

No GitHub: Settings → Secrets and variables → Actions → Repository secrets:
- OPENAI_API_KEY
- ANTHROPIC_API_KEY
- GEMINI_API_KEY

O GitHub não permite ler o valor de volta por este fluxo. O script não imprime as chaves. Nunca cole chaves, Apple ID, senhas, certificados privados, tokens ou dados pessoais nos campos de tarefa/contexto.

## Como executar

Depois que a PR Alpha desta central for revisada e integrada à branch `codex/alpha-ai-orchestrator-20261031`:

1. Abra Actions → AutoRenew AI Central → Run workflow.
2. Escolha Review ou Implement.
3. Informe a tarefa em task.
4. No modo Implement, escolha a IA implementadora (OpenAI, Claude ou Gemini).
5. Informe uma branch-base Alpha existente, por exemplo codex/alpha-ai-central-20261031.
6. Execute. Se os dois revisores aprovarem e as verificações passarem, o workflow abrirá uma PR para a branch Alpha. Caso contrário, não aplica patch nem abre PR.

A central é manual; não é um agente 24/7. Chamadas às APIs podem gerar cobrança independente em cada provedor.

## Modelos padrão verificados na documentação pública

- OpenAI: gpt-6.1-sol (Responses API)
- Ações GitHub: checkout v7.0.1, setup-python v7.1.0 e upload-artifact v7.0.2 (Node 24).
- Claude: claude-sonnet-5-5 (Messages API)
- Gemini: gemini-3.8-flash (generateContent)

Os modelos e preços podem mudar; confira a documentação dos provedores.

## Referências oficiais

- OpenAI Models: https://developers.openai.com/api/docs/models
- OpenAI Responses: https://developers.openai.com/api/reference/resources/responses
- Anthropic Models: https://platform.claude.com/docs/pt-BR/models/overview
- Anthropic Messages: https://platform.claude.com/docs/en/api/messages/create
- Gemini Models: https://ai.google.dev/gemini-api/docs/models
- Gemini generateContent: https://ai.google.dev/api/generate-content
