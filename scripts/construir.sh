#!/bin/sh
# Constrói e instala para o usuário. O --install do flatpak-builder não serve: o
# apply_extra precisa do bwrap, que não sobe dentro do sandbox do org.flatpak.Builder.
set -eu

raiz=$(cd "$(dirname "$0")/.." && pwd)
id=br.gov.serpro.desktop.assinador
remoto=assinador-serpro-local
construcao="$raiz/.construcao"

mkdir -p "$construcao/"
flatpak run --filesystem=host org.flatpak.Builder --user --force-clean \
    --state-dir="$construcao/estado" --repo="$construcao/repo" \
    "$construcao/build" "$raiz/$id.yml"

flatpak remote-add --user --no-gpg-verify --if-not-exists "$remoto" "file://$construcao/repo"
flatpak remote-modify --user --url="file://$construcao/repo" "$remoto"
flatpak install --user --noninteractive --or-update "$remoto" "$id"
