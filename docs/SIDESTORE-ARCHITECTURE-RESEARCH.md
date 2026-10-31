# Pesquisa técnica: arquitetura do SideStore e integração segura no AutoRenew

Data da análise: 2026-10-31

## Resumo executivo

O SideStore não é um único instalador que possa ser copiado para dentro do AutoRenew. É um sistema composto por aplicativo iOS, bibliotecas de assinatura, transporte/descoberta de dispositivos, um mecanismo especial de instalação via VPN/loopback e fontes de catálogo.

A análise foi feita a partir dos READMEs, árvore de código, manifesto Swift Package e diretrizes de contribuição públicos do SideStore e do SideSign. Não foi feita engenharia reversa de binários proprietários nem interceptação de tráfego ou credenciais.

**Decisão para o AutoRenew:** reutilizar os padrões arquiteturais e implementar integração por adaptadores isolados. Não incorporar agora o fluxo de autenticação Apple/Anisette nem o mecanismo de instalação do SideStore, porque dependem de protocolos privados/entitlements especiais e conflitam com as regras de segurança já documentadas no AutoRenew.

## 1. Como o SideStore funciona

### 1.1 Aplicativo principal

O aplicativo iOS é sandboxed e contém a experiência de gerenciamento: fontes, downloads, apps instalados, atualização/refresh, configurações e estado da conta. A documentação descreve o SideStore como fork comunitário do AltStore.

### 1.2 SideSign

O SideSign é uma biblioteca Swift separada. O README e o Package.swift públicos indicam estes blocos:

- AppBundleSigner: re-assinatura de .app, executáveis Mach-O, extensões, plugins e frameworks aninhados.
- CodeSignKit: CMS/PKCS#7, PKCS#12 e assinatura Mach-O.
- CertificateParser / PKCS12Parser: leitura de certificados e arquivos .p12.
- DeveloperPortal: equipes, App IDs, App Groups, dispositivos, certificados e provisioning profiles.
- AnisetteKit e GSACryptoKit: dados Anisette e autenticação GrandSlam/SRP.
- Archive: extração e reconstrução de IPA preservando permissões POSIX.

Exemplo de API descrito no README upstream:

~~~swift
let signer = AppBundleSigner(team: team, keyStore: keyStore)
try await signer.signApp(
    at: appURL,
    provisioningProfiles: [profile]
)
~~~

Esse exemplo é apenas referência de integração; não prova que a API seja compatível com o target, deployment target ou arquitetura atuais do AutoRenew.

### 1.3 Minimuxer

O Minimuxer implementa uma camada de multiplexação/descoberta de serviços de dispositivos baseada no protocolo usbmuxd/lockdown, para que o app consiga falar com serviços locais do dispositivo. Não é equivalente a uma API pública genérica de instalação.

### 1.4 EM Proxy / LocalDevVPN

O README do SideStore descreve o EM Proxy como parte do mecanismo de instalação untethered: um app/helper com entitlements especiais cria o túnel VPN local e utiliza um método de loopback. O README também explica que o Minimuxer encontra os serviços do dispositivo para interagir com esse componente.

Isso não pode ser reproduzido apenas adicionando uma dependência Swift Package ao AutoRenew. Exige targets auxiliares, entitlements e provisioning compatíveis, configuração de VPN, pareamento e testes em dispositivo físico. Não há garantia de que a Apple conceda os entitlements necessários a um app independente.

### 1.5 SideSource

SideSource é uma solução separada para compor catálogos de apps a partir de GitHub Releases, outras fontes e configurações remotas. É a parte mais segura e independente para inspirar uma primeira integração: catálogo JSON, metadados, canais e cache, sem autenticação Apple nem instalação privilegiada.

### 1.6 Fluxo real observado no código-fonte

A leitura dos arquivos de operação da branch pública develop confirma que o fluxo é uma cadeia de etapas, não uma chamada única:

1. SignInOperation obtém credenciais por meio de um handler, solicita dados Anisette e chama AuthManager para autenticar; depois resolve a equipe.
2. DeviceRegistrationFlow obtém o identificador do dispositivo e consulta/registra o dispositivo na equipe.
3. CertificateProvisioningFlow consulta certificados da equipe e pode solicitar/substituir um certificado.
4. FetchProvisioningProfilesOperation obtém os perfis para o app e extensões.
5. VerifyCertificateOperation compara certificados ativos do portal e pode recorrer a OCSP.
6. ResignAppOperation prepara o bundle, ajusta IDs/entitlements/perfis e assina o app.
7. InstallAppOperation entrega o bundle re-assinado ao fluxo de instalação e atualiza os metadados locais.
8. RefreshAppOperation atualiza perfis/estado da instalação; o fluxo de refresh também coordena operações de instalação.

