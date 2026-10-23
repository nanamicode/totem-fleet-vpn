# Runbook de setup

Passo a passo operacional. Siga a seção correspondente à opção de hospedagem
escolhida (ver [DECISOES.md](DECISOES.md)).

## 1. Servidor de controle

### Opção A — VPS gratuito (Oracle Cloud Free Tier)

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

### Opção B — Cloudflare Tunnel (sem IP público)

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
