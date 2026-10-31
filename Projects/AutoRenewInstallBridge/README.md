# AutoRenewInstallBridge

**Inspiração:** fluxo de distribuição e instalação do SideStore, incluindo handoff para ferramentas compatíveis. Projeto independente; não replica entitlements privados nem protocolos não documentados.

## Estado atual no Alpha

- O Installer permite compartilhar IPA com AltStore/SideStore.
- `tools/sign-ipa-macos.sh` prepara um IPA assinado localmente no Mac, usando perfis/entitlements por app e extensão.
- `tools/install-to-iphone.sh` verifica a assinatura do app e solicita instalação via Xcode/devicectl em iPhone pareado e confiável.
- O app iOS não instala nem assina genericamente por conta própria.

## Limites

A assinatura e reconstrução local ainda precisam de teste com certificado/perfil reais. O comando devicectl aceito não prova primeiro lançamento ou funcionamento. O helper não cria perfis, registra UDIDs nem resolve incompatibilidades de dispositivo.

Não copiar LocalDevVPN/entitlements especiais do SideStore, não usar APIs privadas, nem solicitar credenciais Apple ID/2FA. Instalação e renovação on-device exigem estudo e validação específicos antes de qualquer promessa.

## Próximas etapas

1. Confirmar assinatura e provisioning de cada bundle antes de instalar.
2. Melhorar diagnóstico de incompatibilidade de perfil/dispositivo.
3. Confirmar resultado no dispositivo sem confundir comando aceito com primeiro lançamento funcional.
4. Documentar requisitos de Xcode, iOS, dispositivo e perfil.
5. Extrair a integração para Swift Package independente quando os contratos estiverem estáveis.
