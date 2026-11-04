/*
 * nome-local.so: resolve assinador-desktop.serpro.gov.br para 127.0.0.1 dentro
 * do sandbox.
 *
 * O assinador abre o servidor local nesse nome, que não existe no DNS: o
 * instalador do Serpro o escreve em /etc/hosts, e um Flatpak não pode fazer
 * isso. Sem o nome ele avisa que não há internet e desliga a integração com os
 * sites. Só este nome é respondido aqui; todos os outros seguem para a glibc.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <netdb.h>
#include <string.h>

#define NOME_LOCAL "assinador-desktop.serpro.gov.br"
#define ENDERECO_LOCAL "127.0.0.1"

int getaddrinfo(const char *nome, const char *servico,
                const struct addrinfo *dicas, struct addrinfo **resultado)
{
    int (*original)(const char *, const char *, const struct addrinfo *,
                    struct addrinfo **);

    *(void **)&original = dlsym(RTLD_NEXT, "getaddrinfo");
    if (original == NULL)
        return EAI_SYSTEM;
    if (nome != NULL && strcmp(nome, NOME_LOCAL) == 0)
        nome = ENDERECO_LOCAL;
    return original(nome, servico, dicas, resultado);
}
