# Runbook de setup

Passo a passo operacional. Siga a seção correspondente à opção de hospedagem
escolhida (ver [DECISOES.md](DECISOES.md)).

## 1. Servidor de controle

### Opção escolhida — auto-hospedado no seu próprio IP público (zero conta de terceiro)

Sem ngrok, Cloudflare, VPS ou qualquer serviço de terceiro. Ver a decisão e
o porquê em [DECISOES.md](DECISOES.md).

1. Rode `scripts/check-public-ip.sh` para descobrir seu IP público atual e o
   hostname sslip.io correspondente (ex.: `177-221-137-121.sslip.io`).
2. **(Único passo manual, feito pelo operador — eu não altero configurações
   de roteador)** No painel de administração do seu roteador (geralmente
   `192.168.1.1`), configure o encaminhamento de portas (port forwarding):
   - `80/tcp` → IP local da máquina que vai rodar o Headscale
   - `443/tcp` → mesmo IP
   - `3478/udp` → mesmo IP
3. Confirme que funcionou com um checador externo, ex. https://canyouseeme.org
   testando a porta 443 — **se a porta não aparecer aberta, seu provedor
   provavelmente faz CGNAT** e esse caminho não é viável; use a Opção
   alternativa C (ngrok) ou B (Cloudflare Tunnel) abaixo.
4. Copie `headscale/Caddyfile.example` para `Caddyfile` e
   `headscale/config/config.yaml.example` para `config.yaml`, ajustando o
   hostname sslip.io do passo 1 nos dois.
5. `docker compose up -d` (ver seção 2, igual às outras opções).
6. Agende `scripts/check-public-ip.sh --cron` (cron/Agendador de Tarefas,
   1x por dia) para avisar se o IP de casa mudar — nesse caso, repita os
   passos 1 e 4 com o novo IP.

#### IP dinâmico — quando vale migrar para DDNS

Se o IP mudar com frequência (verifique por algumas semanas com o script do
passo 6), a manutenção manual fica chata. Nesse caso, a melhora natural é um
DDNS gratuito (ex.: DuckDNS) — ainda sem custo, mas exige criar uma conta
leve (só e-mail, sem cartão), igual ao ngrok abaixo. É uma escolha sua,
avaliada só se o cenário acima se mostrar instável na prática.

### Opção alternativa C — ngrok, domínio estático gratuito

Menor atrito: não exige cartão de crédito nem domínio próprio.

1. **(Único passo manual, feito pelo operador)** Crie a conta gratuita em
   https://ngrok.com (só e-mail, sem cartão).
2. No painel, vá em **Universal Gateway → Domains** e reserve um domínio
   estático gratuito (ex.: `totem-fleet-abc123.ngrok-free.app`).
3. Copie o **authtoken** em https://dashboard.ngrok.com/get-started/your-authtoken.
4. Passe o authtoken e o domínio reservado para o assistente — o resto
   (passos 5 a 8 abaixo) é configurado automaticamente a partir daqui.
5. Na máquina que vai rodar o Headscale (ex.: o notebook Linux Mint já com
   acesso configurado):
   ```bash
   curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
   echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
   sudo apt update && sudo apt install ngrok
   ngrok config add-authtoken <AUTHTOKEN>
   ```
6. Configure `~/.config/ngrok/ngrok.yml`:
   ```yaml
   version: "3"
   agent:
     authtoken: <AUTHTOKEN>
   endpoints:
     - name: headscale
       url: https://<seu-dominio>.ngrok-free.app
       upstream:
         url: 8080
   ```
7. Suba como serviço (systemd):
   ```bash
   sudo tee /etc/systemd/system/ngrok.service >/dev/null <<'EOF'
   [Unit]
   Description=ngrok tunnel (Headscale)
   After=network.target

   [Service]
   User=vinicius
   ExecStart=/usr/local/bin/ngrok start --all --config /home/vinicius/.config/ngrok/ngrok.yml
   Restart=always

   [Install]
   WantedBy=multi-user.target
   EOF
   sudo systemctl enable --now ngrok
   ```
8. Igual ao Cloudflare Tunnel: **não** precisa do serviço `caddy` do
   `docker-compose.yml` (o ngrok já termina o HTTPS) — rode só o serviço
   `headscale`, com `server_url: https://<seu-dominio>.ngrok-free.app` e
   `listen_addr: 0.0.0.0:8080` no `config.yaml`.

