# Release

A assinatura roda na máquina de quem publica, como no flatpak-adv-br. `scripts/publicar.sh
--enviar` constrói, assina com a chave do cartão e deixa o site em um rascunho de
release. A tag `v*.*.*` dispara `.github/workflows/release.yml`, que roda `scripts/ci.sh`,
confere se a chave do site é a de `packaging/chave-publica.asc`, publica no GitHub Pages
e fecha o Release com o `.flatpakref`, o `.flatpakrepo`, o tarball do código e os
sha256. O corpo vem da seção da versão no CHANGELOG, e o workflow falha sem ela.
`workflow_dispatch` na tag refaz a publicação.

## A cada versão do Serpro

O workflow `versao-serpro` roda `scripts/verificar-serpro.sh` uma vez por dia e falha,
mandando email, se a listagem do Serpro tiver um instalador de Linux mais novo, se o
tamanho do atual mudar, ou se a consulta não funcionar. A mensagem do erro diz qual
foi. Ele vê tamanho, não hash: um arquivo trocado com o mesmo tamanho passa.

1. Atualizar `url`, `sha256`, `size` e `installed-size` no manifesto.
2. Acrescentar o `<release>` no metainfo e mover o `[Unreleased]` do CHANGELOG.
3. Rodar `scripts/ci.sh`, instalar na VM e assinar com um token real.
4. Rodar `scripts/publicar.sh --enviar`, com a YubiKey plugada: cada ref e o summary
   pedem um toque.
5. Criar a tag assinada, no formato `v4.6.0-1`, e enviar com `git push origin <tag>`.

O sufixo conta as revisões do empacotamento sobre a mesma versão do Serpro.

## FlatPark

A tag é a aprovação: é ela que leva uma versão aos usuários da FlatPark, sem revisão de
ninguém. O `resolve-update.sh` de lá lê o último release daqui, tira o sufixo e monta a
URL do Serpro, então um instalador novo no site do Serpro não chega a ninguém antes do
teste com token. O job `flatpark` do `release.yml` avisa a FlatPark por
`flatpark/publish-action`, sem token nem secret, e ela publica em minutos. Sem o aviso,
a varredura de 12 em 12 horas acha o mesmo release.

Por isso o `release.yml` falha quando a versão da tag não é a do manifesto. Uma revisão
do empacotamento (`v4.6.0-2`) não muda nada lá: a versão é a mesma, e o que mudar no
pacote da FlatPark vai por PR.

Até o app entrar no catálogo da FlatPark, o aviso recebe 404, e o job fica vermelho sem
afetar o release.

## Identificador

`br.gov.serpro.desktop.assinador` é o identificador que o Serpro usa no pacote de
macOS, conforme o [cask do Homebrew](https://formulae.brew.sh/cask/assinador-serpro)
(versão 4.3.3). O instalador Linux e o jar não trazem outro. O pacote continua sendo
da comunidade, e o README e o metainfo dizem isso.

## Por que `.flatpakref`, e não `.flatpak`

O termo de uso reserva a distribuição ao Serpro, então o programa entra por
`extra-data` e o pacote só leva o empacotamento. Medido com o ID final:

| Formato | Resultado |
|---|---|
| `.flatpak` | falha: "Dados extras faltando nos metadados destacados" |
| `.flatpak` com `--repo-url` | falha com o mesmo erro |
| `.flatpakref` | instala, baixa do Serpro, exporta o ícone e recebe atualizações |

Um `.flatpak` de verdade exigiria tirar o `extra-data` e baixar o programa na primeira
execução. Isso muda o caminho testado, perde o ícone exportado e pede uma tela de
progresso.

Formatos nativos (deb, rpm, AUR, Homebrew) ficam de fora: o Serpro já distribui o
instalador nativo, e este projeto existe para quem não pode usá-lo.

## Chave do repositório

É a mesma chave GPG do flatpak-adv-br, gerada dentro da YubiKey. A pública está em
`packaging/chave-publica.asc`, e `scripts/publicar.sh` recusa assinar com outra. Nenhum
segredo fica no GitHub. O repositório local mora em
`~/.local/share/assinador-serpro-repo` e guarda o histórico que os deltas usam.

## Riscos

- **URL do instalador:** o `extra-data` depende dela. Se o Serpro tirar a versão do
  ar, a instalação quebra até publicarmos a versão nova.
- **Certificado da porta 65166:** o Let's Encrypt visto em 2026-11-04 vence em
  2027-01-22. Falta confirmar se ele vem no jar ou é renovado em execução. Se vier no
  jar, os sites param de conectar nessa data sem uma versão nova do Serpro.
- **Lojas:** um ID sob o domínio do Serpro não passa na verificação do Flathub sem o
  aval dele.
