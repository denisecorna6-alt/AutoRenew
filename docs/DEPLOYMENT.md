# Publicação do portal de downloads

Verificação feita em **31/10/2026**.

## Estado confirmado

- Página-fonte: [docs/index.html](index.html).
- Workflow: [.github/workflows/deploy-pages.yml](../.github/workflows/deploy-pages.yml).
- Última tentativa de deploy observada: [Deploy download portal #2](https://github.com/xlightxt/AutoRenew/actions/runs/41185796609).
- Resultado: falhou na etapa **Configure Pages**. O log retornou `Get Pages site failed: Not Found`; as etapas de upload e deploy foram ignoradas.
- A URL pública [https://xlightxt.github.io/AutoRenew/](https://xlightxt.github.io/AutoRenew/) respondeu 404 na verificação. Portanto, o portal ainda não está publicado.

## Como habilitar uma vez

Uma pessoa com permissão de administração no repositório precisa:

1. Abrir [Settings → Pages](https://github.com/xlightxt/AutoRenew/settings/pages).
2. Em **Build and deployment**, selecionar **GitHub Actions** como Source.
3. Salvar a configuração.
4. Voltar a [Actions](https://github.com/xlightxt/AutoRenew/actions/workflows/deploy-pages.yml) e executar novamente **Deploy download portal**.

A documentação oficial do GitHub descreve essa configuração em [Using custom workflows with GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).

## Por que não habilitar com um token no workflow?

A ação `actions/configure-pages` mantém `enablement` desativado por padrão. A documentação da ação informa que a habilitação automática exige um token diferente de `GITHUB_TOKEN`, com permissões administrativas/Pages adicionais. Não devemos criar nem armazenar um Personal Access Token só para contornar a configuração inicial; a mudança manual nas configurações do repositório é mais simples e mantém o segredo fora do código.

## Checklist depois da habilitação

- [ ] O workflow termina com sucesso.
- [ ] A URL pública responde HTTP 200.
- [ ] Os links de código, roadmap e instruções abrem.
- [ ] O estado vazio informa que ainda não há Releases, sem inventar downloads.
- [ ] Os links de artefatos levam às execuções corretas do Actions.
- [ ] O aviso de IPA sem assinatura continua visível.
- [ ] Nenhuma versão é chamada de Stable sem assinatura e testes reais.

**Importante:** o portal apenas apresenta Releases e artefatos reais. Ele não assina IPA, não instala apps no iPhone e não transforma um artefato unsigned em instalador pronto.