Arquivos de referência:
- SignInOperation: https://github.com/SideStore/SideStore/blob/develop/SideStore/Core/Operations/StandaloneOperations/SignInOperation.swift
- DeviceRegistrationFlow: https://github.com/SideStore/SideStore/blob/develop/SideStore/Core/Auth/Flows/DeviceRegistrationFlow.swift
- CertificateProvisioningFlow: https://github.com/SideStore/SideStore/blob/develop/SideStore/Core/Auth/Flows/CertificateProvisioningFlow.swift
- VerifyCertificateOperation: https://github.com/SideStore/SideStore/blob/develop/SideStore/Core/Operations/PipelineOperations/VerifyCertificateOperation.swift
- ResignAppOperation: https://github.com/SideStore/SideStore/blob/develop/SideStore/Core/Operations/PipelineOperations/ResignAppOperation.swift
- InstallAppOperation: https://github.com/SideStore/SideStore/blob/develop/SideStore/Core/Operations/PipelineOperations/InstallAppOperation.swift
- RefreshAppOperation: https://github.com/SideStore/SideStore/blob/develop/SideStore/Core/Operations/PipelineOperations/RefreshAppOperation.swift
- EMProxyWrapper: https://github.com/SideStore/SideStore/blob/develop/SideStore/Core/DeviceApi/EMProxyWrapper.swift
- MinimuxerWrapper: https://github.com/SideStore/SideStore/blob/develop/SideStore/Core/DeviceApi/MinimuxerWrapper.swift

**Diferença importante para o AutoRenew:** o código upstream tem um fluxo de autenticação Apple/Anisette e gestão de sessão/credenciais. O README atual do AutoRenew proíbe expressamente coletar ou armazenar Apple ID, senha, 2FA, cookies e tokens. Portanto, não copiar esse SignInOperation nem as rotinas de sessão para o AutoRenew. A integração segura começa no catálogo, validação e exportação para um instalador externo já configurado pelo usuário.

## 2. O que pode ser aproveitado agora

| Componente/padrão | Decisão | Motivo |
|---|---|---|
| Modelo de catálogo SideSource | Adaptar | Dados públicos e releases; sem fluxo de assinatura |
| Pipeline de validação de IPA | Implementar no AutoRenew | ZIP, Payload, Info.plist, bundle ID, arquitetura e integridade |
| Separação entre assinatura, catálogo e instalação | Adotar | Evita backend fictício e facilita testes |
| SideSign completo | Não integrar ainda | GPL-3.0, dependências e autenticação privada/Anisette exigem revisão |
| GrandSlam / Anisette | Não implementar agora | Protocolo não documentado oficialmente pela Apple; risco de conta e privacidade |
| Minimuxer + EM Proxy | Não portar agora | Entitlements, VPN/loopback, helper e pareamento específicos |
| Rotina de refresh do SideStore | Usar como referência de UX/estado | Não copiar pressupostos de instalação nem prometer renovação em background |

## 3. Bloqueios de compatibilidade e segurança

1. **Política atual do AutoRenew:** README e roadmap proíbem endpoints privados/não documentados da Apple, coleta de Apple ID/senha/2FA, cookies, tokens ou chaves privadas. A implementação de GrandSlam/Anisette não deve ser ligada sem uma decisão explícita de produto e uma revisão de segurança — e não deve ser tratada como API oficial.
2. **Licenças:** SideStore declara AGPL-3.0; SideSign declara GPL-3.0. O repositório AutoRenew não apresenta um arquivo LICENSE na árvore consultada. Antes de distribuir um binário que incorpore código GPL/AGPL, é necessário definir a licença do AutoRenew e revisar compatibilidade, obrigações de disponibilização do código-fonte e avisos de terceiros. Não copiar arquivos upstream sem cumprir essas obrigações.
3. **Contribuição ao upstream:** as diretrizes públicas do SideStore restringem contribuições geradas por LLM e proíbem agentes de abrir PRs/issues/comentários automatizados. Esta análise é independente; não será enviada contribuição automatizada ao SideStore.
4. **iOS e entitlements:** uma compilação bem-sucedida não concede LocalDevVPN nem garante instalação por loopback. É necessário provisionamento autorizado e validação em iPhone real.
5. **Limites do iOS:** tarefas de background são oportunistas; não podem ser apresentadas como garantia de renovação em horário exato.

## 4. Arquitetura recomendada para o AutoRenew

Manter o SigningBackend fail-closed atual e evoluir para interfaces explícitas:

