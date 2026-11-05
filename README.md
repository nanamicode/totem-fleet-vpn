# totem-fleet-vpn

Rede privada (estilo Tailscale) para acessar centenas de totens via SSH e ADB
fora da rede wifi local, sem custo de licenciamento, usando [Headscale](https://github.com/juanfont/headscale)
(implementação open-source e compatível do servidor de controle do Tailscale)
rodando em um servidor próprio.

## Objetivo

- SSH e `adb root` em cada totem, de qualquer lugar, sem depender da rede wifi local.
- Zero custo de licença: Headscale é open-source; o único custo é o servidor de controle.
- Escala para centenas de dispositivos sem limite artificial de contas gratuitas.

## Arquitetura

```
                     ┌─────────────────────────┐
                     │  Servidor de controle    │
                     │  (Headscale + DERP)      │
                     │  precisa de IP público    │
                     └────────────┬─────────────┘
                                   │ coordenação (HTTPS)
          ┌────────────────────────┼────────────────────────┐
          │                        │                         │
   ┌──────┴──────┐          ┌──────┴──────┐           ┌──────┴──────┐
   │  Seu PC      │          │  Totem #1    │   ...     │  Totem #N    │
   │  (tailscale) │◄────────►│ (tailscale) │◄─────────►│ (tailscale) │
   └─────────────┘  P2P/DERP └─────────────┘           └─────────────┘
```

- Conexões diretas (P2P) quando o NAT de cada rede permite.
- Quando não permite, o tráfego passa por um relay DERP (o do Headscale, ou,
  em fallback, os relays públicos e gratuitos da própria Tailscale).
- O servidor de controle **precisa de IP público** para que os totens o
  encontrem de fora das redes onde estão. Ver [docs/ARQUITETURA.md](docs/ARQUITETURA.md).

## Status atual

- [x] Definição da arquitetura.
- [x] Acesso SSH por chave a uma máquina de desenvolvimento local (notebook Linux Mint).
- [ ] Servidor de controle com endereço público: **auto-hospedado no seu
      próprio IP público, zero conta de terceiro** (decidido — ver
      [docs/DECISOES.md](docs/DECISOES.md)). IP público testado
      (`177.221.137.121`) não está em faixa de CGNAT — bom indício, a
      confirmar. Falta só o operador abrir 3 portas no roteador — passo a
      passo em [docs/RUNBOOK.md](docs/RUNBOOK.md). ngrok/Cloudflare ficam
      como plano B se o provedor fizer CGNAT de outra forma.
- [x] Script de checagem de IP público ([scripts/check-public-ip.sh](scripts/check-public-ip.sh)).
- [x] Headscale: docker-compose + config de exemplo em [headscale/](headscale/).
- [x] Script de provisionamento para totens Android ([scripts/provision-totem-android.sh](scripts/provision-totem-android.sh)).
- [x] Script de provisionamento para hosts Linux ([scripts/provision-linux.sh](scripts/provision-linux.sh)).
- [x] Script de provisionamento em lote a partir de inventário CSV ([scripts/provision-batch.sh](scripts/provision-batch.sh)).
- [x] ACL de exemplo restringindo quem acessa cada totem ([headscale/config/acl.hujson.example](headscale/config/acl.hujson.example)).
- [ ] Teste de ponta a ponta: SSH e `adb root` em um totem real, fora da rede local.

## Estrutura

```
headscale/    docker-compose + config de exemplo do servidor de controle
scripts/      scripts de provisionamento (totem Android, host Linux)
docs/         arquitetura, decisões e runbook operacional
```

## Segurança

- Nenhuma senha, chave privada ou token vai para este repositório. Chaves de
  pré-autenticação do Headscale são geradas por dispositivo/lote e expiram.
- ACLs do Headscale restringem o tráfego: só o operador alcança os totens;
  totens não se alcançam entre si.
- ADB fica acessível **apenas pela interface da VPN**, nunca pela rede local
  ou pela internet aberta.
