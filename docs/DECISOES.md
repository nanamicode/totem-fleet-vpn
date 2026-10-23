# Registro de decisões

Formato: data, decisão, motivo. Mantém o histórico de por que escolhemos
cada caminho, para não re-discutir do zero depois.

## 2026-10-23 — Servidor de controle

**Status: decidido — ngrok (domínio estático gratuito), aguardando o único
passo manual do operador (criar a conta e gerar o authtoken).**

Tentativa inicial: usar uma máquina na rede local do operador (`192.168.1.228`)
como "VPS". Descartada — IP privado não é alcançável da internet; não
atende ao objetivo de acesso fora da rede wifi local.

Opções avaliadas:
- VPS gratuito real (Oracle Cloud Free Tier) — mais robusto, mas exige conta
  com verificação de cartão de crédito (mais atrito).
- Cloudflare Tunnel saindo de uma máquina local — exige que o operador já
  tenha (ou compre) um domínio próprio.
- **ngrok, domínio estático gratuito, saindo de uma máquina local —
  escolhido.** Único atrito: conta gratuita (só e-mail, sem cartão) e gerar
  um authtoken + reservar o domínio estático no painel. Todo o resto do
  setup (Headscale, ngrok como serviço, ACLs) é feito pelo assistente.

Trade-off aceito: assim como no Cloudflare Tunnel, o DERP embutido do
Headscale fica inacessível de fora (o túnel só carrega HTTP/S); os clientes
usam os relays públicos e gratuitos da própria Tailscale como fallback de
retransmissão — já configurado em `derp.urls` no `config.yaml.example`.
