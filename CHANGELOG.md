# Changelog

Formato do [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).

## [Unreleased]

### Added

- O release avisa a FlatPark, que passa a publicar a versão testada em minutos.

## [4.6.0-1] - 2026-11-05

### Added

- Pacote Flatpak do Assinador Serpro 4.6.0, com o instalador oficial baixado do
  Serpro na instalação.
- Tokens A3 pelo servidor p11-kit do usuário, o mesmo caminho do PJeOffice Pro da
  FlatPark, compatível com o Tessera.
- Servidor local em `assinador-desktop.serpro.gov.br` sem precisar de `/etc/hosts`
  dentro do sandbox.
- Identificador `br.gov.serpro.desktop.assinador`, o mesmo do pacote de macOS do
  Serpro.
- Instalação por `.flatpakref`, de um repositório assinado no GitHub Pages.
