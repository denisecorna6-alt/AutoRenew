# Assinatura local no macOS (Alpha)

Esta etapa é uma implementação experimental inspirada na separação de fases do SideSign/SideStore. Não é afiliada, fork ou port desses projetos.

## O que o helper faz

`tools/sign-ipa-macos.sh` é um primeiro caminho local, sem serviço remoto:

1. pede ao macOS para verificar a assinatura CMS do provisioning profile (`security cms -V`) antes de decodificar seu plist;
2. importa o PKCS#12 em um keychain temporário e remove esse keychain ao sair;
3. verifica Bundle ID, validade do perfil, Team ID, escopo de dispositivo, DeveloperCertificates e correspondência da identidade;
4. valida que cada entitlement solicitado está autorizado pelo perfil e exige application-identifier/Team ID exatos;
5. assina frameworks e dylibs aninhados, depois o app principal com `codesign`;
6. verifica a assinatura final e reconstrói o IPA.

## Uso

Em um Mac com Xcode e ferramentas de linha de comando:

```sh
export P12_PASSWORD='senha-do-arquivo-p12'
tools/sign-ipa-macos.sh AutoRenew-unsigned.ipa Developer.p12 Development.mobileprovision App.entitlements AutoRenew-signed.ipa
unset P12_PASSWORD
```

A senha não deve ser colocada no histórico do shell, issue, log ou CI. Prefira entrada segura por prompt/gerenciador de segredos local. O helper não envia o P12, perfil ou senha à rede.

## Limites deliberados desta versão

- A verificação CMS é delegada à implementação Security do macOS; a validação da cadeia Apple/revogação depende do trust store e da política do sistema. O helper não promete uma avaliação OCSP/CRL independente.
- Extensões `.appex` são recusadas nesta primeira versão. Cada extensão precisa de seu próprio perfil e arquivo de entitlements de menor privilégio; reutilizar os entitlements do app principal seria incorreto.
- O helper não gera certificados/perfis, não registra UDIDs e não contorna requisitos de assinatura da Apple.
- Não foi validado em um iPhone físico neste commit. CI de código-fonte não substitui teste com certificado/perfil reais.
- O IPA de saída só deve ser chamado assinado se o helper terminar com sucesso; a instalação e o primeiro lançamento precisam ser testados separadamente.

## Próximas etapas

1. matriz de perfis por app/appex e manifesto de entitlements;
2. verificação de trust chain/revogação com política explícita;
3. inspeção de Mach-O, CodeDirectory e resource envelope após assinatura;
4. testes round-trip de ZIP, permissões, symlinks e arquivos grandes;
5. teste de instalação em dispositivo real com perfil válido.
