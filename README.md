# AutoRenew

**Acompanhe · Gerencie · Renove**

AutoRenew é um projeto open source em desenvolvimento para acompanhar aplicativos e organizar fluxos de renovação de assinaturas de sideloading.

## Estado real do projeto

- Interface SwiftUI para lista de apps, registros e ajustes.
- Alertas e agendamento local sujeitos às limitações de execução em segundo plano do iOS.
- Integração real de assinatura/renovação ainda em desenvolvimento: o backend atual é um stub e não deve ser tratado como renovação funcional.
- A renovação automática não pode ser garantida enquanto o fluxo completo não estiver integrado e validado em dispositivo.

## Gerar o IPA

1. Abra **Actions → Build IPA** no GitHub.
2. Execute o workflow manualmente.
3. Baixe o artefato `AutoRenew.ipa` quando a compilação terminar com sucesso.
4. Instale usando um método de sideloading compatível e a sua própria assinatura.

O artefato de CI é uma compilação de teste; não representa uma versão pronta para produção nem substitui testes em dispositivo.

## Apoie o projeto

Contribuições são voluntárias e não dão acesso a recursos especiais.

- **Pix (chave aleatória):** `7e67da92-268c-4a69-8a4c-eca7d01da74b`

## Parceiros e afiliados

Nenhum link de afiliado está cadastrado no momento. Links de parceiros serão adicionados somente após validação e serão identificados claramente como links afiliados. A utilização será sempre opcional.

## Desenvolvimento e colaboração

Issues e pull requests são bem-vindos. Não envie senhas, códigos 2FA, cookies, certificados privados ou outros segredos para o repositório.

## Gerar localmente (Mac)

```sh
brew install xcodegen
xcodegen generate
open AutoRenew.xcodeproj
```

## Licença

Consulte os arquivos de licença do repositório.
