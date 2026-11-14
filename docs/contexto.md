# Contexto

O projeto consiste em montar um ambiente de inteligência artificial local no Debian utilizando o Ollama. Os modelos são armazenados em um dispositivo USB dedicado, montado em `/mnt/IA`, e o histórico de conversas é persistido em um banco SQLite no mesmo dispositivo.

A interface é um script Bash que conversa com a API local `http://127.0.0.1:11434/api/chat`. O serviço do Ollama é gerenciado pelo systemd e configurado para utilizar `/mnt/IA/modelos`.

O ambiente de referência foi desenvolvido no Debian 13. A configuração deve ser adaptada para cada computador e dispositivo de armazenamento.
