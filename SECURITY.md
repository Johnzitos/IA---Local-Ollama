# Política de segurança

## Versões suportadas

Recebe correções apenas a versão mais recente na branch `main`.

## Como reportar uma vulnerabilidade

**Não abra uma issue pública.** Use o relato privado do GitHub: aba **Security → Report a vulnerability** deste repositório. Descreva o problema, os passos para reproduzir e o impacto esperado.

## Pontos de atenção do projeto

- **Histórico em texto puro:** `historico.db` guarda as conversas sem criptografia. O script cria o diretório com permissão `700` e usa `umask 077`, mas quem tiver acesso ao pendrive montado pode ler o conteúdo. Considere criptografar a partição (por exemplo, com LUKS) se as conversas forem sensíveis.
- **Uso de `sudo`:** o script usa `sudo` para montar/desmontar o pendrive, ler o UUID (`blkid`), preparar o diretório de histórico e controlar o serviço `ollama`. Revise o código antes de executá-lo e **não o rode como root**.
- **API local sem autenticação:** o Ollama escuta em `127.0.0.1:11434`. Não exponha essa porta para a rede.
- **Dados em contribuições:** nunca publique bancos de dados ou UUIDs de dispositivos.
