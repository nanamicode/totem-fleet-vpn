# Registro de decisões

Formato: data, decisão, motivo. Mantém o histórico de por que escolhemos
cada caminho, para não re-discutir do zero depois.

## 2026-11-05 — Servidor de controle, revisão: zero conta de terceiro

**Status: decidido — auto-hospedado, usando o próprio IP público da rede do
operador. Substitui a decisão de ngrok abaixo.**

O operador pediu para não depender de nenhum software pago externo nem de
ações recorrentes dele. Testamos o IP público visto pela rede de casa
(`177.221.137.121`) e ele **não está na faixa reservada para CGNAT**
(`100.64.0.0/10`), o que é um bom indício de que é um IP público de verdade,
não compartilhado por NAT em massa do provedor. Isso abre a possibilidade de
auto-hospedar o Headscale direto nessa rede, sem ngrok, Cloudflare ou VPS de
terceiro algum.

Solução adotada:
- Headscale + Caddy rodando na própria máquina da rede do operador.
- Hostname via **sslip.io** (serviço público gratuito e sem conta: resolve
  `<ip-com-hifens>.sslip.io` para o próprio IP automaticamente). O Caddy usa
  esse hostname para emitir certificado HTTPS válido (Let's Encrypt) sem
  precisar de domínio próprio.
- `scripts/check-public-ip.sh` monitora se o IP de casa mudou (IPs
  residenciais no Brasil costumam ser razoavelmente estáveis, mas não fixos).

Única ação que continua sendo do operador, e que o assistente não faz por
regra própria (não loga em painéis de roteador nem altera configurações de
rede/segurança de terceiros): abrir o encaminhamento de portas
(80/tcp, 443/tcp, 3478/udp) para o IP local da máquina, no painel do
roteador. Isso não é criação de conta nem depende de nenhum serviço externo
— é uma configuração local, de 2 minutos, feita uma única vez.

Ressalva: a ausência do IP na faixa de CGNAT é um indício forte, não uma
prova definitiva — alguns provedores fazem NAT em massa fora dessa faixa
reservada. A confirmação real só vem ao testar, depois do encaminhamento de
porta, se o Headscale fica alcançável de fora (ex.: via canyouseeme.org). Se
não ficar, caímos de volta nas opções com túnel (ngrok/Cloudflare) já
documentadas abaixo.

## 2026-10-23 — Servidor de controle (decisão anterior, mantida como plano B)

**Status: superada pela decisão acima; mantida como alternativa caso o
encaminhamento de porta não funcione (IP realmente atrás de CGNAT).**

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
