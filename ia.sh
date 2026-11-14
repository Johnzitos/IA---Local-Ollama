#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

# ==========================================
# CONFIGURACOES
# ==========================================

MOUNT="/mnt/IA"
UUID="${IA_UUID:-COLOQUE_O_UUID_DO_PENDRIVE}"
MODEL_DIR="$MOUNT/modelos"
HISTORY_DIR="$MOUNT/conversas"
DB="$HISTORY_DIR/historico.db"
API="http://127.0.0.1:11434/api/chat"

MODEL=""

# CORES
VERDE='\033[0;32m'
AZUL='\033[0;34m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
RESET='\033[0m'

# ==========================================
# FUNCOES GERAIS
# ==========================================

titulo() {
    clear
    echo -e "${AZUL}"
    echo "======================================"
    echo "          IA LOCAL - OLLAMA"
    echo "======================================"
    echo -e "${RESET}"
}

pausa() {
    echo
    read -rp "Pressione ENTER para continuar..."
}

erro() {
    echo -e "${VERMELHO}ERRO: $1${RESET}"
    pausa
}

sql_quote() {
    local valor="$1"
    valor=${valor//\'/\'\'}
    printf "'%s'" "$valor"
}

# ==========================================
# BANCO DE DADOS SQLITE
# ==========================================

preparar_banco() {
    sqlite3 "$DB" <<'SQL'
PRAGMA journal_mode=WAL;

CREATE TABLE IF NOT EXISTS conversas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    modelo TEXT NOT NULL,
    titulo TEXT NOT NULL,
    criada_em TEXT NOT NULL,
    atualizada_em TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS mensagens (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    conversa_id INTEGER NOT NULL,
    papel TEXT NOT NULL CHECK(papel IN ('user','assistant')),
    conteudo TEXT NOT NULL,
    criada_em TEXT NOT NULL,
    FOREIGN KEY (conversa_id) REFERENCES conversas(id)
);

CREATE INDEX IF NOT EXISTS idx_mensagens_conversa
ON mensagens(conversa_id, id);
SQL

    # Adiciona a coluna em bancos existentes.
    if ! sqlite3 "$DB" "PRAGMA table_info(conversas);" |
        awk -F'|' '$2 == "titulo_gerado" { encontrado=1 } END { exit !encontrado }'; then

        sqlite3 "$DB" "
            ALTER TABLE conversas
            ADD COLUMN titulo_gerado INTEGER NOT NULL DEFAULT 0;
        "
    fi
}

# ==========================================
# INICIALIZACAO DO OLLAMA
# ==========================================

preparar_ia() {
    echo "Verificando pendrive..."

    for programa in ollama sqlite3 jq curl; do
        if ! command -v "$programa" >/dev/null 2>&1; then
            erro "Programa não encontrado: $programa"
            return 1
        fi
    done

    if ! mountpoint -q "$MOUNT"; then
        echo "Montando pendrive..."

        sudo mount "$MOUNT" || {
            erro "Não foi possível montar o pendrive."
            return 1
        }
    fi

    local origem uuid tipo

    origem=$(findmnt -nro SOURCE --target "$MOUNT" | head -n1)
    tipo=$(findmnt -nro FSTYPE --target "$MOUNT" | head -n1)
    uuid=$(sudo blkid -s UUID -o value "$origem")

    if [[ "$uuid" != "$UUID" || "$tipo" != "ext4" ]]; then
        erro "O dispositivo montado não corresponde ao pendrive esperado."
        return 1
    fi

    if [[ ! -d "$MODEL_DIR" ]]; then
        erro "Diretório dos modelos não encontrado."
        return 1
    fi

    local ambiente

    ambiente=$(systemctl show ollama -p Environment --value)

    if [[ " $ambiente " != *" OLLAMA_MODELS=$MODEL_DIR "* ]]; then
        erro "O Ollama não está configurado para usar os modelos do pendrive."
        return 1
    fi

    sudo install -d -o "$USER" -g "$(id -gn)" -m 700 "$HISTORY_DIR"

    preparar_banco

    echo "Iniciando Ollama..."
    sudo systemctl start ollama

    if ! systemctl is-active --quiet ollama; then
        erro "O serviço Ollama não iniciou."
        return 1
    fi

    echo -e "${VERDE}IA pronta para uso!${RESET}"
}

# ==========================================
# MODELOS
# ==========================================

listar_modelos() {
    ollama list
}

selecionar_modelo() {
    mapfile -t MODELOS < <(
        ollama list | awk 'NR > 1 && NF {print $1}'
    )

    if [[ ${#MODELOS[@]} -eq 0 ]]; then
        erro "Nenhum modelo encontrado."
        return
    fi

    echo
    echo "MODELOS DISPONÍVEIS"
    echo "-------------------"

    for i in "${!MODELOS[@]}"; do
        echo "$((i + 1)). ${MODELOS[$i]}"
    done

    echo
    read -rp "Selecione o modelo: " escolha

    if [[ "$escolha" =~ ^[0-9]+$ ]] &&
       (( escolha >= 1 && escolha <= ${#MODELOS[@]} )); then

        MODEL="${MODELOS[$((escolha - 1))]}"

        echo -e "${VERDE}Modelo selecionado: $MODEL${RESET}"
    else
        echo -e "${VERMELHO}Seleção inválida.${RESET}"
    fi
}

modelo_disponivel() {
    local modelo="$1"

    ollama list |
        awk 'NR > 1 {print $1}' |
        grep -Fxq -- "$modelo"
}

# ==========================================
# GERACAO AUTOMATICA DO TITULO (AO FINAL DA CONVERSA)
# ==========================================

gerar_titulo() {
    local conversa_id="$1"
    local modelo="$2"
    local gerado quantidade transcricao instrucao payload resposta
    local novo_titulo="" com_think

    # Não sobrescreve título já definido (automático ou manual).
    gerado=$(sqlite3 "$DB" "
        SELECT titulo_gerado
        FROM conversas
        WHERE id = $conversa_id;
    ")

    if [[ "$gerado" != "0" ]]; then
        return 0
    fi

    quantidade=$(sqlite3 "$DB" "
        SELECT COUNT(*)
        FROM mensagens
        WHERE conversa_id = $conversa_id
          AND papel = 'user';
    ")

    if (( quantidade < 1 )); then
        return 0
    fi

    # Monta a transcrição como texto único (mais confiável para modelos pequenos).
    transcricao=$(sqlite3 -json "$DB" "
        SELECT papel AS role, conteudo AS content
        FROM mensagens
        WHERE conversa_id = $conversa_id
        ORDER BY id;
    " | jq -r '
        map(
            (if .role == "user" then "Usuário" else "IA" end)
            + ": " + (.content[0:600])
        )
        | join("\n\n")
        | .[0:5000]
    ' 2>/dev/null || true)

    if [[ -z "$transcricao" ]]; then
        return 0
    fi

    instrucao="Abaixo está uma conversa. Crie um título curto em português que resuma o assunto principal, com 3 a 6 palavras. Responda somente com o título, em uma única linha, sem aspas, sem pontuação final e sem explicações.

CONVERSA:
$transcricao

TÍTULO:"

    # Tenta primeiro com think=false (modelos qwen3 gastariam todos os tokens
    # "pensando" e devolveriam texto vazio). Se o modelo não aceitar o
    # parâmetro, tenta novamente sem ele.
    for com_think in false omitir; do

        payload=$(jq -n \
            --arg modelo "$modelo" \
            --arg instrucao "$instrucao" \
            --arg modo "$com_think" \
            '{
                model: $modelo,
                messages: [
                    { role: "user", content: $instrucao }
                ],
                stream: false,
                options: {
                    temperature: 0.2,
                    num_predict: 120
                }
            } + (if $modo == "false" then { think: false } else {} end)')

        if ! resposta=$(curl -fsS --max-time 180 \
            "$API" \
            -H "Content-Type: application/json" \
            -d "$payload" 2>/dev/null); then
            continue
        fi

        novo_titulo=$(jq -r '.message.content // empty' <<< "$resposta" 2>/dev/null || true)

        # Remove blocos <think>...</think> (modelos que embutem o raciocínio no texto).
        novo_titulo=$(printf '%s' "$novo_titulo" |
            sed -z 's/<think>.*<\/think>//g' |
            sed '/^[[:space:]]*$/d' |
            head -n 1 |
            sed -E '
                s/(\*|#|`|"|“|”)//g
                s/^[[:space:]'"'"']+//
                s/^[Tt](í|i)tulo[[:space:]]*:[[:space:]]*//
                s/[[:space:]'"'"'.]+$//
            ' || true)

        novo_titulo="${novo_titulo:0:60}"

        if [[ -n "$novo_titulo" ]]; then
            break
        fi
    done

    if [[ -z "$novo_titulo" ]]; then
        echo -e "${VERMELHO}Não foi possível gerar o título da conversa.${RESET}"
        return 0
    fi

    sqlite3 "$DB" "
        UPDATE conversas
        SET titulo = $(sql_quote "$novo_titulo"),
            titulo_gerado = 1
        WHERE id = $conversa_id;
    "

    echo -e "${VERDE}Título salvo no histórico: $novo_titulo${RESET}"
}

# ==========================================
# CONVERSAS
# ==========================================

conversar_com_id() {
    local conversa_id="$1"
    local modelo="$2"
    local mensagem historico payload resposta conteudo

    if ! modelo_disponivel "$modelo"; then
        erro "O modelo $modelo não está instalado."
        return
    fi

    MODEL="$modelo"

    echo
    echo -e "${VERDE}Conversa iniciada com $MODEL${RESET}"
    echo "Digite /sair para encerrar."
    echo "Digite /limpar para limpar o contexto da conversa."
    echo

    while true; do

        echo
        read -r -p "Você: " mensagem || break

        case "$mensagem" in
            /sair|/bye)
                echo "Conversa salva."
                break
                ;;

            /limpar)
                sqlite3 "$DB" "
                    DELETE FROM mensagens
                    WHERE conversa_id = $conversa_id;
                "

                echo "Contexto da conversa limpo."
                continue
                ;;

            "")
                continue
                ;;
        esac

        historico=$(sqlite3 -json "$DB" "
            SELECT papel AS role, conteudo AS content
            FROM mensagens
            WHERE conversa_id = $conversa_id
            ORDER BY id;
        ")

        historico=$(jq -c '.' <<< "${historico:-[]}" 2>/dev/null || printf '[]')

        payload=$(jq -n \
            --arg modelo "$modelo" \
            --argjson historico "$historico" \
            --arg mensagem "$mensagem" \
            '{
                model: $modelo,
                messages: ($historico + [
                    {
                        role: "user",
                        content: $mensagem
                    }
                ]),
                stream: false
            }')

        echo
        echo -e "${AMARELO}Pensando...${RESET}"

        if ! resposta=$(curl -fsS --max-time 600 \
            "$API" \
            -H "Content-Type: application/json" \
            -d "$payload"); then

            echo -e "${VERMELHO}Falha na comunicação com Ollama.${RESET}"
            continue
        fi

        if ! conteudo=$(jq -er '.message.content' <<< "$resposta"); then
            echo -e "${VERMELHO}Não foi possível interpretar a resposta.${RESET}"
            continue
        fi

        sqlite3 "$DB" "
            INSERT INTO mensagens
            (conversa_id, papel, conteudo, criada_em)
            VALUES
            ($conversa_id, 'user',
             $(sql_quote "$mensagem"),
             datetime('now','localtime'));

            INSERT INTO mensagens
            (conversa_id, papel, conteudo, criada_em)
            VALUES
            ($conversa_id, 'assistant',
             $(sql_quote "$conteudo"),
             datetime('now','localtime'));

            UPDATE conversas
            SET atualizada_em = datetime('now','localtime')
            WHERE id = $conversa_id;
        "

        echo
        echo -e "${AZUL}IA:${RESET}"
        printf '%s\n' "$conteudo"

    done

    # AO TERMINAR A CONVERSA, O MODELO GERA O TITULO COM BASE NO CONTEXTO.
    echo
    echo -e "${AMARELO}Gerando título da conversa...${RESET}"
    gerar_titulo "$conversa_id" "$modelo" || true

    pausa
}

# ==========================================
# NOVA CONVERSA
# ==========================================

nova_conversa() {
    if [[ -z "$MODEL" ]]; then
        erro "Selecione um modelo primeiro."
        return
    fi

    local data titulo_conversa conversa_id

    data=$(date '+%Y-%m-%d_%H-%M-%S')
    titulo_conversa="${MODEL}_${data}"

    conversa_id=$(sqlite3 "$DB" "
        INSERT INTO conversas
        (modelo, titulo, criada_em, atualizada_em)
        VALUES (
            $(sql_quote "$MODEL"),
            $(sql_quote "$titulo_conversa"),
            datetime('now','localtime'),
            datetime('now','localtime')
        );

        SELECT last_insert_rowid();
    ")

    conversar_com_id "$conversa_id" "$MODEL"
}

# ==========================================
# RENOMEAR CONVERSA
# ==========================================

renomear_conversa() {
    local id="$1"
    local titulo_atual novo_titulo

    titulo_atual=$(sqlite3 "$DB" "
        SELECT titulo
        FROM conversas
        WHERE id = $id;
    ")

    echo
    echo "Título atual: $titulo_atual"
    echo
    read -r -p "Digite o novo nome da conversa: " novo_titulo

    novo_titulo=$(printf '%s' "$novo_titulo" |
        sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

    if [[ -z "$novo_titulo" ]]; then
        echo -e "${VERMELHO}O nome não pode ficar vazio.${RESET}"
        pausa
        return
    fi

    if (( ${#novo_titulo} > 60 )); then
        echo -e "${VERMELHO}O nome deve ter no máximo 60 caracteres.${RESET}"
        pausa
        return
    fi

    sqlite3 "$DB" "
        UPDATE conversas
        SET titulo = $(sql_quote "$novo_titulo"),
            titulo_gerado = 1
        WHERE id = $id;
    "

    echo
    echo -e "${VERDE}Conversa renomeada com sucesso!${RESET}"
    echo "Novo nome: $novo_titulo"

    pausa
}

# ==========================================
# EXCLUIR CONVERSA
# ==========================================

excluir_conversa() {
    local id="$1"
    local titulo_conversa confirmacao

    titulo_conversa=$(sqlite3 "$DB" "
        SELECT titulo
        FROM conversas
        WHERE id = $id;
    ")

    echo
    echo -e "${VERMELHO}EXCLUIR CONVERSA${RESET}"
    echo "Título: $titulo_conversa"
    echo
    echo "ATENÇÃO: Todas as mensagens dessa conversa serão apagadas."
    echo

    read -rp "Tem certeza? Digite SIM para confirmar: " confirmacao

    if [[ "$confirmacao" != "SIM" ]]; then
        echo "Exclusão cancelada."
        pausa
        return
    fi

    sqlite3 "$DB" "
        BEGIN TRANSACTION;

        DELETE FROM mensagens
        WHERE conversa_id = $id;

        DELETE FROM conversas
        WHERE id = $id;

        COMMIT;
    "

    echo
    echo -e "${VERDE}Conversa excluída com sucesso!${RESET}"

    pausa
}

# ==========================================
# VISUALIZAR HISTORICO
# ==========================================

visualizar_conversa() {
    local id="$1"

    echo
    echo "======================================"
    echo "          HISTÓRICO DA CONVERSA"
    echo "======================================"

    sqlite3 -json "$DB" "
        SELECT papel, conteudo, criada_em
        FROM mensagens
        WHERE conversa_id = $id
        ORDER BY id;
    " | jq -r '
        .[] |
        "\n[\(.criada_em)] \(.papel):\n\(.conteudo)\n"
    '

    pausa
}

# ==========================================
# MENU DE HISTORICO
# ==========================================

historico() {
    local -a IDS
    local escolha id modelo titulo_conversa data opcao arquivo

    mapfile -t IDS < <(
        sqlite3 "$DB" "
            SELECT id
            FROM conversas
            ORDER BY atualizada_em DESC;
        "
    )

    echo
    echo "HISTÓRICO DE CONVERSAS"
    echo "----------------------"

    if [[ ${#IDS[@]} -eq 0 ]]; then
        echo "Nenhuma conversa salva no banco."
    else
        for i in "${!IDS[@]}"; do
            id="${IDS[$i]}"

            IFS='|' read -r modelo titulo_conversa data < <(
                sqlite3 "$DB" "
                    SELECT modelo, titulo, atualizada_em
                    FROM conversas
                    WHERE id = $id;
                "
            )

            echo "$((i + 1)). $titulo_conversa"
            echo "   Modelo: $modelo | Última atividade: $data"
        done
    fi

    # MOSTRA GRAVACOES ANTIGAS
    shopt -s nullglob
    local antigos=("$HISTORY_DIR"/*.typescript)
    shopt -u nullglob

    if [[ ${#antigos[@]} -gt 0 ]]; then
        echo
        echo "Gravações antigas do terminal:"

        for arquivo in "${antigos[@]}"; do
            echo " - $(basename "$arquivo")"
        done
    fi

    if [[ ${#IDS[@]} -eq 0 ]]; then
        pausa
        return
    fi

    echo
    read -rp "Selecione uma conversa ou 0 para voltar: " escolha

    if [[ ! "$escolha" =~ ^[0-9]+$ ]] ||
       (( escolha < 1 || escolha > ${#IDS[@]} )); then
        return
    fi

    id="${IDS[$((escolha - 1))]}"

    IFS='|' read -r modelo titulo_conversa data < <(
        sqlite3 "$DB" "
            SELECT modelo, titulo, atualizada_em
            FROM conversas
            WHERE id = $id;
        "
    )

    echo
    echo "CONVERSA: $titulo_conversa"
    echo
    echo "1. Visualizar conversa"
    echo "2. Continuar conversa"
    echo "3. Renomear conversa"
    echo "4. Excluir conversa"
    echo "0. Voltar"

    read -rp "Escolha: " opcao

    case "$opcao" in
        1)
            visualizar_conversa "$id"
            ;;

        2)
            conversar_com_id "$id" "$modelo"
            ;;

        3)
            renomear_conversa "$id"
            ;;

        4)
            excluir_conversa "$id"
            ;;

        *)
            return
            ;;
    esac
}

# ==========================================
# AJUDA
# ==========================================

ajuda() {
    titulo

    echo "COMANDOS DA CONVERSA"
    echo "--------------------"
    echo "/sair       - Salva e encerra"
    echo "/bye        - Salva e encerra"
    echo "/limpar     - Limpa o contexto salvo"
    echo
    echo "HISTÓRICO"
    echo "---------"
    echo "Você pode visualizar, continuar, renomear e excluir conversas."
    echo
    echo "COMANDOS DO OLLAMA"
    echo "------------------"
    echo "ollama list          - Lista modelos"
    echo "ollama show MODELO   - Informações do modelo"
    echo "ollama pull MODELO   - Baixa um modelo"
    echo
    echo "BANCO DE DADOS"
    echo "--------------"
    echo "Local: $DB"
    echo "Formato: SQLite"

    pausa
}

# ==========================================
# ENCERRAR
# ==========================================

encerrar_ia() {
    echo "Encerrando Ollama..."

    sudo systemctl stop ollama

    if mountpoint -q "$MOUNT"; then
        echo "Desmontando pendrive..."

        # Sai do ponto de montagem antes de desmontar.
        cd "$HOME" || return 1
        sync

        sudo umount "$MOUNT" || {
            erro "Não foi possível desmontar. Verifique se há arquivos em uso."
            return
        }
    fi

    MODEL=""

    echo -e "${VERDE}Ollama encerrado e pendrive desmontado.${RESET}"

    pausa
}

# ==========================================
# INICIO DO PROGRAMA
# ==========================================

# Permite carregar as funções com "source ia.sh" (usado nos testes)
# sem iniciar o menu.
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    return 0
fi

if [[ "$EUID" -eq 0 ]]; then
    echo "Execute como usuário normal, sem sudo."
    exit 1
fi

if ! preparar_ia; then
    exit 1
fi

# ==========================================
# MENU PRINCIPAL
# ==========================================

while true; do

    titulo

    echo "Pendrive: conectado"
    echo "Ollama: $(systemctl is-active ollama)"
    echo "Modelo: ${MODEL:-Nenhum selecionado}"
    echo
    echo "1. Selecionar modelo"
    echo "2. Nova conversa"
    echo "3. Histórico de conversas"
    echo "4. Listar modelos instalados"
    echo "5. Ajuda e comandos"
    echo "6. Encerrar IA e desmontar pendrive"
    echo "0. Sair"
    echo

    read -rp "Escolha uma opção: " opcao

    case "$opcao" in
        1)
            selecionar_modelo
            pausa
            ;;

        2)
            nova_conversa
            ;;

        3)
            historico
            ;;

        4)
            listar_modelos
            pausa
            ;;

        5)
            ajuda
            ;;

        6)
            encerrar_ia
            break
            ;;

        0)
            exit 0
            ;;

        *)
            echo -e "${VERMELHO}Opção inválida.${RESET}"
            pausa
            ;;
    esac

done
