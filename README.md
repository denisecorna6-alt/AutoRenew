# AutoRenew

Projeto SwiftUI para iOS 17+ que ajuda a acompanhar manualmente a validade de apps instalados por sideloading no iPhone.

## Estado real da Alpha

- Cadastro manual de nome, Bundle ID e data informada pelo usuário.
- Painel com contagem estimada de dias e estados derivados exclusivamente da data cadastrada.
- Histórico local e lembretes de expiração.
- Importação local de `.mobileprovision`: cópia privada no app, SHA-256, detecção de duplicatas e limite de 25 MB.
- Agendamento em segundo plano experimental, sujeito às decisões do iOS.
- O backend de assinatura está **indisponível**. O placeholder falha de forma segura e nunca simula uma renovação bem-sucedida.
- O app ainda não lê os aplicativos instalados nem decodifica o CMS dos perfis importados; validade, equipe, Bundle ID, UDID e revogação permanecem desconhecidos.
- Não há login Apple funcional, renovação/reassinatura, reinstalação ou revogação implementados.
- O artefato de CI é **unsigned**. Não é instalável diretamente como está; exige assinatura válida e método de instalação compatível.

## Compilar e testar no GitHub Actions

1. Abra **Actions → Build IPA**.
2. Execute manualmente ou envie commits para uma branch `codex/alpha-*`.
3. O workflow gera o projeto com XcodeGen, compila o app e executa os testes unitários no Simulator.
4. Se tudo passar, o workflow anexa um artefato unsigned para inspeção.

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
- Endpoints Anisette configurados precisam usar HTTPS e retornar resposta HTTP válida com metadados esperados.
- Não usar endpoints privados/não documentados, certificados compartilhados ou automação que burle controles da Apple.
- Uma falha de rede nunca deve ser interpretada como certificado revogado.

## Próximas etapas

1. Decodificar e validar o CMS dos perfis importados e extrair metadados verificáveis.
2. Distinguir validade temporal de revogação; estado remoto não será inferido apenas do arquivo local.
3. Integrar um fluxo de assinatura documentado e suportado, condicionado a pareamento, dispositivo e autenticação explícita.
4. Testes em iPhone físico, com logs sem dados sensíveis.
5. Avaliação de automações adicionais somente após comprovação técnica.

Não divulgar esta Alpha como versão de renovação automática funcional.
