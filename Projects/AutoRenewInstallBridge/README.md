# AutoRenewInstallBridge

**Inspiração:** fluxo de distribuição e instalação do SideStore, incluindo handoff para ferramentas compatíveis. Projeto independente; não replica entitlements privados nem protocolos não documentados.

## Objetivo

Separar a entrega do IPA da assinatura e da renovação. Usar somente caminhos de instalação suportados e resultados que possam ser verificados.

## Estado atual

O Installer permite compartilhar IPA com AltStore/SideStore. Há também um helper macOS para instalar um IPA já assinado por meio do Xcode/devicectl, com iPhone pareado e confiável. O app iOS não instala nem assina genericamente por conta própria.

## Evolução

1. Definir estados de handoff: preparado, compartilhado, recebido externamente e resultado não confirmado.
2. Melhorar o helper macOS com detecção de dispositivo, diagnóstico de perfil e relatório de instalação.
3. Validar assinatura e provisioning antes de solicitar instalação.
4. Confirmar o resultado no dispositivo sem confundir comando aceito com primeiro lançamento funcional.
5. Documentar requisitos de Xcode, versão do iOS, dispositivo e perfil.
6. Manter integração com ferramentas externas opcional e sem alegar controle sobre o resultado delas.

## Limites

Não copiar LocalDevVPN/entitlements especiais do SideStore, não usar APIs privadas, nem solicitar credenciais Apple ID/2FA. Instalação e renovação on-device exigem estudo e validação específicos antes de qualquer promessa.
