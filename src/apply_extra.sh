#!/bin/sh
# Roda uma vez, na instalação, em /app/extra e sem rede. Tira do instalador do
# Serpro só o que o aplicativo usa, sem executar o instalador: ele é um binário
# Go com um tar.zst embutido, e o que ele faria além de extrair (escrever em
# /etc/hosts, criar atalhos no sistema, enviar telemetria) não cabe num sandbox.
set -eu

INSTALADOR=assinador.bin
APP_ID=br.gov.serpro.desktop.assinador
ICONES=export/share/icons/hicolor/128x128/apps

extrair() { # <deslocamento>
    tail -c "+$(($1 + 1))" "$INSTALADOR" | zstd -dc 2>/dev/null \
        | tar -xf - ./lib ./jre_amd64 ./serpro-signer.png \
            ./TermoDeUsoAssinadorSERPRO.md ./version.json 2>/dev/null
}

# O número mágico do zstd também aparece no código do binário, então cada
# ocorrência é só uma candidata; quem decide é o resultado da extração.
for deslocamento in $(LC_ALL=C grep -aboP '\x28\xb5\x2f\xfd\x04' "$INSTALADOR" | cut -d: -f1); do
    extrair "$deslocamento" || true
    if [ -x jre_amd64/bin/java ]; then
        break
    fi
done

for jar in lib/serpro-signer-*.jar; do :; done
if [ ! -s "$jar" ] || [ ! -x jre_amd64/bin/java ]; then
    echo "apply_extra: o instalador não trouxe o jar e o JRE esperados" >&2
    exit 1
fi

# O ícone é do Serpro e não pode vir no pacote; extra/export é o que o Flatpak
# exporta de quem usa extra-data.
mkdir -p "$ICONES"
mv serpro-signer.png "$ICONES/$APP_ID.png"

rm -f "$INSTALADOR"