- CatalogProvider: lê fontes JSON/GitHub Releases públicas (Stable/Beta/Alpha), valida schema, URLs HTTPS e metadados.
- IPAPreflightValidator: verifica estrutura ZIP, Payload/*.app, Info.plist, Bundle ID, versão, arquitetura e arquivos esperados; não altera nem assina o IPA.
- SigningCapability: descreve capacidades reais do backend (inspecionar, importar identidade, assinar, verificar); não declara disponibilidade por configuração estática.
- SigningBackend: só pode retornar sucesso depois de produzir e verificar assinatura e provisioning profile válidos. Erro ou ausência de credencial mantém estado unknown/falha; nunca altera validade ficticiamente.
- InstallationBackend: adaptador separado para um método de instalação suportado e autorizado. Não assumir que o app iOS pode instalar outros apps sem o helper/entitlement apropriado.
- CertificateHealthProvider: distingue valid, expired, revoked e unknown; falha de rede sempre resulta em unknown.
- RefreshCoordinator: orquestra estados e lembretes; não tenta autenticação ou instalação quando os adaptadores não estão disponíveis.

Fluxo:

1. Buscar catálogo público.
2. Baixar IPA para área temporária.
3. Validar estrutura e metadados.
4. Exibir requisitos e limites de assinatura.
5. Quando houver backend legítimo configurado, assinar em ambiente seguro.
6. Verificar assinatura, entitlements e perfil.
7. Delegar instalação a um método compatível.
8. Atualizar validade apenas após confirmação verificável; caso contrário, manter estado anterior.

## 5. Plano de implementação por etapas

### Etapa A — segura e independente (próxima)

- Criar CatalogProvider para feeds JSON/GitHub Releases.
- Criar IPAPreflightValidator com testes para IPA inválido, ZIP corrompido, Payload ausente, Bundle ID ausente e arquitetura incompatível.
- Adicionar estado explícito notConfigured, ready, failed, unknown.
- Preservar StubSigningBackend indisponível e bloquear qualquer sucesso simulado.

### Etapa B — assinatura sem autenticação privada

- Avaliar ferramentas e APIs oficiais/documentadas para assinatura local com certificado e provisioning profile fornecidos pelo próprio usuário.
- Manter chave privada no Keychain/ambiente local; nunca enviar para GitHub Actions ou backend remoto.
- Verificar a assinatura produzida antes de reportar sucesso.
- Fazer revisão de licença antes de adicionar dependências GPL.

### Etapa C — instalação e refresh

- Primeiro oferecer exportação/compartilhamento para SideStore/AltStore já instalado pelo usuário.
- Investigar instalação independente apenas se existir caminho autorizado para entitlements e helper.
- Testar pareamento, VPN, retomada, falhas e reinstalação em dispositivos físicos.
- Não prometer refresh automático até validar os limites de BackgroundTasks e o ciclo de assinatura.

### Etapa D — Beta

- Testes unitários e de integração.
- IPA assinado com perfil válido.
- Instalação e primeiro lançamento em iPhone real.
- Verificação de regressão, privacidade e licenças.
- Só então promover para Beta.

## 6. Referências primárias

- SideStore README: https://github.com/SideStore/SideStore/blob/develop/README.md
- SideStore agent/contribution rules: https://github.com/SideStore/SideStore/blob/develop/AGENTS.md
- SideSign README: https://github.com/SideStore/SideSign/blob/main/README.md
- SideSign Package.swift: https://github.com/SideStore/SideSign/blob/main/Package.swift
- SideStore docs: https://docs.sidestore.io/
- SideStore FAQ: https://docs.sidestore.io/docs/faq
- SideStore Anisette docs: https://docs.sidestore.io/docs/advanced/anisette
- SideSource: https://github.com/SideStore/SideSource

## Resultado desta análise

A integração direta do SideStore inteiro não é tecnicamente nem legalmente apropriada como primeira mudança. O caminho de menor risco é implementar primeiro catálogo + validação IPA + contratos de backend no AutoRenew, mantendo assinatura e instalação desabilitadas até haver uma solução documentada, licenciada e testada em dispositivo.


## 7. Referências oficiais Apple para o caminho suportado

- App Store Connect API — Provisioning: https://developer.apple.com/documentation/appstoreconnectapi (recursos de Bundle IDs, Certificates, Devices e Profiles).
- Profiles API: https://developer.apple.com/documentation/appstoreconnectapi/profiles
- Criar perfil de desenvolvimento: https://developer.apple.com/help/account/provisioning-profiles/create-a-development-provisioning-profile
- Distribuir para dispositivos registrados: https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices
- Background Tasks: https://developer.apple.com/documentation/uikit/using-background-tasks-to-update-your-app

A Apple documenta perfis como vínculos entre App ID, certificados e dispositivos; o App Store Connect API permite gerenciar esses recursos. O sistema decide quando executa tarefas de background, então o AutoRenew deve oferecer lembretes e tentativas oportunistas, não prometer execução exata em segundo plano.
