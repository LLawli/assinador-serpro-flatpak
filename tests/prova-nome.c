/* nome-local.so responde só pelo nome do servidor local. */
#include <arpa/inet.h>
#include <netdb.h>
#include <stdio.h>
#include <string.h>

int main(void)
{
    struct addrinfo dicas = { .ai_family = AF_INET, .ai_socktype = SOCK_STREAM };
    struct addrinfo *r = NULL;
    char texto[INET_ADDRSTRLEN] = "";
    int falhas = 0;
    int rv = getaddrinfo("assinador-desktop.serpro.gov.br", "65166", &dicas, &r);

    if (rv == 0) {
        struct sockaddr_in *a = (struct sockaddr_in *)r->ai_addr;
        inet_ntop(AF_INET, &a->sin_addr, texto, sizeof(texto));
        falhas += ntohs(a->sin_port) != 65166;
        freeaddrinfo(r);
    }
    falhas += strcmp(texto, "127.0.0.1") != 0;
    printf("  %s o nome do servidor local vai para 127.0.0.1\n", falhas ? "ERRO" : "ok  ");

    rv = getaddrinfo("nome.invalid", NULL, &dicas, &r);
    printf("  %s outro nome segue para a glibc\n", rv != 0 ? "ok  " : "ERRO");
    falhas += rv == 0;
    return falhas != 0;
}
