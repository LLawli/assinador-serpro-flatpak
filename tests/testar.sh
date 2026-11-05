#!/bin/sh
# Testes que não precisam de token, de rede nem do instalador do Serpro.
set -eu

raiz=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
opcoes="-shared -fPIC -O2 -Wall -Wextra -Werror"
p11=$(pkg-config --cflags p11-kit-1)

# shellcheck disable=SC2086
gcc $opcoes $p11 -o "$tmp/falso.so" "$raiz/tests/modulo-falso.c"
# shellcheck disable=SC2086
gcc $opcoes $p11 -DMODULO_CLIENTE="\"$tmp/falso.so\"" \
    -o "$tmp/tokens-p11.so" "$raiz/src/tokens-p11.c" -ldl
# shellcheck disable=SC2086
gcc -O2 -Wall -Wextra -Werror $p11 -o "$tmp/prova-tokens" "$raiz/tests/prova-tokens.c" -ldl
echo 'tokens-p11.so'
"$tmp/prova-tokens" "$tmp/tokens-p11.so"

# shellcheck disable=SC2086
gcc $opcoes -o "$tmp/nome-local.so" "$raiz/src/nome-local.c" -ldl
gcc -O2 -Wall -Wextra -Werror -o "$tmp/prova-nome" "$raiz/tests/prova-nome.c"
echo 'nome-local.so'
LD_PRELOAD="$tmp/nome-local.so" "$tmp/prova-nome"

# apply_extra contra um instalador de mentira: lixo, o número mágico solto como
# no código do binário de verdade, e depois o tar.zst.
echo 'apply_extra.sh'
extra="$tmp/extra"
mkdir -p "$extra" "$tmp/carga/lib" "$tmp/carga/jre_amd64/bin"
echo jar > "$tmp/carga/lib/serpro-signer-9.9.9.jar"
printf '#!/bin/sh\n' > "$tmp/carga/jre_amd64/bin/java"
chmod +x "$tmp/carga/jre_amd64/bin/java"
echo png > "$tmp/carga/serpro-signer.png"
echo termo > "$tmp/carga/TermoDeUsoAssinadorSERPRO.md"
echo '{}' > "$tmp/carga/version.json"
{
    head -c 4096 /dev/urandom
    printf '\050\265\057\375\004lixo-que-nao-e-zstd'
    tar -C "$tmp/carga" -cf - . | zstd -q -c
    head -c 512 /dev/urandom
} > "$extra/assinador.bin"
(cd "$extra" && sh "$raiz/src/apply_extra.sh")
icone=export/share/icons/hicolor/128x128/apps/br.gov.serpro.desktop.assinador.png
for esperado in lib/serpro-signer-9.9.9.jar jre_amd64/bin/java "$icone"; do
    test -s "$extra/$esperado"
done
test ! -e "$extra/assinador.bin"
echo '  ok   extrai o jar, o JRE e o ícone, e apaga o instalador'

: > "$extra/assinador.bin"
rm -rf "${extra:?}/lib" "${extra:?}/jre_amd64"
if (cd "$extra" && sh "$raiz/src/apply_extra.sh" 2>/dev/null); then
    echo '  ERRO um instalador vazio passou'
    exit 1
fi
echo '  ok   um instalador sem o conteúdo esperado falha'

# Um curl de mentira: -I responde o tamanho, o resto responde a listagem.
echo 'verificar-serpro.sh'
manifesto="$raiz/br.gov.serpro.desktop.assinador.yml"
atual=$(sed -n 's/^ *url: .*\/Assinador-Serpro-\([0-9.]*\)-Linux.*/\1/p' "$manifesto")
tamanho=$(sed -n 's/^ *size: //p' "$manifesto")
mkdir -p "$tmp/rede"
cat > "$tmp/rede/curl" <<'CURL'
#!/bin/sh
[ -n "$PAGINA" ] || exit 28
case $1 in
    -fsSIL) printf 'HTTP/1.1 200 OK\r\nContent-Length: %s\r\n\r\n' "$TAMANHO" ;;
    *) printf '%s\n' "$PAGINA" ;;
esac
CURL
chmod +x "$tmp/rede/curl"
verificar() { # <página> <tamanho>
    PATH="$tmp/rede:$PATH" PAGINA="$1" TAMANHO="$2" \
        sh "$raiz/scripts/verificar-serpro.sh" 2>&1
}
item() {
    printf 'href="downloads/%s/Assinador-Serpro-%s-Linux-x86_64.bin"\n' "$1" "$1"
}
recusa() { # <descrição> <mensagem esperada> <página> <tamanho>
    if saida=$(verificar "$3" "$4"); then
        echo "  ERRO $1: passou"
        exit 1
    fi
    case $saida in
        *"$2"*) echo "  ok   $1" ;;
        *) echo "  ERRO $1: $saida"; exit 1 ;;
    esac
}
homologacao='Assinador-Serpro-99.0.0-HOM-Linux-x86_64.bin'
verificar "$(item 1.0.0; item "$atual"; echo "$homologacao")" "$tamanho" >/dev/null
echo '  ok   passa na última versão, ignorando a de homologação'
recusa 'versão nova falha' 'publicou a versão 99.0.0' \
    "$(item "$atual"; item 99.0.0)" "$tamanho"
recusa 'tamanho diferente falha' 'mudou' "$(item "$atual")" 5
recusa 'página sem a versão do manifesto falha' 'não está em' '<html></html>' "$tamanho"
recusa 'site fora do ar falha' 'não consegui consultar' '' "$tamanho"
