#!/usr/bin/env bash
# Testes da geração automática de título (gerar_titulo) com um Ollama simulado.
# Requisitos: bash, python3, sqlite3, jq, curl.

# As variáveis de cor, DB e API abaixo são usadas pelas funções carregadas de ia.sh.
# shellcheck disable=SC2034
set -Eeuo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
PORTA="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')"

python3 "$RAIZ/tests/mock_ollama.py" "$PORTA" &
SERVIDOR=$!
trap 'kill "$SERVIDOR" 2>/dev/null || true; rm -rf "$TMP"' EXIT

# Aguarda o servidor simulado subir.
for _ in $(seq 1 50); do
    if curl -s -o /dev/null -m 1 -X POST "http://127.0.0.1:$PORTA/" -d '{"model":"x"}' 2>/dev/null; then
        break
    fi
    sleep 0.1
done

# Carrega as funções do script sem iniciar o menu.
# shellcheck source=/dev/null
source "$RAIZ/ia.sh"

DB="$TMP/historico.db"
API="http://127.0.0.1:$PORTA/api/chat"
VERDE=""; AZUL=""; AMARELO=""; VERMELHO=""; RESET=""
preparar_banco >/dev/null

FALHAS=0
TOTAL=0

nova_conversa_teste() {
    sqlite3 "$DB" "
        INSERT INTO conversas (modelo, titulo, criada_em, atualizada_em)
        VALUES ('$1', 'padrao_$1', 'x', 'x');
        SELECT last_insert_rowid();"
}

adicionar_mensagem() {
    sqlite3 "$DB" "
        INSERT INTO mensagens (conversa_id, papel, conteudo, criada_em)
        VALUES ($1, '$2', $(sql_quote "$3"), 'x');"
}

titulo_de() { sqlite3 "$DB" "SELECT titulo FROM conversas WHERE id = $1;"; }
gerado_de() { sqlite3 "$DB" "SELECT titulo_gerado FROM conversas WHERE id = $1;"; }

verificar() {
    local descricao="$1" esperado="$2" obtido="$3"
    TOTAL=$((TOTAL + 1))
    if [[ "$obtido" == "$esperado" ]]; then
        echo "ok   - $descricao"
    else
        echo "FALHA - $descricao"
        echo "        esperado: [$esperado]"
        echo "        obtido:   [$obtido]"
        FALHAS=$((FALHAS + 1))
    fi
}

conversa_com_modelo() {
    local id
    id=$(nova_conversa_teste "$1")
    adicionar_mensagem "$id" user "Como listar arquivos no Bash? It's 'urgente' \"já\""
    adicionar_mensagem "$id" assistant "Use ls -la"
    printf '%s' "$id"
}

# 1. Modelo que só responde com think=false (comportamento do qwen3).
id=$(conversa_com_modelo qwen3-think)
gerar_titulo "$id" qwen3-think >/dev/null
verificar "think=false gera título (qwen3)" "Listar Arquivos no Bash" "$(titulo_de "$id")"
verificar "marca titulo_gerado=1" "1" "$(gerado_de "$id")"

# 2. Modelo que rejeita o parâmetro think: repete a requisição sem ele.
id=$(conversa_com_modelo gemma-nothink)
gerar_titulo "$id" gemma-nothink >/dev/null
verificar "limpa aspas, prefixo 'Título:' e linhas extras" "Receita de Bolo" "$(titulo_de "$id")"

# 3. Raciocínio embutido em <think>...</think>.
id=$(conversa_com_modelo think-tags)
gerar_titulo "$id" think-tags >/dev/null
verificar "remove bloco <think>" "Dúvidas sobre Bash" "$(titulo_de "$id")"

# 4. Título longo é limitado a 60 caracteres.
id=$(conversa_com_modelo longo)
gerar_titulo "$id" longo >/dev/null
verificar "limita o título a 60 caracteres" "60" "$(titulo_de "$id" | awk '{ print length($0) }')"

# 5. Resposta vazia: mantém título padrão e permite nova tentativa depois.
id=$(conversa_com_modelo vazio)
gerar_titulo "$id" vazio >/dev/null
verificar "resposta vazia mantém o título padrão" "padrao_vazio" "$(titulo_de "$id")"
verificar "resposta vazia mantém titulo_gerado=0" "0" "$(gerado_de "$id")"

# 6. Título definido manualmente não é sobrescrito.
id=$(conversa_com_modelo qwen3-think)
sqlite3 "$DB" "UPDATE conversas SET titulo = 'Meu Nome', titulo_gerado = 1 WHERE id = $id;"
gerar_titulo "$id" qwen3-think >/dev/null
verificar "título manual não é sobrescrito" "Meu Nome" "$(titulo_de "$id")"

# 7. Conversa sem mensagens não gera título.
id=$(nova_conversa_teste qwen3-think)
gerar_titulo "$id" qwen3-think >/dev/null
verificar "conversa sem mensagens não gera título" "padrao_qwen3-think" "$(titulo_de "$id")"

# 8. API indisponível não interrompe o script (set -e / set -u).
API="http://127.0.0.1:1/api/chat"
id=$(conversa_com_modelo qwen3-think)
codigo=0
gerar_titulo "$id" qwen3-think >/dev/null || codigo=$?
verificar "API fora do ar retorna 0 sem abortar" "0" "$codigo"
verificar "API fora do ar mantém o título padrão" "padrao_qwen3-think" "$(titulo_de "$id")"

echo
echo "$((TOTAL - FALHAS))/$TOTAL testes passaram."
exit $((FALHAS > 0))
