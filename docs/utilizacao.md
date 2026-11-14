# Guia de utilização

## Iniciar a interface

```bash
cd ~/IA-Local-Ollama
./ia.sh
```

Execute sem `sudo`. O menu oferece:

1. Selecionar modelo.
2. Nova conversa.
3. Histórico de conversas.
4. Listar modelos instalados.
5. Ajuda e comandos.
6. Encerrar IA e desmontar pendrive.
0. Sair.

## Comandos durante uma conversa

| Comando | Ação |
|---|---|
| `/sair` | Encerra a conversa atual e gera o título; as mensagens já foram salvas |
| `/bye` | Mesmo comportamento de `/sair` |
| `Ctrl+D` | Também encerra a conversa e gera o título |
| `/limpar` | Apaga as mensagens e o contexto da conversa selecionada |

## Comandos úteis do Ollama

```bash
ollama list
ollama pull NOME_DO_MODELO
ollama show NOME_DO_MODELO
systemctl status ollama
systemctl is-active ollama
```

## Histórico

O banco fica em `/mnt/IA/conversas/historico.db`. O sistema permite visualizar, continuar, renomear e excluir conversas anteriores. Ao encerrar uma conversa (`/sair`, `/bye` ou `Ctrl+D`), o modelo recebe o contexto e gera um título curto em português (3 a 6 palavras, no máximo 60 caracteres), que é salvo no histórico. Se a geração falhar, o título padrão é mantido e uma nova tentativa ocorre na próxima vez que a conversa for encerrada. A renomeação manual impede que o título automático substitua o nome escolhido. A exclusão exige que o usuário digite exatamente `SIM` e remove a conversa e suas mensagens em uma transação SQLite.

## Encerrar

Use a opção **6. Encerrar IA e desmontar pendrive**. O script para o serviço e tenta desmontar `/mnt/IA`. Não desconecte o dispositivo até a operação terminar. A opção `0` apenas sai do menu; não equivale ao encerramento do serviço e à desmontagem.
