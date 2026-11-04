#!/usr/bin/env bash
# Constrói e assina nesta máquina, como o flatpak-adv-br: a chave privada não sai
# daqui, e o CI só recebe o resultado assinado.
#
#   scripts/publicar.sh            monta o site em .construcao/site
#   scripts/publicar.sh --enviar   e deixa no rascunho do release da versão atual
#
# Depois do --enviar, a tag dispara .github/workflows/release.yml.
set -euo pipefail

raiz=$(cd "$(dirname "$0")/.." && pwd)
id=br.gov.serpro.desktop.assinador
ramo=stable
titulo='Assinador Serpro'
url=${URL:-https://llawli.github.io/assinador-serpro-flatpak}
repo=${REPO:-${XDG_DATA_HOME:-$HOME/.local/share}/assinador-serpro-repo}
chave_publica=${CHAVE_PUBLICA:-$raiz/packaging/chave-publica.asc}
construcao="$raiz/.construcao/publicar"
site="$raiz/.construcao/site"

enviar=nao
case ${1:-} in
    '') ;;
    --enviar) enviar=sim ;;
    *) echo "argumento desconhecido: $1" >&2; exit 1 ;;
esac

# Assinar com uma chave que o repositório não anuncia gera um repositório que
# ninguém instala, e o erro do outro lado fala de ref inexistente.
impressao=$(gpg --show-keys --with-colons "$chave_publica" | awk -F: '/^fpr/ { print $10; exit }')
chave=${CHAVE:-$impressao}
gpg --list-secret-keys "$chave" >/dev/null 2>&1 || {
    echo "não achei a chave privada $chave neste computador" >&2
    exit 1
}
em_uso=$(gpg --list-keys --with-colons "$chave" | awk -F: '/^fpr/ { print $10; exit }')
if [ "$impressao" != "$em_uso" ]; then
    echo "a chave em uso ($em_uso) não é a de $chave_publica ($impressao)" >&2
    exit 1
fi

avisar_toque() {
    command -v notify-send >/dev/null 2>&1 &&
        notify-send -u normal -t 30000 'Toque na YubiKey' "$1" 2>/dev/null || true
}

mkdir -p "$construcao" "$repo"
flatpak run --filesystem=host org.flatpak.Builder --user --force-clean \
    --disable-rofiles-fuse --default-branch="$ramo" \
    --state-dir="$construcao/estado" --repo="$repo" \
    "$construcao/build" "$raiz/$id.yml" >/dev/null

assinado() {
    ostree --repo="$repo" show --print-detached-metadata-key=ostree.gpgsigs \
        "$(ostree --repo="$repo" rev-parse "$1")" >/dev/null 2>&1
}

# Pelo ostree: o build-sign do flatpak ignora as refs de appstream. Fora do builder:
# dentro do sandbox dele não há gpg-agent, e o cartão só fala com o da sessão.
assinar_pendentes() {
    pendentes=0
    while IFS= read -r ref; do
        assinado "$ref" && continue
        avisar_toque "Assinando $ref"
        ostree --repo="$repo" gpg-sign "$(ostree --repo="$repo" rev-parse "$ref")" "$chave"
        pendentes=$((pendentes + 1))
    done < <(ostree --repo="$repo" refs)
}

atualizar() {
    avisar_toque 'Assinando o summary do repositório'
    flatpak build-update-repo "$repo" --gpg-sign="$chave" --title="$titulo" \
        --default-branch="$ramo" --generate-static-deltas --prune --prune-depth=3 >/dev/null
}

# A ordem importa: uma instalação nova usa o delta de origem vazia, que leva uma cópia
# do commit de quando foi gerado. Assinar depois dos deltas não chega a quem instala.
flatpak build-update-repo "$repo" >/dev/null
assinar_pendentes
atualizar
# Essa passada pode recriar o appstream, que nasce sem assinatura.
assinar_pendentes
if [ "$pendentes" -gt 0 ]; then
    atualizar
fi

total=0
while IFS= read -r ref; do
    assinado "$ref" || { echo "ref sem assinatura: $ref" >&2; exit 1; }
    total=$((total + 1))
done < <(ostree --repo="$repo" refs)
[ "$total" -ge 2 ] || { echo "só $total ref no repositório" >&2; exit 1; }
flatpak repo --branches "$repo" | grep -q "app/$id/x86_64/$ramo"

rm -rf "$site"
mkdir -p "$site"
cp -a "$repo" "$site/repo"
rm -rf "$site/repo/tmp" "$site/repo/state" "$site/repo/.lock"
chave_base64=$(gpg --export "$chave" | base64 -w0)
cat > "$site/assinador-serpro.flatpakref" <<FIM
[Flatpak Ref]
Title=$titulo
Name=$id
Branch=$ramo
Url=$url/repo/
IsRuntime=false
GPGKey=$chave_base64
RuntimeRepo=https://dl.flathub.org/repo/flathub.flatpakrepo
FIM
cat > "$site/assinador-serpro.flatpakrepo" <<FIM
[Flatpak Repo]
Title=$titulo
Url=$url/repo/
GPGKey=$chave_base64
FIM
echo "$total refs assinadas, site em $site"

[ "$enviar" = sim ] || exit 0

versao=$(awk '$1 == "##" && $2 != "[Unreleased]" { gsub(/[][]/, "", $2); print $2; exit }' "$raiz/CHANGELOG.md")
[ -n "$versao" ] || { echo 'CHANGELOG sem versão' >&2; exit 1; }
tag="v$versao"
tar -C "$site" -czf "$raiz/.construcao/assinador-serpro-site.tar.gz" .
arquivos=("$raiz/.construcao/assinador-serpro-site.tar.gz"
    "$site/assinador-serpro.flatpakref" "$site/assinador-serpro.flatpakrepo")
if rascunho=$(gh release view "$tag" --json isDraft --jq .isDraft 2>/dev/null); then
    [ "$rascunho" = true ] || { echo "$tag já foi publicado" >&2; exit 1; }
    gh release upload "$tag" --clobber "${arquivos[@]}"
else
    gh release create "$tag" --draft --title "$versao" --notes '' "${arquivos[@]}"
fi
echo "rascunho $tag pronto; agora crie e envie a tag"
