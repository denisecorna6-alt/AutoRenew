# Servidor Anisette V3 próprio (Alpha)

Esta pasta contém uma implantação Docker opcional para um servidor Anisette V3 compatível com SideStore. Ela **não é necessária** para o SideStore manual continuar funcionando e não habilita, por si só, assinatura ou renovação dentro do AutoRenew.

## Arquitetura

- [Dadoum/anisette-v3-server](https://github.com/Dadoum/anisette-v3-server): implementação upstream do protocolo V3.
- Caddy: termina HTTPS e encaminha HTTP/WebSocket ao serviço na rede privada do Docker.
- Volume Docker: mantém os dados locais de provisionamento do servidor.
- A porta do serviço Anisette não é publicada diretamente na internet.

O Compose exige que as duas imagens sejam referenciadas por digest imutável. Não use tags mutáveis como `:latest` em produção.

## Requisitos

- VPS ou host Linux sob seu controle, Docker Engine e Docker Compose.
- Domínio próprio com registro DNS A/AAAA apontando para o host.
- Portas TCP 80 e 443 liberadas para o Caddy.
- Um digest de imagem obtido do registry upstream e revisado por você.
- Um endereço de e-mail válido que você controla para a conta ACME do Caddy.

## Preparar (não executar automaticamente)

1. Copie `.env.example` para `.env`.
2. Substitua `ANISETTE_DOMAIN` pelo seu domínio e `ACME_EMAIL` por um e-mail válido que você controla. Os valores de exemplo não são operacionais.
3. Obtenha a imagem upstream e confira o digest:

```sh
docker pull dadoum/anisette-v3-server
docker image inspect --format '{{index .RepoDigests 0}}' dadoum/anisette-v3-server
```

4. Coloque a referência completa retornada (incluindo `@sha256:...`) em `ANISETTE_IMAGE` no `.env`. Faça o mesmo para Caddy.
5. Só depois de revisar domínio, host, imagens e política de dados, um operador autorizado poderá decidir se executa o Compose. Esta PR não implanta o serviço.

## Segurança operacional

- Use apenas um host e domínio sob seu controle. Não use servidor público de terceiros para dados ADI.
- Não coloque Apple ID, senha, 2FA, cookies, tokens ou chaves privadas em variáveis de ambiente, arquivos, logs ou neste repositório.
- Trate identifier, dados de provisionamento e ADI como dados sensíveis. Restrinja acesso administrativo ao host e aos logs.
- Não exponha a porta 6969 publicamente; somente o proxy HTTPS deve aceitar tráfego externo.
- Mantenha Docker, host e imagem atualizados; revise mudanças upstream e atualize o digest deliberadamente.
- Faça backup protegido do volume apenas se compreender os dados que ele contém. Não publique backups.
- Não habilite CORS amplo nem endpoints administrativos adicionais.
- Este serviço não é um serviço oficial Apple ou SideStore. A disponibilidade depende do host, DNS, TLS e upstream.

## Integração com AutoRenew

O AutoRenew não configura automaticamente o app e não muda o provedor Anisette usado pelo SideStore. Não envie identifier/ADI para este serviço por automação.

Mesmo com um servidor ativo, ainda faltam backend de assinatura real e validação end-to-end em iPhone físico. O `StubSigningBackend` deve continuar fail-closed até esses requisitos serem atendidos.

## Referências upstream

- [SideStore — Custom Anisette Server](https://docs.sidestore.io/docs/advanced/anisette)
- [Dadoum/anisette-v3-server](https://github.com/Dadoum/anisette-v3-server)
