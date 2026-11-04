# Arquitetura

## O que vai no pacote

O item 12 do termo de uso reserva ao Serpro a distribuição dos arquivos de
instalação. O pacote leva só o lançador e dois módulos pequenos (cerca de 30 KB). O
instalador entra como `extra-data`: o Flatpak baixa da URL do Serpro na máquina de
quem instala, confere sha256 e tamanho, e roda `src/apply_extra.sh`.

O instalador é um binário Go com um `tar.zst` embutido. O `apply_extra.sh` não o
executa: acha o quadro zstd e extrai `lib/`, `jre_amd64/`, o ícone e o termo. Assim
ficam de fora o que ele faria além disso: `/etc/hosts`, atalhos de sistema,
autostart e telemetria da instalação. O ícone vai para `extra/export`, que o
Flatpak exporta, porque a marca do Serpro não pode vir no pacote.

O lançador em Go do Serpro também fica de fora. Ele se atualiza no diretório de
instalação, que aqui é somente leitura, e quem atualiza é o Flatpak.
`src/assinador-serpro.sh` sobe a JVM com as mesmas opções. A telemetria do
lançador sai junto com ele; o que o jar envia por conta própria não foi alterado.

## Como o token chega

```
Assinador (sandbox) → tokens-p11.so → p11-kit-client.so
    → $XDG_RUNTIME_DIR/p11-kit/pkcs11 → p11-kit server (host) → driver ou Tessera
```

É o contrato do PJeOffice Pro da FlatPark: `--filesystem=xdg-run/p11-kit/pkcs11`,
sem `--socket=pcsc` e sem `--device=all`. Quem publica para esse socket serve os
dois aplicativos sem saber qual deles está do outro lado.

O módulo entra pela variável `PKCS11_DRIVER`, lida no fim de
`Configuration.doConfiguration()`. O aviso "Nenhum driver encontrado" no log vem
antes dessa leitura e não indica problema.

## Por que tokens-p11.so existe

Apontar `PKCS11_DRIVER` direto para o `p11-kit-client.so` não funciona. Medido com
um token de teste no formato e-CPF A3, atrás de um servidor p11-kit com o
`p11-kit-trust` ativo:

| Chamada | Sem o módulo | Com o módulo |
|---|---|---|
| Slots | 3, sendo o 0 e o 1 de confiança | 1, o do token |
| Assinar | "Ocorreu um erro ao acessar o token" | pede o PIN e lê o titular |
| `C_Initialize` do `LoadLib` | `CKR_CANT_LOCK` | aceita |
| `C_FindObjectsInit` do `LoadLib` | `CKR_HOST_MEMORY` | aceita |

- **Slots:** o assinador configura o SunPKCS11 só com `name` e `library`, e ele usa
  o primeiro slot. Sem o filtro, esse slot é o System Trust.
- **`C_Initialize`:** o `LoadLib` chama sem `CKF_OS_LOCKING_OK`, que o RPC do
  p11-kit exige.
- **`C_FindObjectsInit`:** o `LoadLib` manda `CKA_TOKEN` com 8 bytes em vez de 1.
  Drivers locais toleram, o RPC valida.

`CKR_ATTRIBUTE_TYPE_INVALID 0x11` no log é esperado: o `LoadLib` pede `CKA_VALUE`
a objetos que não o têm, trata o erro e segue.

## Por que nome-local.so existe

O assinador abre o servidor em `assinador-desktop.serpro.gov.br`. Sem esse nome ele
mostra "Não foi possível conectar-se a internet" e desliga a integração.
`nome-local.so` entra por `LD_PRELOAD` e troca só esse nome por `127.0.0.1` em
`getaddrinfo`.

Alternativas descartadas: `jdk.net.hosts.file` faz a JVM ignorar o DNS e quebraria
as listas de revogação; um `InetAddressResolverProvider` pediria mais uma extensão
de SDK no build.

Isso resolve só dentro do sandbox. O navegador, no host, precisa da linha em
`/etc/hosts` descrita no README.

## Portas

