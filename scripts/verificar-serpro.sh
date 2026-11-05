#!/bin/sh
# Falha quando o instalador de Linux do Serpro não é mais o do manifesto. Roda uma
# vez por dia no Actions: a falha vira email, e a atualização é à mão porque pede
# um teste com token. Passos em docs/release.md.
set -eu

raiz=$(cd "$(dirname "$0")/.." && pwd)
manifesto="$raiz/br.gov.serpro.desktop.assinador.yml"
listagem=https://artefatos-assinador.serpro.gov.br/downloads/
versao_do_nome='s/^Assinador-Serpro-\([0-9.]*\)-Linux-x86_64\.bin$/\1/'

url=$(sed -n 's/^ *url: //p' "$manifesto")
esperado=$(sed -n 's/^ *size: //p' "$manifesto")
atual=$(basename "$url" | sed -n "${versao_do_nome}p")
[ -n "$atual" ] || { echo "não achei a versão em $url" >&2; exit 1; }

# Site fora do ar também falha: passar em silêncio deixaria de vigiar sem ninguém
# saber. As tentativas seguram as quedas curtas, que já aconteceram no runner.
pagina=$(curl -fsSL --retry 4 --retry-delay 30 --retry-all-errors \
    --connect-timeout 30 -m 60 "$listagem") || {
    echo "não consegui consultar $listagem" >&2
    exit 1
}

# O padrão deixa de fora as versões -HOM-, de homologação.
versoes=$(printf '%s\n' "$pagina" \
    | grep -oE 'Assinador-Serpro-[0-9]+\.[0-9]+\.[0-9]+-Linux-x86_64\.bin' \
    | sed "$versao_do_nome" | sort -Vu)

# Sem a versão do manifesto na lista, ou a página mudou e este teste ficou cego, ou
# o arquivo saiu do ar e a instalação quebrou.
printf '%s\n' "$versoes" | grep -qxF "$atual" || {
    echo "a versão $atual não está em $listagem" >&2
    exit 1
}

ultima=$(printf '%s\n' "$versoes" | tail -1)
if [ "$ultima" != "$atual" ]; then
    echo "o Serpro publicou a versão $ultima; o manifesto está na $atual" >&2
    exit 1
fi

tamanho=$(curl -fsSIL --retry 4 --retry-delay 30 --retry-all-errors \
    --connect-timeout 30 -m 60 "$url" \
    | tr -d '\r' | sed -n 's/^[Cc]ontent-[Ll]ength: //p' | tail -1)
if [ "$tamanho" != "$esperado" ]; then
    echo "o instalador $atual mudou: ${tamanho:-sem tamanho}, o manifesto diz $esperado" >&2
    exit 1
fi

echo "versão $atual é a última, com $tamanho bytes"
