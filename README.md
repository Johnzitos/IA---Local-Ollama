# IA Local com Ollama no Debian

[![CI](../../actions/workflows/ci.yml/badge.svg)](../../actions/workflows/ci.yml)
[![Licença: MIT](https://img.shields.io/badge/licen%C3%A7a-MIT-blue.svg)](LICENSE)
![Shell: Bash](https://img.shields.io/badge/shell-bash-4EAA25.svg)
![Plataforma: Debian 13](https://img.shields.io/badge/plataforma-Debian%2013-A81D33.svg)

Ambiente de inteligência artificial **100% local** no Debian, usando o [Ollama](https://ollama.com/). Os modelos e o histórico de conversas ficam em um pendrive dedicado, e a interação é feita por um menu em Bash com histórico em SQLite. Nenhuma conversa depende de serviço externo.

> **Estado do projeto:** em fase de testes. Desenvolvido e validado no Debian 13. Adapte UUID, caminhos e requisitos ao seu equipamento antes de executar.

## Funcionalidades

- Seleção entre os modelos instalados no Ollama.
- Conversas com contexto, enviadas à API local (`127.0.0.1:11434`).
- Histórico persistente em SQLite: visualizar, continuar, renomear e excluir conversas.
- **Título automático:** ao encerrar a conversa, o modelo lê o contexto e salva um título curto no histórico. Títulos definidos manualmente nunca são sobrescritos.
- Inicialização e encerramento do serviço Ollama, com montagem e desmontagem seguras do pendrive.

## Requisitos

Debian 13, Ollama, `bash`, `curl`, `jq`, `sqlite3`, `util-linux`, `sudo` e `ncurses-bin`. Detalhes em [docs/requisitos.md](docs/requisitos.md).

```bash
sudo apt update
sudo apt install git bash curl jq sqlite3 util-linux sudo coreutils gawk grep sed ncurses-bin
```

## Início rápido

Pré-requisito: pendrive em EXT4 montado em `/mnt/IA` e Ollama configurado para usar `/mnt/IA/modelos` (passo a passo em [docs/instalacao.md](docs/instalacao.md)).

```bash
git clone https://github.com/Johnzitos/IA-Local-Ollama.git
cd IA-Local-Ollama

export IA_UUID="UUID_DO_SEU_PENDRIVE"   # obtido com: sudo blkid
bash ia.sh                                  # execute como usuário comum, sem sudo
```

Dentro de uma conversa: `/sair` ou `/bye` encerram e geram o título; `/limpar` apaga o contexto.

## Estrutura do repositório

```text
.
├── ia.sh                  # interface em Bash (menu, conversas, histórico)
├── docs/                  # documentação detalhada e fluxograma
├── tests/                 # testes automatizados (Ollama simulado)
├── .github/               # CI, modelos de issue e de pull request
├── CHANGELOG.md
├── CONTRIBUTING.md
├── SECURITY.md
└── LICENSE
```

## Documentação

- [Contexto](docs/contexto.md) · [Vantagens](docs/vantagens.md) · [Requisitos](docs/requisitos.md)
- [Guia de instalação](docs/instalacao.md) · [Guia de utilização](docs/utilizacao.md)
- [Fluxograma de funcionamento](docs/fluxo-de-trabalho.md) · [Problemas comuns](docs/problemas-comuns.md)

## Modelos

Qualquer modelo da [biblioteca do Ollama](https://ollama.com/library) compatível com o seu hardware pode ser usado. Nos testes: `qwen3:1.7b`, `qwen3:4b`, `qwen3:8b` e `gemma3:4b`.

## Testes

```bash
bash tests/test_titulo.sh   # geração de título, com um servidor Ollama simulado
shellcheck -x ia.sh tests/test_titulo.sh
```

Os mesmos passos rodam automaticamente no GitHub Actions a cada push e pull request.

## Segurança e privacidade

O banco `historico.db` guarda o conteúdo das conversas em texto puro e fica em `/mnt/IA/conversas/`. **Nunca publique esse banco nem UUIDs de dispositivos.** O `.gitignore` já exclui arquivos SQLite. Veja [SECURITY.md](SECURITY.md).

## Roteiro

- [ ] Testar todas as opções do menu e a geração de título com os quatro modelos.
- [ ] Verificar a integridade do histórico após reiniciar o computador.
- [ ] Avaliar o desempenho dos modelos disponíveis.
- [ ] Melhorar a interface e a experiência de uso.

## Contribuindo

Contribuições são bem-vindas. Leia o [guia de contribuição](CONTRIBUTING.md) e abra uma issue antes de mudanças grandes.

## Licença

Distribuído sob a licença [MIT](LICENSE).
