# Revisão pública do SideInstaller e plano do AutoRenew Installer

**Referência analisada:** https://github.com/FrizzleM/SideInstaller (branch pública `main`, consultada em 2026-10-31).

Esta análise é independente e descritiva. Não copiamos código, assets, protocolo privado, credenciais, certificados ou entitlements do SideInstaller. A licença publicada pelo SideInstaller é uma licença customizada com restrições comerciais e de redistribuição; por isso, AutoRenew implementará suas próprias soluções e não incorporará código-fonte ou binários do projeto.

## Arquitetura observada

1. **Fluxo guiado por etapas:** o motor apresenta estados pending/active/waiting/done/failed e etapas distintas para rede, pairing, conexão, autenticação, download, assinatura, instalação e gravação do pairing.
2. **Separação SwiftUI/Rust:** a interface iOS fica em `ios-app/`; o núcleo de pairing, sessão, certificados, entitlements e comunicação com dispositivo fica em `rust-core/`, exposto por FFI.
3. **Pairing local:** há suporte a pairing file, RPPairing, descoberta local e confirmação de PIN. O README diferencia os requisitos de versões de iOS e quando ainda é necessário preparar pairing em um computador.
4. **Conta e sessão:** a implementação analisada tem AccountStore, Keychain, sessão Apple, fluxo de Anisette e gestão de certificados. Isso é uma decisão sensível de segurança; AutoRenew não passará a recolher senha Apple ID/2FA sem arquitetura e revisão de segurança adequadas.
5. **Certificados e capabilities:** há operações de listagem, importação, revogação e exportação de certificados, além de gestão de App IDs/capabilities.
6. **Downloads e deep links:** suporta links próprios para download de IPA, importação de pairing file e transferência de certificado, com confirmação antes de agir. Mantém inventário de downloads e apresenta progresso/etapas.
7. **Instalação e feedback:** o motor representa o processo como etapas e erros explícitos, em vez de apresentar um download concluído como instalação bem-sucedida.

## Diferenças atuais do AutoRenew Installer

| Área | Estado atual AutoRenew | Próxima melhoria |
|---|---|---|
| Catálogo Stable/Beta/Alpha | Releases públicas GitHub | incluir canal Alpha de Actions claramente separado de Releases |
| Download HTTPS | Implementado | progresso, cancelamento, limite e validação de redirects |
| Importação IPA | Implementada | verificação ZIP completa antes de handoff |
| Deep link | PR #17 em desenvolvimento | download somente após confirmação |
| Pairing local | Não implementado | estudar API pública e requisitos de entitlement |
| Login Apple/Anisette | Não implementado | não coletar credenciais sem modelo de segurança validado |
| Certificados | Importação local .p12 | validação criptográfica e correspondência de perfil |
| Entitlements | Não há fluxo integrado no app | pré-visualização e relatório de menor privilégio |
| Assinatura | Helper experimental macOS | testes reais CMS/Mach-O/recursos e iPhone |
| Instalação on-device | Não implementada | somente por mecanismo suportado e entitlement legítimo |
| Estado de instalação | Handoff via Share Sheet | máquina de estados e confirmação verificável |

## Melhoria aplicada nesta rodada

O AutoRenew Installer passa a aceitar o esquema próprio:

```
autorenewinstaller://install?url=https%3A%2F%2Fexample.com%2Fbuild.ipa
```

O deep link:
- aceita somente ação `install` no esquema `autorenewinstaller`;
- aceita apenas um parâmetro `url`;
- exige URL HTTPS para arquivo `.ipa`;
- rejeita usuário/senha, fragmentos, parâmetros extras, HTTP e extensões diferentes;
- apresenta confirmação antes do download;
- apenas baixa o arquivo. Não instala, não assina e não executa IPA automaticamente;
- mantém a validação de HTTPS também no destino final após redirects.

Testes unitários cobrem links válidos, esquema/ação desconhecidos, HTTP, extensão errada, credenciais, fragmentos e parâmetros extras.

## Plano de evolução

1. Progresso real, cancelamento e retomada segura de downloads.
2. Manifesto local de artefatos Alpha com SHA-256, commit, workflow, target e classificação unsigned/signed.
3. Análise ZIP completa e relatório de integridade antes de compartilhar.
4. Gestão de perfis/certificados com validação criptográfica e compatibilidade por bundle.
5. Máquina de estados para pairing, assinatura, handoff e instalação, sem sucesso falso.
6. Estudo de pairing suportado pelo iOS e teste físico antes de qualquer promessa de instalação sem PC.

## Fontes públicas

- SideInstaller: https://github.com/FrizzleM/SideInstaller
- SideInstaller README: https://github.com/FrizzleM/SideInstaller/blob/main/README.md
- SideInstaller License: https://github.com/FrizzleM/SideInstaller/blob/main/LICENSE.md
- SideStore pairing docs: https://docs.sidestore.io/docs/advanced/anisette
- SideStore install docs: https://docs.sidestore.io/docs/installation/install

**Aviso:** compatibilidade visual ou de fluxo não equivale a compatibilidade técnica. AutoRenew não é afiliado ao SideInstaller ou SideStore.
