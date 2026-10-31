# Publicação do portal de downloads

Verificação em **31/10/2026**.

## Estado confirmado

- Página: [https://xlightxt.github.io/AutoRenew/](https://xlightxt.github.io/AutoRenew/).
- Workflow: [.github/workflows/deploy-pages.yml](../.github/workflows/deploy-pages.yml).
- Deploy inicial: [run #41185536948](https://github.com/xlightxt/AutoRenew/actions/runs/41185536948) falhou em Configure Pages com `Get Pages site failed: Not Found`.
- Deploy seguinte: [run #41185796609](https://github.com/xlightxt/AutoRenew/actions/runs/41185796609) concluído com sucesso.
- Deploy mais recente verificado: [run #41208603252](https://github.com/xlightxt/AutoRenew/actions/runs/41208603252), branch `main`, conclusão `success`.
- Inspeção com navegador em 31/10/2026: página e catálogo dinâmico carregaram sem erros JavaScript/rede observados. Stable sem Release, Beta sem Release e Alpha com `alpha-2026.10.31-c1feeb6`.
- O card Beta do portal live exibiu o run #41182023247 (branch `codex/ipa-packaging-validation`, 07:48:09Z), que não é a branch `beta`; o run real da branch `beta` é #41181299910 (07:36:47Z). Isso confirma o bug de classificação no `docs/index.html` de `main`.

## Catálogo e builds observados

- Stable: nenhuma Release.
- Beta: nenhuma Release.
- Alpha: `alpha-2026.10.31-c1feeb6`, com `AutoRenew.ipa` e `AutoRenew-Installer.ipa`, ambos identificados nas notas como unsigned.
- Builds: os cards exibem o estado das execuções do Actions; isso não transforma o artefato em IPA assinado.
- A página ainda não confirma assinatura, instalação no iPhone ou primeiro lançamento.

Esta PR corrige a consulta dos builds para filtrar Alpha por `codex/alpha-*`, Beta por `beta` e Oficial por `main`. A correção só ficará pública após revisão, merge e novo deploy; nenhum deploy foi feito por esta alteração.

## Distinções obrigatórias

1. **Actions artifact:** pacote anexado a uma execução de CI, com prazo de retenção.
2. **IPA unsigned:** arquivo IPA sem assinatura de desenvolvimento; não instalável diretamente.
3. **IPA assinado:** exige assinatura válida, perfil compatível e verificação de código; nenhum está publicado nesta Alpha.
4. **Instalação validada:** exige instalação real em iPhone; ainda não ocorreu.
5. **Primeiro lançamento:** exige abrir o app instalado e confirmar o funcionamento; ainda não ocorreu.

## Segurança

O portal apenas lista Releases e execuções reais. Não pede Apple ID, senha, 2FA, token ou chave privada. Não assina, não instala e não verifica o primeiro lançamento.
