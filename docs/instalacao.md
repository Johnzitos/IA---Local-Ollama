# Guia de instalação

Este roteiro descreve a configuração de referência. Execute os comandos com atenção e confirme o dispositivo correto antes de particionar ou formatar. **A formatação apaga os dados do dispositivo selecionado.**

## 1. Instalar as dependências

```bash
sudo apt update
sudo apt install git bash curl jq sqlite3 util-linux sudo coreutils gawk grep sed ncurses-bin
```

Instale o Ollama seguindo a documentação oficial: https://ollama.com/download/linux. Depois confirme:

```bash
ollama --version
systemctl status ollama
```

## 2. Preparar o dispositivo USB

Identifique o dispositivo:

```bash
lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINTS
```

Formate a partição destinada ao projeto em EXT4 pelo GParted ou com ferramentas de terminal. Confira cuidadosamente o nome da partição; não copie comandos de formatação sem substituir o dispositivo pelo correto.

Crie o ponto de montagem e consulte o UUID:

```bash
sudo mkdir -p /mnt/IA
sudo blkid
```

Adicione uma entrada ao `/etc/fstab`, substituindo `UUID_DO_DISPOSITIVO` pelo UUID real:

```fstab
UUID=UUID_DO_DISPOSITIVO /mnt/IA ext4 defaults,nofail 0 2
```

Monte e confira:

```bash
sudo mount /mnt/IA
findmnt /mnt/IA
lsblk -f
```

## 3. Criar o diretório dos modelos e ajustar permissões

O serviço do Ollama deve conseguir gravar no diretório de modelos. Crie-o e atribua a propriedade ao usuário de serviço:

```bash
sudo mkdir -p /mnt/IA/modelos /mnt/IA/conversas
sudo chown -R ollama:ollama /mnt/IA/modelos
sudo chmod 755 /mnt/IA
sudo chmod 755 /mnt/IA/modelos
```

O diretório de conversas será preparado pelo próprio script para o usuário que o executa.

## 4. Configurar o Ollama para usar o dispositivo USB

Crie o diretório de configuração adicional:

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo nano /etc/systemd/system/ollama.service.d/storage.conf
```

Conteúdo:

```ini
[Unit]
RequiresMountsFor=/mnt/IA

[Service]
Environment="OLLAMA_MODELS=/mnt/IA/modelos"
```

Recarregue o systemd e reinicie o serviço:

```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
systemctl show ollama -p Environment --value
systemctl status ollama
```

Confirme que `OLLAMA_MODELS` aponta para `/mnt/IA/modelos`.

## 5. Instalar modelos de sua preferência

O projeto não obriga o uso de um modelo específico. Consulte a biblioteca do Ollama em https://ollama.com/library e escolha o modelo conforme a tarefa e os recursos do computador.

Exemplo de instalação:

```bash
ollama pull qwen3:1.7b
ollama list
```

Para instalar outro modelo, substitua o nome no comando:

```bash
ollama pull NOME_DO_MODELO
```

Para verificar informações de um modelo:

```bash
ollama show NOME_DO_MODELO
```

Aguarde o download terminar e confira se o modelo aparece em `ollama list`. O tamanho exibido na biblioteca é uma referência; o consumo real de RAM/VRAM também depende do contexto e da configuração.

## 6. Obter e configurar o script

Clone o repositório:

```bash
git clone https://github.com/Johnzitos/IA-Local-Ollama.git
cd IA-Local-Ollama
```

O script identifica o dispositivo correto pelo UUID. Obtenha o UUID da partição montada em `/mnt/IA`:

```bash
sudo blkid
```

Informe-o pela variável de ambiente `IA_UUID`, sem editar o arquivo do projeto:

```bash
export IA_UUID="UUID_DO_DISPOSITIVO"
```

Para que valha em todas as sessões, acrescente essa linha ao `~/.bashrc` (ou `~/.zshrc`, se você usa zsh). Sem `IA_UUID`, o script usa o valor `COLOQUE_O_UUID_DO_PENDRIVE` e recusa o dispositivo.

Valide a sintaxe e dê permissão de execução:

```bash
bash -n ia.sh
chmod +x ia.sh
```

## 7. Executar

Execute como usuário comum, sem `sudo`:

```bash
./ia.sh
```

O script verifica dependências, montagem, UUID, sistema de arquivos, configuração do Ollama e banco SQLite antes de apresentar o menu.

## 8. Observações

- O script de referência espera o ponto `/mnt/IA` configurado para montagem, por exemplo, via `/etc/fstab`.
- O serviço precisa estar configurado com `OLLAMA_MODELS=/mnt/IA/modelos`.
- O nome do usuário de serviço utilizado no exemplo é `ollama`; confirme no seu sistema.
- Não remova o dispositivo enquanto o serviço estiver usando seus arquivos. Use a opção de encerramento do menu e confirme que a desmontagem foi concluída.
