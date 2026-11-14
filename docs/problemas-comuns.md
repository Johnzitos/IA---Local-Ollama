# Subproblemas que podem ser enfrentados

## 1. `umount: /mnt/IA: o alvo está ocupado`

Algum processo ainda está utilizando o ponto de montagem. Feche terminais e programas que estejam dentro de `/mnt/IA`. Se estiver no terminal, volte para sua pasta pessoal:

```bash
cd ~
sudo umount /mnt/IA
```

A função de encerramento do `ia.sh` também muda o diretório atual para `$HOME` antes de desmontar.

## 2. UUID ou sistema de arquivos não corresponde

Confira o dispositivo e o UUID:

```bash
lsblk -f
sudo blkid
findmnt /mnt/IA
```

Confira se a variável `IA_UUID` contém o UUID obtido com `blkid` (`echo "$IA_UUID"`) e revise a entrada de `/etc/fstab`. Não use UUID de outro dispositivo.

## 3. Ollama não utiliza o diretório externo

Verifique o drop-in e a variável:

```bash
sudo cat /etc/systemd/system/ollama.service.d/storage.conf
systemctl show ollama -p Environment --value
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

## 4. Permissão negada ao acessar modelos

Confira proprietário e permissões:

```bash
ls -ld /mnt/IA /mnt/IA/modelos
```

O diretório de modelos deve permitir acesso ao usuário de serviço `ollama`. Evite aplicar `chmod -R 777` como solução genérica.

## 5. Dependência não encontrada

O script verifica `ollama`, `sqlite3`, `jq` e `curl`. Instale os pacotes ausentes com `apt` e confirme com `command -v NOME`.

## 6. Falha de conexão ou download de modelo

Verifique a conexão com a internet, DNS, proxy e certificados TLS. Tente novamente mais tarde e consulte a documentação do Ollama. O uso das conversas locais não requer que a API de chat acesse a internet, mas a obtenção de modelos normalmente requer conexão.

## 7. Modelo lento ou não cabe na memória

Modelos maiores podem exceder a VRAM disponível e utilizar RAM, causando lentidão ou falha. Escolha um modelo menor ou uma variante quantizada compatível com o hardware.

## 8. Histórico não aparece

Confira se o dispositivo correto está montado e se o banco existe:

```bash
findmnt /mnt/IA
ls -lh /mnt/IA/conversas/historico.db
sqlite3 /mnt/IA/conversas/historico.db '.tables'
```

Faça cópias de segurança do banco antes de qualquer reparo.

## 9. O título da conversa não é gerado

O título é solicitado ao modelo quando a conversa é encerrada. Se aparecer a mensagem `Não foi possível gerar o título da conversa`:

- Confirme que o serviço está ativo: `systemctl is-active ollama`.
- Modelos da família Qwen3 "pensam" antes de responder. O script envia `think: false` para evitar que todo o limite de tokens seja gasto nesse raciocínio; esse parâmetro exige uma versão recente do Ollama. Atualize-o se o título continuar vazio (`ollama --version`).
- Se o modelo rejeitar o parâmetro, o script repete a requisição sem ele automaticamente.
- O título padrão é mantido e uma nova tentativa ocorre ao encerrar a conversa novamente. Para definir o nome manualmente, use **Histórico de conversas → Renomear conversa**.
