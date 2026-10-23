# Registro de decisões

Formato: data, decisão, motivo. Mantém o histórico de por que escolhemos
cada caminho, para não re-discutir do zero depois.

## 2026-10-23 — Servidor de controle

**Status: pendente.**

Tentativa inicial: usar uma máquina na rede local do operador (`192.168.1.228`)
como "VPS". Descartada — IP privado não é alcançável da internet; não
atende ao objetivo de acesso fora da rede wifi local.

Opções em avaliação:
- VPS gratuito real (Oracle Cloud Free Tier) — recomendado, mais robusto.
- Cloudflare Tunnel saindo de uma máquina local — viável, mas depende de um
  domínio e não tuneliza DERP (usaria os relays públicos da Tailscale como
  fallback).

Próximo passo: operador decide e cria a conta necessária (VPS ou Cloudflare).
