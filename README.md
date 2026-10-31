# AutoRenew

Protótipo SwiftUI para iOS 17+ voltado ao monitoramento e à preparação de fluxos de renovação de apps assinados.

## Estado real da Alpha

- O painel, histórico, preferências e agendamento são componentes experimentais.
- Os prazos exibidos são dados de demonstração; ainda não são lidos de perfis ou certificados reais.
- O backend de assinatura está **indisponível**. O placeholder falha de forma segura e nunca simula uma renovação bem-sucedida.
- Não há login Apple funcional, renovação/reassinatura, reinstalação ou revogação implementados.
- O artefato de CI é **unsigned**. Não é instalável diretamente como está; exige assinatura válida e método de instalação compatível.
- O agendamento em segundo plano depende das decisões do iOS e não garante execução em horário exato.

## Compilar e testar no GitHub Actions

1. Abra **Actions → Build IPA**.
2. Execute manualmente ou envie commits para uma branch `codex/alpha-*`.
3. O workflow gera o projeto com XcodeGen, compila o app e executa os testes unitários no Simulator.
4. Se tudo passar, o workflow pode anexar um artefato unsigned para inspeção.

O sucesso da compilação não comprova assinatura, instalação ou renovação real em iPhone.

## Compilar localmente (Mac)

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project AutoRenew.xcodeproj -scheme AutoRenew \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```

## Segurança

- A Alpha não solicita nem armazena senha Apple ID, códigos 2FA, cookies, tokens de sessão ou chaves privadas.
- Na primeira inicialização desta versão, a chave legada `applePassword` das versões Alpha anteriores é removida do Keychain.
- Endpoints Anisette configurados precisam usar HTTPS e retornar resposta HTTP válida.
- Não usar endpoints privados/não documentados, certificados compartilhados ou automação que burle controles da Apple.
- Uma falha de rede nunca deve ser interpretada como certificado revogado.

## Próximas etapas

1. Inventário local e não destrutivo de perfis/certificados reais.
2. Estados de monitoramento verificáveis: válido, próximo do vencimento, expirado, revogado e desconhecido.
3. Integração com fluxo de assinatura documentado e suportado, condicionado a pareamento, dispositivo e autenticação explícita do usuário.
4. Testes em iPhone físico, com logs sem dados sensíveis.
5. Avaliação de automações adicionais apenas após comprovação técnica.

Não divulgar esta Alpha como aplicativo de renovação automática funcional.
