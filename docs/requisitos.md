# Tabela de requisitos

## Ambiente de referência

| Categoria | Requisito / configuração |
|---|---|
| Sistema operacional | Debian 13 |
| Serviço de IA | Ollama (`ollama.service`) |
| Interface | Bash |
| Armazenamento | Dispositivo USB formatado em EXT4 |
| Ponto de montagem | `/mnt/IA` |
| Modelos | `/mnt/IA/modelos` |
| Histórico | `/mnt/IA/conversas/historico.db` |
| Banco de dados | SQLite |
| Comunicação | API local `127.0.0.1:11434` |
| Gerenciador de serviços | systemd |

## Dependências de software

| Pacote / ferramenta | Finalidade |
|---|---|
| `ollama` | Executar e gerenciar modelos |
| `bash` | Executar a interface |
| `curl` | Enviar requisições à API |
| `jq` | Montar e interpretar JSON |
| `sqlite3` | Persistir conversas e mensagens |
| `util-linux` | `mountpoint`, `findmnt` e `blkid` |
| `sudo` | Montagem e controle do serviço |
| `ncurses-bin` | Fornece o comando `clear` |
| `coreutils`, `gawk`, `grep`, `sed` | Utilitários usados pelo script |
| `git` | Obter o repositório (opcional) |

## Hardware

Não foi definido um requisito mínimo universal. A memória RAM, a VRAM e o espaço em disco necessários dependem do modelo escolhido, de sua quantização e do tamanho do contexto. Antes de baixar um modelo, consulte seus requisitos e considere que modelos maiores podem usar memória RAM além da VRAM.
