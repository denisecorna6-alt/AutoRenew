# AutoRenew

**Aplicativo iOS para acompanhar a validade de apps instalados por sideloading e preparar um fluxo seguro de renovação.**

> **Estado atual:** projeto em desenvolvimento. A renovação real ainda não está implementada. O backend atual é um stub de demonstração; não trate esta versão como renovador automático funcional.

## Comece aqui

- [Estado do projeto e roadmap](docs/ROADMAP.md)
- [Issues abertas](https://github.com/xlightxt/AutoRenew/issues)
- [Pull requests](https://github.com/xlightxt/AutoRenew/pulls)
- [Execuções e builds](https://github.com/xlightxt/AutoRenew/actions)
- [Releases](https://github.com/xlightxt/AutoRenew/releases)

## Situação funcional

| Área | Situação |
|---|---|
| Interface SwiftUI e painel | Estrutura inicial |
| Lembretes e acompanhamento de validade | Parcial; depende da branch/versão |
| Assinatura de IPA | Não implementada no backend atual |
| Renovação e reinstalação automáticas | Não implementadas |
| Monitoramento de certificados Apple | Planejado; não conectado a uma API real |
| Revogação automática | Não implementada; exige suporte oficial, propriedade verificada e autorização explícita |
| Portal de downloads | Em revisão; ainda não é um site publicado |
| IPA de CI | Artefatos de teste sem assinatura; não são releases instaláveis diretamente |

## Gerar o projeto (macOS)

```bash
brew install xcodegen
xcodegen generate
open AutoRenew.xcodeproj
```

A geração e a compilação precisam ser verificadas no Xcode e em um iPhone real antes de declarar uma versão pronta.

## Instalar builds

Os artefatos atuais de CI são **unsigned**. Eles não podem ser instalados diretamente como se fossem um IPA assinado. Use um fluxo legítimo de assinatura no dispositivo, como SideStore/AltStore, e siga as limitações da conta Apple utilizada. Uma conta Apple gratuita não fornece certificados permanentes nem garante renovação silenciosa ilimitada.

## Segurança

- Nunca envie Apple ID, senha, códigos 2FA, cookies, tokens, certificados privados ou arquivos de pareamento em Issues/PRs.
- Não centralize credenciais Apple ou chaves privadas.
- Falha de rede ou indisponibilidade de serviço deve resultar em estado **desconhecido**, nunca em falso diagnóstico de certificado revogado.
- Revogação deve ser desativada por padrão, limitada a certificados próprios e só ocorrer com mecanismo oficialmente suportado e autorização explícita.
- Não use endpoints privados/não documentados da Apple.

## Fluxo de desenvolvimento

1. Abra uma Issue para cada tarefa ou defeito.
2. Trabalhe em uma branch específica e envie um Pull Request.
3. Execute validações/CI e registre limitações conhecidas.
4. Mantenha mudanças experimentais como Draft até estarem testadas.
5. Não publique Release nem anuncie renovação real sem teste completo em dispositivo.

## Licença

Consulte o arquivo de licença do repositório, se incluído.
