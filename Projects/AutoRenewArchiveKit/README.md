# AutoRenewArchiveKit

**Inspiração:** etapas de empacotamento e reconstrução de IPA usadas em ferramentas de sideload como SideSign/SideStore. Implementação independente.

## Objetivo

Inspecionar, extrair e reconstruir arquivos IPA de forma determinística, preservando estrutura, permissões e metadados necessários ao pacote iOS.

## Estado atual

O Alpha possui um inspector preliminar que verifica extensão, tamanho, cabeçalho ZIP e SHA-256. Isso não valida assinatura Apple, conteúdo seguro, compatibilidade ou malware.

## Evolução

1. Inspecionar central directory e entradas ZIP, rejeitando path traversal, symlinks perigosos, duplicatas ambíguas e arquivos excessivos.
2. Extrair em diretório temporário isolado com limites de tamanho descompactado e quantidade de arquivos.
3. Identificar exatamente o app em Payload e inventariar frameworks, dylibs, appex e recursos.
4. Reconstruir preservando permissões e estrutura esperadas, sem confiar em caminhos do arquivo de entrada.
5. Verificar o pacote final e produzir relatório de hashes e arquivos alterados.
6. Testar round-trip com fixtures sintéticas e pacotes de teste não sensíveis.

## Critério de conclusão

Um IPA reconstruído só será aceito se passar inspeção estrutural, limites de segurança e verificação de assinatura pós-processamento.
