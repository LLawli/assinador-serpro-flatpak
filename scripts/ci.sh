#!/bin/sh
# Todas as verificações. O CI roda este mesmo comando.
set -eu

raiz=$(cd "$(dirname "$0")/.." && pwd)
id=br.gov.serpro.desktop.assinador
cd "$raiz"

# Sem o binário, a imagem oficial: a mesma ferramenta, sem instalar nada.
echo '== shellcheck'
if shellcheck --version >/dev/null 2>&1; then
    shellcheck -S warning src/*.sh scripts/*.sh tests/*.sh
else
    motor=$(command -v podman || command -v docker)
    "$motor" run --rm -v "$raiz:/mnt:z" -w /mnt docker.io/koalaman/shellcheck:stable \
        -S warning src/*.sh scripts/*.sh tests/*.sh
fi

echo '== metadados'
desktop-file-validate --no-hints "$id.desktop"
appstreamcli validate --no-net --pedantic "$id.metainfo.xml"

echo '== testes'
./tests/testar.sh

# A única dependência externa é o instalador. O Serpro pode recusar a origem da
# conexão, e isso não é defeito daqui; um tamanho diferente é.
echo '== instalador do Serpro'
url=$(sed -n 's/^ *url: //p' "$id.yml")
esperado=$(sed -n 's/^ *size: //p' "$id.yml")
tamanho=$(curl -fsSIL -m 30 "$url" | tr -d '\r' | sed -n 's/^[Cc]ontent-[Ll]ength: //p' | tail -1)
if [ -z "$tamanho" ]; then
    echo '  aviso: site do Serpro inacessível daqui'
elif [ "$tamanho" != "$esperado" ]; then
    echo "o instalador mudou: $tamanho bytes, o manifesto diz $esperado" >&2
    exit 1
else
    echo "  ok   $tamanho bytes"
fi
