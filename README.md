# AutoRenew

**Protótipo SwiftUI para explorar formas mais claras e seguras de acompanhar apps instalados por sideloading no iPhone.**

> **Estado atual (Alpha):** interface e fluxos de demonstração. O backend ativo é `StubSigningBackend`: ele simula uma expiração futura, mas não autentica na Apple, não assina IPA e não reinstala apps. Não use esta versão esperando renovação automática real.

## Comece aqui

- [Estado do projeto e roadmap](docs/ROADMAP.md)
- [Notas da Alpha](docs/ALPHA.md)
- [Publicação do portal de downloads](docs/DEPLOYMENT.md)
- [Kit de comunicação e colaboração](docs/social/2026-10-31.md)
- [Issues abertas](https://github.com/xlightxt/AutoRenew/issues)
- [Pull requests](https://github.com/xlightxt/AutoRenew/pulls)
- [Execuções e builds](https://github.com/xlightxt/AutoRenew/actions)
- [Releases](https://github.com/xlightxt/AutoRenew/releases)

## Situação funcional

| Área | Situação |
|---|---|
| Interface SwiftUI e navegação | Protótipo inicial |
| Dados apresentados no painel | Demonstração; o app ainda não lê os apps instalados no SideStore/AltStore |
| Backend de assinatura | Stub demonstrativo; não executa assinatura |
| Assinatura de IPA | Não implementada |
| Renovação e reinstalação automáticas | Não implementadas |
| Monitoramento real de certificados Apple | Não implementado |
| Revogação de certificados | Não implementada |
| Portal de downloads | HTML e workflow existem; GitHub Pages ainda não foi habilitado para o repositório |
| Releases públicas | Nenhuma publicada |
| Artefatos de CI | Builds sem assinatura; não são instaladores prontos |

## Gerar o projeto (macOS)

```bash
brew install xcodegen
xcodegen generate
open AutoRenew.xcodeproj
```

A geração e a compilação precisam ser verificadas no Xcode. Uma compilação bem-sucedida não comprova instalação, assinatura válida ou funcionamento em iPhone real.

## Builds e instalação

Consulte [GitHub Actions](https://github.com/xlightxt/AutoRenew/actions) para ver as execuções e os artefatos. Os IPAs gerados pela CI são **unsigned** (sem assinatura de desenvolvimento). Eles não podem ser instalados diretamente como se fossem um IPA assinado. Não há Release pública neste momento.

A instalação de um IPA exige assinatura válida e um método compatível, como um fluxo legítimo do SideStore/AltStore. Os limites variam conforme a conta e o método; uma conta Apple gratuita não oferece certificado permanente nem garante renovação silenciosa ilimitada.

## Segurança

- Nunca envie Apple ID, senha, códigos 2FA, cookies, tokens, certificados privados ou arquivos de pareamento em Issues/PRs.
- Não centralize credenciais Apple ou chaves privadas.
- Falha de rede ou indisponibilidade de serviço deve resultar em estado **desconhecido**, nunca em falso diagnóstico de certificado revogado.
- Revogação deve ser desativada por padrão, limitada a certificados próprios e só ocorrer com mecanismo oficialmente suportado e autorização explícita.
- Não use endpoints privados/não documentados da Apple.
- Não anuncie renovação real, assinatura funcional ou IPA pronto sem integração e teste físico comprovados.

## Fluxo de desenvolvimento

1. Abra uma Issue para cada tarefa ou defeito.
2. Trabalhe em uma branch específica e envie um Pull Request.
3. Execute validações/CI e registre limitações conhecidas.
4. Mantenha mudanças experimentais como Draft até estarem testadas.
5. Não mescle PRs nem publique Releases sem aprovação explícita do mantenedor.

## Licença

Consulte o arquivo de licença do repositório, se incluído.
