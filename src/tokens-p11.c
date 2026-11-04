/*
 * tokens-p11.so: o único módulo PKCS#11 que o Assinador Serpro carrega.
 *
 * Tudo vai para o p11-kit-client.so do runtime, que fala com o servidor p11-kit
 * do usuário pelo socket $XDG_RUNTIME_DIR/p11-kit/pkcs11. É o caminho do
 * PJeOffice Pro da FlatPark, e por ele o Tessera e afins servem o token.
 *
 * Três chamadas mudam. A primeira é a lista de slots: o assinador monta a configuração do SunPKCS11 com
 * "name" e "library", sem "slot", e o SunPKCS11 usa o primeiro slot com token.
 * Nesse socket os primeiros são os do p11-kit-trust (System Trust e Default
 * Trust), que não têm chave privada: sem este filtro o assinador abriria um
 * deles e diria que não há certificado.
 *
 * A segunda é C_Initialize. A listagem de dispositivos do assinador (LoadLib)
 * chama sem CKF_OS_LOCKING_OK, e o cliente RPC do p11-kit recusa isso com
 * CKR_CANT_LOCK; como o cliente é multithread de qualquer forma, a flag é
 * acrescentada aqui.
 *
 * A terceira é C_FindObjectsInit. A mesma listagem procura com CKA_TOKEN, que é
 * um booleano de 1 byte, mas manda um Long de 8. Um driver local tolera; o RPC
 * do p11-kit valida o tamanho e responde CKR_HOST_MEMORY.
 */
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>

#include <p11-kit/pkcs11.h>

#ifndef MODULO_CLIENTE
#error "defina MODULO_CLIENTE com o caminho do p11-kit-client.so"
#endif

#define MODELO_CONFIANCA "p11-kit-trust"

static CK_FUNCTION_LIST *cliente;
static CK_FUNCTION_LIST lista;

static int token_de_confianca(CK_SLOT_ID slot)
{
    CK_TOKEN_INFO info;

    if (cliente->C_GetTokenInfo(slot, &info) != CKR_OK)
        return 0;
    return memcmp(info.model, MODELO_CONFIANCA, strlen(MODELO_CONFIANCA)) == 0;
}

static CK_RV iniciar(void *argumentos)
{
    CK_C_INITIALIZE_ARGS copia;

    if (argumentos == NULL)
        return cliente->C_Initialize(NULL);

    copia = *(CK_C_INITIALIZE_ARGS *)argumentos;
    copia.flags |= CKF_OS_LOCKING_OK;
    return cliente->C_Initialize(&copia);
}

static CK_RV procurar(CK_SESSION_HANDLE sessao, CK_ATTRIBUTE *modelo, CK_ULONG quantos)
{
    if (quantos == 1 && modelo[0].type == CKA_TOKEN
        && modelo[0].ulValueLen == sizeof(CK_ULONG)) {
        CK_BBOOL valor = *(CK_ULONG *)modelo[0].pValue != 0;
        CK_ATTRIBUTE corrigido = { CKA_TOKEN, &valor, sizeof(valor) };

        return cliente->C_FindObjectsInit(sessao, &corrigido, 1);
    }
    return cliente->C_FindObjectsInit(sessao, modelo, quantos);
}

static CK_RV listar_slots(CK_BBOOL com_token, CK_SLOT_ID *slots, CK_ULONG *quantos)
{
    CK_SLOT_ID *todos;
    CK_ULONG total = 0;
    CK_ULONG visiveis = 0;
    CK_RV rv;

    if (quantos == NULL)
        return CKR_ARGUMENTS_BAD;

    rv = cliente->C_GetSlotList(com_token, NULL, &total);
    if (rv != CKR_OK)
        return rv;

    todos = calloc(total ? total : 1, sizeof(*todos));
    if (todos == NULL)
        return CKR_HOST_MEMORY;

    rv = cliente->C_GetSlotList(com_token, todos, &total);
    if (rv != CKR_OK) {
        free(todos);
        return rv;
    }

    for (CK_ULONG i = 0; i < total; i++) {
        if (!token_de_confianca(todos[i]))
            todos[visiveis++] = todos[i];
    }

    if (slots != NULL) {
        if (*quantos < visiveis)
            rv = CKR_BUFFER_TOO_SMALL;
        else
            memcpy(slots, todos, visiveis * sizeof(*todos));
    }
    *quantos = visiveis;
    free(todos);
    return rv;
}

/*
 * Só C_GetFunctionList é exportada: sem C_GetInterface o SunPKCS11 usa a lista
 * 2.x, e a versão é fixada em 2.40 para ninguém procurar as funções da 3.0
 * depois do fim desta estrutura.
 */
CK_RV C_GetFunctionList(CK_FUNCTION_LIST **saida)
{
    if (saida == NULL)
        return CKR_ARGUMENTS_BAD;

    if (cliente == NULL) {
        CK_RV (*obter)(CK_FUNCTION_LIST **);
        void *modulo = dlopen(MODULO_CLIENTE, RTLD_NOW | RTLD_LOCAL);
        CK_RV rv;

        if (modulo == NULL)
            return CKR_GENERAL_ERROR;
        *(void **)&obter = dlsym(modulo, "C_GetFunctionList");
        if (obter == NULL)
            return CKR_GENERAL_ERROR;
        rv = obter(&cliente);
        if (rv != CKR_OK)
            return rv;

        lista = *cliente;
        lista.version.major = 2;
        lista.version.minor = 40;
        lista.C_Initialize = iniciar;
        lista.C_GetSlotList = listar_slots;
        lista.C_FindObjectsInit = procurar;
    }

    *saida = &lista;
    return CKR_OK;
}
