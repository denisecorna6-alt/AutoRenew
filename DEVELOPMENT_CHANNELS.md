# Canais de desenvolvimento e promoção

## main — referência pública
- Recebe melhorias por Pull Request depois de CI verde, revisão técnica/de segurança e conferência de escopo/diff.
- Correções pequenas e reversíveis podem ser mescladas em main após PR e critérios verdes; não é obrigatório passar por Beta para documentação ou correções de baixo risco.
- Não publicar Release nem anunciar renovação real sem validação completa em dispositivo físico.

## beta — testes de candidatos
- Recebe funcionalidades que precisam de regressão adicional antes de Stable.
- Um build Beta é apenas um artefato de CI até que assinatura, instalação e funcionamento sejam validados.
- Não publicar Release Beta sem regressões aprovadas e teste em dispositivo físico.

## Fluxo de trabalho
1. Criar branch curta a partir da base apropriada (`main` para correções públicas; `beta` para candidatos de promoção).
2. Implementar a menor mudança reversível e adicionar teste de regressão.
3. Abrir PR para a base pretendida; conferir diff, escopo, dependências, licenças e permissões.
4. Exigir CI/checks verdes e revisão de segurança antes do merge.
5. Manter Draft quando faltar teste físico, credencial, autorização, confirmação humana ou validação legal/licença.
6. Promover para Beta somente após regressões aprovadas e teste físico.
7. Publicar Stable somente após validação completa, IPA assinado, instalação e primeiro lançamento em iPhone/iPad, mais aprovação explícita.

## Critérios de segurança
- Nunca solicitar ou armazenar Apple ID, senhas, códigos 2FA, cookies, tokens ou chaves privadas.
- Nunca usar endpoints privados/não documentados da Apple.
- Nunca revogar certificado compartilhado, de terceiros ou de outra conta.
- Nunca tratar erro de rede como revogação.
- Nunca apresentar IPA unsigned como instalável.
- Artefato Actions, IPA unsigned, IPA assinado, instalação validada e primeiro lançamento são estados distintos.
