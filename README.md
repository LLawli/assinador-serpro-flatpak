# Assinador Serpro em Flatpak

O Assinador Serpro para Linux é um instalador que pede root, escreve em `/opt` e
em `/etc/hosts`, e por isso não entra em sistemas imutáveis como Silverblue ou
Bluefin. Este pacote é para quem assina com certificado ICP-Brasil nesses
sistemas, ou prefere não instalar nada fora do sandbox.

> Pacote da comunidade, sem vínculo com o Serpro. O programa é baixado do site do
> Serpro na instalação, e o uso dele segue o termo de uso do Serpro. O identificador
> `br.gov.serpro.desktop.assinador` é o do programa original, não indica autoria do
> pacote.

## Instalar

Ainda não há release: o plano está em [docs/release.md](docs/release.md). Para
construir e instalar a partir deste código:

```sh
flatpak install flathub org.flatpak.Builder
./scripts/construir.sh
```

A instalação baixa cerca de 100 MB do site do Serpro e confere o sha256. Depois
disso, **Assinador Serpro** aparece no menu de aplicativos. Abra antes de assinar:
ele não inicia sozinho com a sessão, como a instalação nativa faz.

## Token A3

O token não é aberto dentro do sandbox. O caminho é o mesmo do
[PJeOffice Pro da FlatPark](https://flatpark.org/apps/br.jus.cnj.PJeOfficePro/):
o driver roda no host, e o aplicativo fala com o servidor p11-kit do usuário.

Com o [Tessera](https://flatpark.org/apps/io.github.pedrohqb.Tessera/) não há
mais nada a fazer além do que ele já pede. Sem ele, instale o driver do fabricante
e registre com uma linha `module: /caminho/do/driver.so` em um arquivo de
`~/.config/pkcs11/modules/`. Nos dois casos o servidor precisa estar ligado:

```sh
systemctl --user enable --now p11-kit-server.socket
```

Se houver mais de um token, o Assinador usa o primeiro: ele escolhe por driver,
e aqui todos chegam pelo mesmo.

## Certificado A1

Guarde o arquivo em Documentos ou Downloads, as duas pastas que o aplicativo
enxerga. Para usar outra:

```sh
flatpak override --user --filesystem=home br.gov.serpro.desktop.assinador
```

## Assinar em sites

Os sites falam com o Assinador por um servidor local. Ele atende em `127.0.0.1` e
em `assinador-desktop.serpro.gov.br`, um nome que não existe no DNS e que o
instalador nativo escreve em `/etc/hosts`. Um Flatpak não pode fazer isso, então
para os sites que usam esse nome rode uma vez:

```sh
echo '127.0.0.1 assinador-desktop.serpro.gov.br' | sudo tee -a /etc/hosts
```

Na primeira visita, o navegador pede para o site acessar serviços locais: aceite, ou
a página mostra o Assinador como desligado. Se o token sumir com o Assinador aberto,
feche e abra o Assinador antes de assinar de novo.

## Para quem contribui

[docs/arquitetura.md](docs/arquitetura.md) explica como o pacote funciona e o que
foi medido. `./scripts/ci.sh` roda todas as verificações.

## Licença

O empacotamento é GPL-3.0. O Assinador Serpro é do Serpro, e nada dele está neste
repositório.