| Porta | Serviço |
|---|---|
| 65056 | HTTP legado, `127.0.0.1` |
| 65156 | WSS legado, `127.0.0.1`, certificado gerado localmente |
| 65066 | HTTP, `assinador-desktop.serpro.gov.br` |
| 65166 | WSS, `assinador-desktop.serpro.gov.br` |

## Atualizar a versão

Troque `url`, `sha256`, `size` e `installed-size` no manifesto, e a versão no
metainfo. O `apply_extra.sh` acha o conteúdo sem depender de deslocamento fixo, e
o lançador acha o jar por padrão de nome. `installed-size` é o tamanho do tar
descomprimido.

## Armadilhas do ambiente

- **Reinicie `p11-kit-server.socket`, não o `.service`.** Ao sair, o servidor apaga o
  socket, e o `.service` reiniciado não o recria. Sem ele no host, o sandbox cai em
  silêncio no socket de confiança do próprio Flatpak (`/run/flatpak/p11-kit/pkcs11`),
  que só tem System Trust e Default Trust: parece token invisível, e nada indica que
  o socket é outro. Compare o inode nos dois lados.
- **Um `.flatpak` não serve para distribuir.** `flatpak install --bundle` falha com
  "Dados extras faltando nos metadados destacados": o formato não leva os metadados
  do `extra-data`, nem com `--repo-url`. Distribua por repositório: veja
  [release.md](release.md).

## O que foi e o que não foi testado

Testado com o pacote instalado. Com token físico, GD Burti (SafeSign IC) e
certificado e-CPF A3 real, na VM Fedora 44 GNOME, com o Tessera 0.2.1 da FlatPark e
sem override: assinatura de PDF completa dentro do Assinador, com a política
`PA_AD_RB_v2_4`. Fora do Assinador, `openssl cms -verify` confirmou a assinatura
sobre o arquivo inteiro, e o certificado do CMS é o mesmo lido do token.

No mesmo ambiente, a [página de teste do Serpro](https://www.frameworkdemoiselle.gov.br/v3/signer/demoNovo/)
assinou um texto pelo Firefox do Fedora e pelo Chromium em Flatpak, por
`wss://assinador-desktop.serpro.gov.br:65166/signer`. Essa porta usa certificado
Let's Encrypt, sem exceção manual no navegador. O nome não tem registro no DNS
público, por isso a linha em `/etc/hosts` é obrigatória.

Com um token falso, com certificado no formato e-CPF A3:

| Onde | O quê |
|---|---|
| Arch, Xvfb | instalação pelo `extra-data`, interface, os quatro servidores, comparação com e sem o módulo |
| Fedora 44 GNOME (VM) | instalação por repositório, janela, ícone e notificação na sessão real |
| Fedora 44, Tessera 0.2.1 da FlatPark | `flatpak run` sem override, socket padrão: pedido `sign`, consentimento, PIN e leitura do titular |
| Fedora 44, Tessera 0.2.1 | `tessera probe-sign` pelo `tokens-p11.so`: RSA PKCS#1 v1.5 e PSS assinam, PIN errado é recusado |

No teste com o Tessera, o token falso entrou como driver por `TESSERA_DRIVERS_PATH`,
a variável de desenvolvimento dele. O fluxo do app na VM rodou em Xvfb, porque o GNOME
intercepta a entrada simulada; na sessão real a janela e o consentimento abriram.

Com o token físico, o Tessera precisa de um Reiniciar depois que o token entra, se
abriu sem ele: o driver fica "Parado" após três tentativas sem resposta.

Durante o teste, o `pcscd` 2.4.1 do Fedora caiu uma vez com SIGSEGV em
`IsClientAuthorized`, com Firefox e Chromium abertos. O Assinador não se recupera
sozinho: sua conexão com o Tessera fica morta (`CKR_TOKEN_NOT_RECOGNIZED`), embora
clientes novos vejam o token. Reabrir o Assinador resolve, sem reiniciar o Tessera.
A queda não se repetiu, e a causa não foi isolada.

Não testado: certificado A1; sites de produção, como o e-CAC.
