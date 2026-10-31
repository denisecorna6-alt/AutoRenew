# Canais de desenvolvimento e promoção

## main — Oficial
- É a linha de referência para builds estáveis.
- Recebe apenas mudanças revisadas que passaram pelo CI da branch beta e pelo CI de promoção.
- Não prometer renovação automática enquanto o SigningBackend real não estiver integrado e validado em dispositivo.
- Releases oficiais exigem validação manual em iPhone, registro de versão/notas e aprovação explícita do mantenedor.

## beta — Testes
- Recebe funcionalidades novas, refatorações e integrações experimentais.
- Builds são pré-lançamento e podem conter bugs; não usar como única cópia de dados importantes.
- Toda mudança deve vir por PR, com escopo, riscos, passos de teste e resultado esperado.
- Falhas devem virar issue com logs sem dados pessoais, certificados, tokens ou segredos.

## Fluxo de promoção
1. Desenvolver em branch curta baseada em beta.
2. Abrir PR para beta; CI executa geração do projeto e compilação iOS Simulator.
3. Corrigir falhas e revisar diff.
4. Testar manualmente em dispositivo e registrar evidências para recursos que dependem de iOS real.
5. Promover beta para main somente após aprovação e CI verde.
6. Criar tag/release oficial somente após aprovação explícita.

## Critérios mínimos
- Build sem erros.
- Testes automatizados disponíveis aprovados.
- Sem segredos no repositório.
- README e changelog atualizados.
- Funcionalidade documentada sem exagerar o que foi testado.
- Recursos de assinatura, certificados, Anisette, SideSign e Minimuxer exigem testes reais; compilação não comprova funcionamento.
