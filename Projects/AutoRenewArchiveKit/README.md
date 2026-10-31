# AutoRenewArchiveKit

**Inspiração:** etapas de empacotamento e reconstrução de IPA usadas em ferramentas de sideload como SideSign/SideStore. Implementação independente.

## Estado implementado no Alpha

- O inspector do app verifica extensão, tamanho, cabeçalho ZIP e SHA-256.
- `tools/validate-signing-inputs.py` inspeciona o diretório central do ZIP e bloqueia path traversal, links simbólicos, entradas duplicadas, entradas excessivas, arquivos individuais grandes e taxa de compressão suspeita.
- `tools/sign-ipa-macos.sh` extrai em diretório temporário, assina os bundles e reconstrói o IPA com `ditto`, preservando a pasta Payload e metadados suportados pelo macOS.
- Depois de reconstruir, o helper reabre o IPA e executa novamente a verificação de assinatura dos bundles.

## Limites técnicos

- A reconstrução só é considerada bem-sucedida quando o helper termina sem erro; não prova instalação ou primeiro lançamento.
- O helper usa ferramentas macOS (`ditto`, `codesign`, `security`) e ainda precisa de teste com pacotes reais de desenvolvimento.
- Ainda faltam fixtures ZIP/Mach-O reais, comparação de hashes por arquivo, validação de permissões em diferentes tipos de bundle e auditoria independente do resource envelope.
- Este diretório ainda é uma especificação de subprojeto, não um Swift Package autônomo.

## Próximas etapas

1. Extrair a lógica ZIP para biblioteca testável.
2. Criar inventário de Mach-O, frameworks, dylibs, appex e recursos.
3. Adicionar testes round-trip com fixtures não sensíveis.
4. Produzir relatório de hashes e arquivos alterados, sem incluir segredos.
