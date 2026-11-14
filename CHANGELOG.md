# Changelog

Todas as mudanças relevantes deste projeto são registradas aqui.

O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e o projeto adota [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Unreleased]

## [0.1.0] - 2026-11-14

### Adicionado

- Interface em Bash com menu: seleção de modelo, nova conversa, histórico, listagem de modelos, ajuda e encerramento.
- Conversas com contexto via API local do Ollama (`/api/chat`).
- Histórico em SQLite com visualização, continuação, renomeação e exclusão (com confirmação `SIM` e transação).
- Verificações de ambiente: dependências, montagem, UUID, sistema de arquivos EXT4 e `OLLAMA_MODELS`.
- UUID do dispositivo configurável pela variável de ambiente `IA_UUID`.
- Testes automatizados da geração de título, com servidor Ollama simulado, e CI com ShellCheck.
- Documentação completa em `docs/`.

### Corrigido

- Geração automática de título: passa a ocorrer ao encerrar a conversa, com `think: false` (modelos Qwen3 devolviam texto vazio), nova tentativa sem o parâmetro quando o modelo o rejeita, e limpeza de aspas, prefixo "Título:" e blocos `<think>`.
- Encerramento: o script muda para `$HOME` antes de desmontar, evitando `umount: o alvo está ocupado`.

[Unreleased]: ../../compare/v0.1.0...HEAD
[0.1.0]: ../../releases/tag/v0.1.0
