# AutoRenew

**Acompanhe a validade dos seus apps sideloaded no iPhone — com foco em transparência, segurança e automação.**

[![Build IPA](https://github.com/denisecorna6-alt/AutoRenew/actions/workflows/build.yml/badge.svg)](https://github.com/denisecorna6-alt/AutoRenew/actions/workflows/build.yml)

> **Status: em desenvolvimento.** O acompanhamento de validade e os alertas estão em implementação. A renovação/reinstalação automática com SideSign + Minimuxer ainda não está pronta. Esta versão não renova apps nem estende prazos artificialmente.

## O que já funciona nesta versão

- Interface SwiftUI para cadastrar apps manualmente com nome, Bundle ID e data de expiração.
- Persistência local dos apps e do histórico.
- Alertas locais programados antes da expiração.
- Histórico de verificações e falhas.
- Agendamento de tarefas em segundo plano (sujeito às regras do iOS; o sistema não garante execução em horário exato).
- Credenciais guardadas no Keychain, sem serem usadas até o fluxo SideSign estar integrado.

## O que estamos construindo

- Login Apple com verificação em duas etapas via SideSign.
- Gestão de certificados e provisioning profiles.
- Importação, extração e assinatura de IPA.
- Instalação/reinstalação no iPhone usando Minimuxer e pareamento válido.
- Testes de ponta a ponta em dispositivo físico.

## Como testar o acompanhamento

1. Baixe o IPA de um workflow concluído em **Actions → Build IPA → Artifacts → AutoRenew-ipa**.
2. Instale usando SideStore/AltStore.
3. Abra o AutoRenew e cadastre o nome, Bundle ID e validade exibida pelo seu instalador.
4. Permita notificações para receber alertas antes do vencimento.

O IPA da CI é empacotado sem assinatura de desenvolvimento. A instalação deve ser feita por um instalador de sideloading compatível.

## Compilar no Mac

```bash
brew install xcodegen
xcodegen generate
open AutoRenew.xcodeproj
```

## Contribuir

Issues e pull requests são bem-vindos. Veja o roadmap e os bloqueios conhecidos em [CONTRIBUTING.md](CONTRIBUTING.md). Não envie senhas, cookies, tokens, certificados privados ou arquivos de pareamento em issues.

## Segurança e limitações conhecidas

- Não há login Apple ativo nem renovação automática nesta versão.
- O cadastro da validade é manual; o app ainda não consegue ler os apps instalados no SideStore.
- A integração Minimuxer precisa de pairing file válido e transporte de dispositivo configurado.
- O target VPN/Network Extension não é incluído na build padrão; exige entitlements próprios.
- O iOS decide quando executar tarefas de background; alertas locais são a alternativa mais confiável para lembrar o vencimento.
- Não use credenciais de produção para testar código de integração ainda não revisado.

## Licença

Consulte o arquivo de licença do repositório.
