# Fluxograma de funcionamento

Os diagramas abaixo descrevem o fluxo implementado em `ia.sh` e são exibidos automaticamente pelo GitHub.

## 1. Visão geral

Da execução do script até o encerramento: verificações do ambiente, menu principal e as ações de cada opção.

```mermaid
flowchart TD
    A(["Executar ./ia.sh"]) --> B{"Executando como root?"}
    B -->|"Sim"| X1(["Aborta: use um usuário comum"])
    B -->|"Não"| C{"ollama, sqlite3, jq e curl instalados?"}
    C -->|"Não"| X2(["Erro: dependência ausente"])
    C -->|"Sim"| D["Montar /mnt/IA se necessário"]
    D --> E{"UUID e sistema EXT4 conferem?"}
    E -->|"Não"| X3(["Erro: dispositivo inesperado"])
    E -->|"Sim"| F{"OLLAMA_MODELS aponta para /mnt/IA/modelos?"}
    F -->|"Não"| X4(["Erro: Ollama não configurado"])
    F -->|"Sim"| G["Preparar pasta do histórico e banco SQLite"]
    G --> H["Iniciar ollama.service"]
    H --> M{"Menu principal"}

    M -->|"1"| S["Selecionar modelo instalado"]
    S --> M
    M -->|"2"| N{"Há modelo selecionado?"}
    N -->|"Não"| M
    N -->|"Sim"| NC["Criar conversa no SQLite"]
    NC --> CONV[["Conversa e título automático - diagrama 2"]]
    CONV --> M
    M -->|"3"| HI["Histórico de conversas"]
    HI --> HO{"Ação escolhida"}
    HO -->|"Visualizar"| HV["Exibir as mensagens"]
    HV --> M
    HO -->|"Continuar"| CONV
    HO -->|"Renomear"| HR["Salvar título manual e bloquear o automático"]
    HR --> M
    HO -->|"Excluir"| HE{"Digitou SIM?"}
    HE -->|"Sim"| HX["Apagar conversa e mensagens em uma transação"]
    HE -->|"Não"| M
    HX --> M
    M -->|"4 ou 5"| L["Listar modelos ou exibir ajuda"]
    L --> M

    M -->|"6"| Q1["Parar ollama.service"]
    Q1 --> Q2["Ir para o diretório HOME"]
    Q2 --> Q3["sync e desmontar /mnt/IA"]
    Q3 --> Q4{"Desmontou?"}
    Q4 -->|"Sim"| Z(["Fim"])
    Q4 -->|"Não"| Q5["Erro: alvo ocupado, serviço já parado"]
    Q5 --> Z
    M -->|"0"| Z
```

## 2. Conversa e título automático

Cada mensagem é enviada à API local com o histórico da conversa e salva no SQLite. O título é gerado **ao encerrar** a conversa.

```mermaid
flowchart TD
    L["Ler mensagem do usuário"] --> LC{"O que foi digitado?"}
    LC -->|"Vazio"| L
    LC -->|"/limpar"| LL["Apagar as mensagens da conversa"]
    LL --> L
    LC -->|"Texto"| LH["Montar histórico mais a nova mensagem"]
    LH --> LA["Enviar ao Ollama em 127.0.0.1:11434"]
    LA --> LR{"Resposta válida?"}
    LR -->|"Não"| LE["Mostrar erro de comunicação"]
    LE --> L
    LR -->|"Sim"| LS["Salvar pergunta e resposta no SQLite"]
    LS --> LP["Exibir a resposta"]
    LP --> L

    LC -->|"/sair, /bye ou Ctrl+D"| T0{"Título já definido?"}
    T0 -->|"Sim"| FIM(["Voltar ao menu"])
    T0 -->|"Não"| T1{"Há mensagens do usuário?"}
    T1 -->|"Não"| FIM
    T1 -->|"Sim"| T2["Enviar o contexto ao modelo com think false"]
    T2 --> T3{"Veio texto?"}
    T3 -->|"Sim"| T7["Limpar o texto: aspas, prefixo Título, limite de 60 caracteres"]
    T3 -->|"Não"| T4["Repetir a requisição sem o parâmetro think"]
    T4 --> T5{"Veio texto?"}
    T5 -->|"Sim"| T7
    T5 -->|"Não"| T6["Avisar e manter o título padrão"]
    T6 --> FIM
    T7 --> T8["Salvar o título e marcar como gerado"]
    T8 --> FIM
```
