#!/bin/sh
# Sobe a JVM com as mesmas opções do lançador do Serpro. O lançador em si não
# entra: ele atualiza o programa no diretório de instalação, que aqui é somente
# leitura, e quem atualiza este pacote é o Flatpak.
set -eu

BASE=/app/extra

for jar in "$BASE"/lib/serpro-signer-*.jar; do :; done
if [ ! -f "$jar" ]; then
    echo "assinador-serpro: jar não encontrado em $BASE/lib" >&2
    exit 1
fi

# Lido pelo Configuration do Demoiselle, que acrescenta o módulo à lista.
export PKCS11_DRIVER=/app/lib/assinador-serpro/tokens-p11.so
# O nome do servidor local, que o instalador nativo põe em /etc/hosts.
export LD_PRELOAD=/app/lib/assinador-serpro/nome-local.so

exec "$BASE/jre_amd64/bin/java" \
    -Xms256m -Xmx4096m \
    -XX:MinHeapFreeRatio=20 -XX:MaxHeapFreeRatio=40 \
    -Dfile.encoding=UTF-8 -Duser.timezone=GMT-3 -Djava.io.tmpdir=/tmp \
    -Dswing.aatext=true -Dawt.useSystemAAFontSettings=on \
    -Dsun.java2d.uiScale.enabled=true \
    --add-modules=jdk.crypto.cryptoki \
    --add-opens=java.base/java.io=ALL-UNNAMED \
    --add-opens=java.base/java.lang=ALL-UNNAMED \
    --add-opens=java.base/java.lang.reflect=ALL-UNNAMED \
    --add-opens=java.base/java.util=ALL-UNNAMED \
    --add-opens=java.base/sun.security.x509=ALL-UNNAMED \
    --add-opens=java.desktop/java.awt=ALL-UNNAMED \
    --add-opens=java.desktop/javax.swing=ALL-UNNAMED \
    --add-exports=jdk.crypto.cryptoki/sun.security.pkcs11=ALL-UNNAMED \
    --add-exports=jdk.crypto.cryptoki/sun.security.pkcs11.wrapper=ALL-UNNAMED \
    -cp "$jar" org.demoiselle.signer.serpro.desktop.Main "$@"
