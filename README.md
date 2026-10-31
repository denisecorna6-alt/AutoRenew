# AutoRenew

**Aplicativo iOS para acompanhar datas de validade de apps instalados por sideloading e preparar um fluxo seguro de organização.**

> **Estado atual:** protótipo em desenvolvimento. O backend de renovação é indisponível por padrão; o app não assina, não reinstala e não altera datas de validade como se uma renovação tivesse ocorrido.

## Comece aqui

- [Estado do projeto e roadmap](docs/ROADMAP.md)
- [Notas da Alpha](docs/ALPHA.md)
- [Portal público](https://xlightxt.github.io/AutoRenew/)
- [Issues abertas](https://github.com/xlightxt/AutoRenew/issues)
- [Pull requests](https://github.com/xlightxt/AutoRenew/pulls)
- [Execuções e builds](https://github.com/xlightxt/AutoRenew/actions)
- [Releases](https://github.com/xlightxt/AutoRenew/releases)

## Situação funcional

| Área | Situação |
|---|---|
| Interface SwiftUI e painel | Protótipo inicial com dados de demonstração |
| Lembretes e acompanhamento de validade | Lembretes locais; não lê automaticamente apps instalados |
| Assinatura de IPA | Não implementada |
| Renovação e reinstalação automáticas | Não implementadas |
| Monitoramento de certificados Apple | Não implementado |
| Revogação automática | Não implementada |
| Portal de downloads | Público no GitHub Pages; catálogo de Releases dinâmico |
| Releases públicas | Uma pré-release Alpha; nenhuma Beta ou Stable |
| IPA público | Os IPAs Alpha publicados são unsigned e não instaláveis diretamente |

## Gerar o projeto (macOS)

\`\`\`bash
brew install xcodegen
xcodegen generate
open AutoRenew.xcodeproj
\`\`\`

Uma compilação bem-sucedida não comprova assinatura válida, instalação ou primeiro lançamento em iPhone real.

## Builds e instalação

Os artefatos de CI e os IPAs da Alpha pública são **unsigned**. São pacotes de teste, não instaladores prontos para abrir diretamente no iPhone. A instalação exige assinatura válida e um método compatível, como um fluxo legítimo do SideStore/AltStore. A conta Apple gratuita tem limites e prazos definidos pela Apple.

## Segurança

- A Alpha não solicita nem armazena Apple ID, senha, códigos 2FA, cookies, tokens, certificados privados ou chaves privadas.
- A migração de segurança remove o item de senha legado criado por versões anteriores e regrava o estado local sem os campos antigos de Apple ID/Anisette.
- Nenhum servidor Anisette é consultado enquanto não existir um backend revisado.
- Não use endpoints privados/não documentados da Apple.
- Falha de rede deve resultar em estado desconhecido, nunca em falso diagnóstico de certificado revogado.
- Não revogue certificados de terceiros ou compartilhados.

## Fluxo de desenvolvimento

1. Abra uma Issue para cada tarefa ou defeito.
2. Trabalhe em uma branch específica e envie um Pull Request.
3. Execute validações/CI e registre limitações conhecidas.
4. Mantenha mudanças experimentais como Draft até estarem testadas.
5. Não publique Release nem anuncie renovação real sem teste completo em dispositivo.

## Licença

Consulte o arquivo de licença do repositório, se incluído.
