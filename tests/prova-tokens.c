/* O que o Assinador Serpro precisa de tokens-p11.so, chamado como ele chama. */
#include <dlfcn.h>
#include <stdio.h>

#include <p11-kit/pkcs11.h>

static int falhas;

static void conferir(int condicao, const char *descricao)
{
    printf("  %s %s\n", condicao ? "ok  " : "ERRO", descricao);
    falhas += !condicao;
}

int main(int argc, char **argv)
{
    CK_RV (*obter)(CK_FUNCTION_LIST **);
    CK_FUNCTION_LIST *f = NULL;
    CK_C_INITIALIZE_ARGS sem_flag = { 0 };
    CK_SLOT_ID slots[4];
    CK_ULONG quantos = 0;
    void *modulo;

    if (argc != 2 || (modulo = dlopen(argv[1], RTLD_NOW)) == NULL) {
        fprintf(stderr, "uso: prova-tokens <modulo>: %s\n", dlerror());
        return 2;
    }
    *(void **)&obter = dlsym(modulo, "C_GetFunctionList");
    conferir(obter != NULL && obter(&f) == CKR_OK, "exporta C_GetFunctionList");
    if (f == NULL)
        return 1;

    conferir(f->version.major == 2 && f->version.minor == 40, "anuncia a lista 2.40");
    conferir(f->C_Initialize(&sem_flag) == CKR_OK, "aceita C_Initialize sem CKF_OS_LOCKING_OK");
    conferir(f->C_GetSlotList(CK_TRUE, NULL, &quantos) == CKR_OK && quantos == 1,
             "conta só o slot que não é de confiança");

    quantos = 0;
    conferir(f->C_GetSlotList(CK_TRUE, slots, &quantos) == CKR_BUFFER_TOO_SMALL && quantos == 1,
             "buffer pequeno devolve CKR_BUFFER_TOO_SMALL e o tamanho certo");

    quantos = 4;
    conferir(f->C_GetSlotList(CK_TRUE, slots, &quantos) == CKR_OK && quantos == 1 && slots[0] == 13,
             "o primeiro slot é o do token, com o id real");

    CK_ULONG verdadeiro = 1;
    CK_ATTRIBUTE como_o_assinador = { CKA_TOKEN, &verdadeiro, sizeof(verdadeiro) };
    conferir(f->C_FindObjectsInit(1, &como_o_assinador, 1) == CKR_OK,
             "aceita CKA_TOKEN em 8 bytes, como o assinador manda");
    return falhas != 0;
}
