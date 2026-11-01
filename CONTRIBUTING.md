# Contributing to AutoRenew

Obrigado por considerar contribuir!

## Prioridades atuais

1. Cobrir com testes a fronteira fail-closed do backend.
2. Revisar a API oficial do SideSign e o modelo real de Anisette antes de qualquer adaptador.
3. Definir a licença do AutoRenew e verificar compatibilidade antes de adicionar dependências copyleft.
4. Avaliar o transporte Minimuxer/Swift-Bridge e seus pré-requisitos de dispositivo.
5. Validar qualquer integração completa em iPhone real antes de declarar renovação concluída.

## Integrações oficiais: estado e bloqueios

### SideSign

Fonte oficial: https://github.com/SideStore/SideSign

- O pacote exporta `DeveloperPortal.authenticate(...)`, que recebe Apple ID, senha, `AnisetteData` e um callback opcional para verificação em duas etapas.
- A assinatura de bundles usa `AppBundleSigner(team:keyStore:)` e `signApp(at:provisioningProfiles:)`.
- O `Package.swift` atual usa Swift tools 6.0 e dependências apontadas para branches, portanto uma futura integração deve fixar revisões imutáveis e revisar a árvore de dependências.
- O README oficial declara licença GPL-3.0.

Esta branch não solicita nem persiste Apple ID, senha, códigos 2FA, sessões ou material privado. Por isso, a autenticação SideSign não foi ligada. O repositório AutoRenew ainda não possui arquivo `LICENSE`; a dependência não deve ser adicionada antes de uma decisão explícita sobre a licença do projeto e a compatibilidade GPL.

### Minimuxer

Fonte oficial: https://github.com/jkcoxson/minimuxer

- O projeto é Rust e expõe funções via `swift-bridge`; o README descreve a geração de biblioteca estática/XCFramework.
- A FFI atual inclui `start(pairing_file, log_path)`, `yeet_app_afc(bundle_id, ipa_bytes)`, `install_ipa(bundle_id)` e `install_provisioning_profile(profile)`.
- O transporte depende de um pairing record válido e de uma conexão real do dispositivo pelo mecanismo usado pelo SideStore (em_proxy/LocalDevVPN).
- O repositório declara licença AGPL-3.0.

Nenhum pairing file, UDID, certificado privado ou dado de dispositivo será solicitado ou armazenado nesta etapa. Sem um dispositivo pareado e sem decisão de licença, não é seguro ligar a FFI nem afirmar que uma instalação ocorreu.

## Regras de segurança

- Nunca abra PR contendo Apple ID/senha, cookies, tokens, códigos 2FA, certificados privados, provisioning profiles privados, pairing files ou dados pessoais.
- Não registre segredos nos logs nem os envie para serviços remotos.
- Não interprete resposta de rede, assinatura local ou cópia de IPA como confirmação de instalação.
- Não declare renovação bem-sucedida até a instalação e a validação terem sido confirmadas no dispositivo.
- Mantenha o acompanhamento manual utilizável quando o backend de assinatura estiver indisponível.
- Não revogue certificados ou perfis automaticamente.
- Teste em dispositivo real antes de marcar integração como concluída.

## Pull requests

Descreva o problema, o comportamento esperado, como testou e quais dispositivos/versões do iOS foram usados. Inclua apenas logs sanitizados quando necessário.