### Opção alternativa A — VPS gratuito (Oracle Cloud Free Tier)

1. Crie a conta em https://www.oracle.com/cloud/free/ (feito pelo operador;
   exige cartão só para verificação, não cobra no tier Always Free).
2. Crie uma instância **Ampere A1 (ARM), Always Free**, Ubuntu 24.04, com
   IP público fixo (reserve um "Reserved Public IP" para ele não mudar).
3. Libere as portas no painel de rede da Oracle (Security List / NSG):
   - TCP 443 (coordenação HTTPS)
   - TCP 80 (emissão do certificado Let's Encrypt)
   - UDP 3478 (STUN/DERP)
4. Aponte um domínio/subdomínio seu para esse IP público (registro A).
5. Siga a seção 2 (Headscale) usando esse IP/domínio.

### Opção alternativa B — Cloudflare Tunnel (sem IP público, exige domínio próprio)

1. Crie a conta Cloudflare e adicione seu domínio a ela (feito pelo
   operador).
2. Instale o `cloudflared` na máquina que vai rodar o Headscale
   (ex.: o notebook Linux Mint já com acesso SSH configurado):
   ```bash
   curl -L https://pkg.cloudflare.com/cloudflared-stable-linux-amd64.deb -o cloudflared.deb
   sudo dpkg -i cloudflared.deb
   cloudflared tunnel login
   cloudflared tunnel create totem-fleet
   ```
3. Crie o registro DNS do túnel:
   ```bash
   cloudflared tunnel route dns totem-fleet hs.seudominio.com
   ```
4. Configure `~/.cloudflared/config.yml`:
   ```yaml
   tunnel: <ID-do-tunnel>
   credentials-file: /home/vinicius/.cloudflared/<ID-do-tunnel>.json
   ingress:
     - hostname: hs.seudominio.com
       service: http://localhost:8080
     - service: http_status:404
   ```
5. Suba como serviço: `sudo cloudflared service install`.
6. Nesse caso, **não** precisa do Caddy do `docker-compose.yml` (o Cloudflare
   já termina o HTTPS) — rode só o serviço `headscale`, apontando
   `server_url` para `https://hs.seudominio.com` e `listen_addr` para
   `0.0.0.0:8080`.
7. DERP embutido fica inacessível de fora (o túnel só carrega HTTP/S); os
   clientes usam os relays públicos da Tailscale como fallback — já
   configurado em `derp.urls` no `config.yaml.example`.

## 2. Headscale

1. No host escolhido:
   ```bash
   git clone https://github.com/nanamicode/totem-fleet-vpn.git
   cd totem-fleet-vpn/headscale
   cp config/config.yaml.example config/config.yaml   # edite server_url
   cp config/acl.hujson.example config/acl.hujson      # edite seu usuário
   cp Caddyfile.example Caddyfile                      # só na Opção A; edite o domínio
   docker compose up -d
   ```
2. Crie o usuário e a chave de pré-autenticação reutilizável para os totens:
   ```bash
   docker compose exec headscale headscale users create totens
   docker compose exec headscale headscale preauthkeys create \
     --user totens --reusable --expiration 365d --tags tag:totem
   ```
3. Guarde essa chave fora do repositório (ex.: gerenciador de senhas, ou um
   `.env` local, nunca commitado — já está no `.gitignore`).
4. Registre seu próprio usuário/dispositivo (operador):
   ```bash
   docker compose exec headscale headscale users create operador
   docker compose exec headscale headscale preauthkeys create --user operador --expiration 1h
   ```
   Use essa chave de uso único para conectar seu próprio PC
   (`tailscale up --login-server=... --authkey=...`).

## 3. Provisionar um totem

Ver [scripts/provision-totem-android.sh](../scripts/provision-totem-android.sh)
(Android) ou [scripts/provision-linux.sh](../scripts/provision-linux.sh)
(Linux), e [scripts/provision-batch.sh](../scripts/provision-batch.sh) para
lotes a partir de [docs/inventario.csv.example](inventario.csv.example).

## 4. Verificação de ponta a ponta

1. Fora da rede wifi local (ex.: 4G do celular, ou rede de outro lugar):
   ```bash
   ssh usuario@totem-0001
   adb connect totem-0001:5555 && adb root
   ```
2. Confirme no Headscale que o tráfego de outro totem para este é recusado
   (ACL funcionando): tente `ssh totem-0002` a partir de dentro do
   `totem-0001` — deve falhar.
