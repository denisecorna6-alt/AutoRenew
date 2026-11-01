# AutoRenew

**Acompanhe a validade dos seus apps sideloaded no iPhone — com foco em transparência, segurança e automação.**

[![Build IPA](https://github.com/xlightxt/AutoRenew/actions/workflows/build.yml/badge.svg)](https://github.com/xlightxt/AutoRenew/actions/workflows/build.yml)

> **Status: em desenvolvimento.** O acompanhamento de validade e os alertas estão em implementação. A renovação/reinstalação automática com SideSign + Minimuxer ainda não está pronta. Esta versão não renova apps nem estende prazos artificialmente.

## O que já funciona nesta versão

- Interface SwiftUI para cadastrar apps manualmente com nome, Bundle ID e data de expiração.
- Persistência local dos apps e do histórico.
- Alertas locais programados antes da expiração.
- Histórico de verificações e falhas.
- Agendamento de tarefas em segundo plano (sujeito às regras do iOS; o sistema não garante execução em horário exato).
- Nenhuma credencial Apple, senha, código 2FA, token, certificado privado ou pairing file é solicitado ou armazenado.

## O que estamos construindo

- Avaliação da autenticação e do modelo Anisette do SideSign, condicionada à decisão de licença e a um fluxo de autorização compatível com a política de não coletar credenciais.
- Gestão de certificados e provisioning profiles, sem revogação automática.
- Importação, inspeção e assinatura de IPA.
- Instalação/reinstalação no iPhone usando Minimuxer, somente após decisão de licença e validação do transporte em dispositivo real.
- Testes de ponta a ponta em dispositivo físico.

## Como testar o acompanhamento

1. Gere um build de CI na branch de desenvolvimento.
2. Instale usando SideStore/AltStore.
3. Abra o AutoRenew e cadastre o nome, Bundle ID e validade exibida pelo seu instalador.
4. Permita notificações para receber alertas antes do vencimento.

O IPA da CI é empacotado sem assinatura de desenvolvimento. A instalação deve ser feita por um instalador de sideloading compatível.

## Testes

O workflow de CI executa testes XCTest no simulador quando há um dispositivo disponível; caso contrário, compila o bundle de testes. Os testes atuais garantem que o backend indisponível nunca retorna uma nova validade.

## Compilar no Mac

```bash
brew install xcodegen
xcodegen generate
open AutoRenew.xcodeproj
```

## Contribuir

Issues e pull requests são bem-vindos. Veja o estado das integrações e os bloqueios conhecidos em [CONTRIBUTING.md](CONTRIBUTING.md). Não envie senhas, cookies, tokens, certificados privados ou arquivos de pareamento em issues.

## Segurança e limitações conhecidas

- Não há login Apple ativo nem renovação automática nesta versão.
- O cadastro da validade é manual; o app ainda não consegue ler os apps instalados no SideStore.
- A integração Minimuxer depende de pairing file válido e transporte de dispositivo configurado; nenhum desses dados é solicitado ou armazenado.
- O target VPN/Network Extension não é incluído na build padrão; exige entitlements próprios.
- O iOS decide quando executar tarefas de background; alertas locais são a alternativa mais confiável para lembrar o vencimento.
- O repositório ainda não tem arquivo de licença. SideSign (GPL-3.0) e Minimuxer (AGPL-3.0) não serão adicionados como dependências antes de uma decisão de compatibilidade.

## Licença

A licença do AutoRenew ainda precisa ser definida.
