# Guia de contribuição

Obrigado por querer contribuir! Este guia mantém o projeto simples de revisar e seguro de usar.

## Antes de começar

- Procure nas [issues](../../issues) se o assunto já existe.
- Para mudanças grandes, abra uma issue descrevendo a ideia antes de escrever código.
- **Nunca inclua dados pessoais** em issues, commits ou pull requests: bancos `historico.db`, conteúdo de conversas, UUIDs de dispositivos e nomes de usuário.

## Fluxo de trabalho

1. Faça um fork e crie uma branch a partir de `main`: `feat/descricao-curta` ou `fix/descricao-curta`.
2. Faça mudanças pequenas e focadas, uma ideia por pull request.
3. Rode as verificações locais (abaixo).
4. Atualize a documentação em `docs/` e o `CHANGELOG.md` (seção `[Unreleased]`) quando o comportamento mudar.
5. Abra o pull request preenchendo o modelo.

## Mensagens de commit

Use [Conventional Commits](https://www.conventionalcommits.org/pt-br/):

```text
feat: gerar título ao encerrar a conversa
fix: voltar ao HOME antes de desmontar o pendrive
docs: explicar a variável IA_UUID
test: cobrir resposta vazia do modelo
```

## Verificações locais

Dependências extras para desenvolver: `shellcheck` e `python3`.

```bash
for f in ia.sh tests/*.sh; do bash -n "$f"; done   # sintaxe
shellcheck -x ia.sh tests/*.sh                      # análise estática
bash tests/test_titulo.sh                           # testes
```

O CI executa exatamente esses passos; o pull request só deve ser integrado com o CI verde.

## Estilo do código Bash

Seguimos o [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) no que for prático:

- Mantenha `set -Eeuo pipefail` e coloque aspas em todas as expansões de variável.
- Use `local` para variáveis de função e `[[ ... ]]` em testes.
- Indentação de 4 espaços (veja `.editorconfig`) e finais de linha LF.
- Escape valores em SQL com `sql_quote` e monte JSON com `jq`, nunca por concatenação de texto.
- Funções que podem falhar sem ser críticas devem retornar `0` ou ser protegidas, para não derrubar o menu sob `set -e`.
