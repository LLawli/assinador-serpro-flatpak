/*
 * Módulo PKCS#11 de mentira, no lugar do p11-kit-client.so: três slots, os dois
 * primeiros de confiança, e um C_Initialize e um C_FindObjectsInit que recusam
 * o que o cliente RPC do p11-kit recusa.
 */
#include <string.h>

#include <p11-kit/pkcs11.h>

#define SLOT_DO_TOKEN 13

static const CK_SLOT_ID slots[] = { 11, 12, SLOT_DO_TOKEN };
#define TOTAL (sizeof(slots) / sizeof(slots[0]))

static CK_RV iniciar(void *argumentos)
{
    CK_C_INITIALIZE_ARGS *a = argumentos;

    if (a != NULL && !(a->flags & CKF_OS_LOCKING_OK))
        return CKR_CANT_LOCK;
    return CKR_OK;
}

static CK_RV listar(CK_BBOOL com_token, CK_SLOT_ID *saida, CK_ULONG *quantos)
{
    (void)com_token;
    if (saida != NULL) {
        if (*quantos < TOTAL)
            return CKR_BUFFER_TOO_SMALL;
        memcpy(saida, slots, sizeof(slots));
    }
    *quantos = TOTAL;
    return CKR_OK;
}

static CK_RV token(CK_SLOT_ID slot, CK_TOKEN_INFO *info)
{
    const char *modelo = slot == SLOT_DO_TOKEN ? "um token qualquer" : "p11-kit-trust";

    memset(info->model, ' ', sizeof(info->model));
    memcpy(info->model, modelo, strlen(modelo));
    return CKR_OK;
}

/* Como o RPC do p11-kit: atributo booleano só com o tamanho de booleano. */
static CK_RV procurar(CK_SESSION_HANDLE sessao, CK_ATTRIBUTE *modelo, CK_ULONG quantos)
{
    (void)sessao;
    for (CK_ULONG i = 0; i < quantos; i++) {
        if (modelo[i].type == CKA_TOKEN && modelo[i].ulValueLen != sizeof(CK_BBOOL))
            return CKR_HOST_MEMORY;
    }
    return CKR_OK;
}

static CK_FUNCTION_LIST lista = {
    .version = { 3, 0 },
    .C_Initialize = iniciar,
    .C_GetSlotList = listar,
    .C_GetTokenInfo = token,
    .C_FindObjectsInit = procurar,
};

CK_RV C_GetFunctionList(CK_FUNCTION_LIST **saida)
{
    *saida = &lista;
    return CKR_OK;
}
