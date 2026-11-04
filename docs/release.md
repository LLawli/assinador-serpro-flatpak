# Plano de release

Ainda não executado. Nada foi publicado além do código.

## Identificador

`br.gov.serpro.desktop.assinador` é o identificador que o Serpro usa no pacote de
macOS, conforme o [cask do Homebrew](https://formulae.brew.sh/cask/assinador-serpro)
(versão 4.3.3). O instalador Linux e o jar não trazem outro. O pacote continua sendo
da comunidade, e o README e o metainfo dizem isso.

## Formato

O termo de uso reserva a distribuição ao Serpro, então o programa entra por
`extra-data` e o pacote só leva o empacotamento. Medido com o ID final:

| Formato | Resultado |
|---|---|
| `.flatpak` | falha: "Dados extras faltando nos metadados destacados" |
| `.flatpak` com `--repo-url` | falha com o mesmo erro |
| `.flatpakref` | instala, baixa do Serpro e exporta o ícone |

O release é um `.flatpakref` apontando para um repositório OSTree. Ele abre com dois
cliques, como um `.flatpak`, e ainda traz atualizações.

Um `.flatpak` de verdade exigiria tirar o `extra-data` e baixar o programa na primeira
execução. Isso muda o caminho testado, perde o ícone exportado e pede uma tela de
progresso. Fica de fora enquanto o `.flatpakref` atender.

## Hospedagem

GitHub Pages, deste repositório. O repositório OSTree tem cerca de 360 KB, porque não
contém o programa do Serpro.

## Antes do primeiro release

1. Criar uma chave GPG só para o repositório, com a privada em um secret do Actions.
2. Escrever `.github/workflows/release.yml`: em tag `v*`, rodar `scripts/ci.sh`,
   construir, assinar, publicar no Pages e criar o Release com o `.flatpakref` e o
   `.flatpakrepo`.
3. Trocar a seção Instalar do README.

## A cada versão do Serpro

1. Atualizar `url`, `sha256`, `size` e `installed-size` no manifesto.
2. Acrescentar o `<release>` no metainfo e mover o `[Unreleased]` do CHANGELOG.
3. Rodar `scripts/ci.sh`, instalar na VM e assinar com um token real.
4. Criar a tag assinada, no formato `v4.6.0-1`, e enviar com `git push origin <tag>`.

## Riscos

- **URL do instalador:** o `extra-data` depende dela. Se o Serpro tirar a versão do
  ar, a instalação quebra até publicarmos a versão nova.
- **Certificado da porta 65166:** o Let's Encrypt visto em 2026-11-04 vence em
  2027-01-22. Falta confirmar se ele vem no jar ou é renovado em execução. Se vier no
  jar, os sites param de conectar nessa data sem uma versão nova do Serpro.
- **Lojas:** um ID sob o domínio do Serpro não passa na verificação do Flathub sem o
  aval dele.
