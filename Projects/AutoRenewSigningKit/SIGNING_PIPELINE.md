# Assinatura local no macOS (Alpha)

Esta etapa é uma implementação experimental inspirada na separação de fases do SideSign/SideStore. Não é afiliada, fork ou port desses projetos.

## O que o helper faz

`tools/sign-ipa-macos.sh` implementa um caminho local, sem serviço remoto:

1. inspeciona o ZIP/IPA e bloqueia path traversal, links simbólicos, entradas duplicadas, arquivos excessivos e taxa de compressão suspeita;
2. pede ao macOS para verificar a assinatura CMS de cada provisioning profile (`security cms -V`) antes de decodificar o plist;
3. importa o PKCS#12 em um keychain temporário e remove esse keychain ao sair;
4. exige um manifesto com um perfil e um plist de entitlements para cada `.app` e `.appex`;
5. verifica Bundle ID, validade do perfil, Team ID, escopo de dispositivo, DeveloperCertificates e correspondência da identidade;
6. valida que cada entitlement solicitado está autorizado pelo perfil, exige application-identifier/Team ID exatos e permite reduzir privilégios, não elevá-los;
7. assina frameworks/dylibs aninhados, depois extensões e apps do nível mais interno para o externo;
8. verifica a assinatura dos bundles e reconstrói o IPA preservando os metadados suportados por `ditto`.

## Manifesto

Crie um arquivo JSON ao lado dos perfis e dos plists, por exemplo:

```json
{
  "bundles": [
    {
      "bundle_path": "Payload/Example.app",
      "profile_path": "profiles/main.mobileprovision",
      "entitlements_path": "entitlements/main.plist"
    },
    {
      "bundle_path": "Payload/Example.app/PlugIns/Share.appex",
      "profile_path": "profiles/share.mobileprovision",
      "entitlements_path": "entitlements/share.plist"
    }
  ]
}
```

O manifesto deve listar exatamente cada `.app` e `.appex` contido no IPA. Os caminhos de perfil e entitlements são relativos à pasta do manifesto; `bundle_path` é relativo à raiz extraída do IPA. Cada extensão precisa do seu próprio perfil e entitlements mínimos. Todos os perfis devem autorizar a mesma identidade PKCS#12 usada nesta etapa.

## Uso

Em um Mac com Xcode e ferramentas de linha de comando:

```sh
export P12_PASSWORD='senha-do-arquivo-p12'
tools/sign-ipa-macos.sh AutoRenew-unsigned.ipa Developer.p12 signing-manifest.json AutoRenew-signed.ipa
unset P12_PASSWORD
```

A senha não deve ser colocada no histórico do shell, issue, log ou CI. Prefira entrada segura por prompt/gerenciador de segredos local. O helper não envia o P12, perfil ou senha à rede.

## Limites deliberados desta versão

- A verificação CMS é delegada à implementação Security do macOS; a validação da cadeia Apple/revogação depende do trust store e da política do sistema. O helper não promete uma avaliação OCSP/CRL independente.
- A comparação de identidade confere o certificado listado no perfil e a identidade importada, mas não substitui uma auditoria PKI externa.
- A validação de entitlements é conservadora e cobre valores escalares, arrays e dicionários comuns; capacidades complexas/variáveis devem receber testes específicos antes de uso.
- O helper não gera certificados/perfis, não registra UDIDs e não contorna requisitos de assinatura da Apple.
- O pipeline ainda precisa ser executado em macOS com perfis/certificados de teste reais e depois validado em iPhone físico. CI de código-fonte não substitui isso.
- O IPA de saída só deve ser chamado assinado se o helper terminar com sucesso; a instalação e o primeiro lançamento precisam ser testados separadamente.

## Próximas etapas

1. testar CMS válido, CMS adulterado, certificado expirado e cadeia não confiável com fixtures reais;
2. validar Mach-O CodeDirectory, resource envelope e entitlements efetivos após assinatura;
3. testar round-trip de ZIP, permissões, symlinks e arquivos grandes;
4. executar instalação e primeiro lançamento em dispositivo real com perfil válido.
