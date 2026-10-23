# Arquitetura

## Por que Headscale e não Tailscale puro

O Tailscale gratuito tem limite de contas/dispositivos pensado para uso
pessoal. Para centenas de totens, precisamos de um servidor de controle sem
esse limite. O Headscale é a implementação open-source e compatível do
protocolo do Tailscale: os mesmos clientes oficiais funcionam, mudando apenas
o `--login-server` para apontar para o nosso servidor.

## Por que o servidor de controle precisa de IP público

O servidor de controle (Headscale) é o ponto que:
1. Autentica cada dispositivo (chave de pré-autenticação).
2. Coordena quem são os outros dispositivos da rede e como alcançá-los.
3. Opcionalmente, retransmite tráfego (DERP) quando a conexão direta P2P não
   é possível entre dois dispositivos (ex.: ambos atrás de NAT simétrico).

Para um totem que está em uma rede 4G/wifi qualquer, fora de casa, alcançar
esse servidor, o servidor precisa ter um endereço que a internet pública
consiga rotear — ou seja, um IP público (direto, ou via túnel que expõe um
IP público de um terceiro, como Cloudflare Tunnel).

Uma máquina com IP privado (faixa `192.168.x.x`, `10.x.x.x`) atrás de um
roteador doméstico **não é alcançável** da internet, a menos que:
- o roteador tenha IP público próprio (não é CGNAT) e faça port forwarding
  das portas necessárias para essa máquina; ou
- a máquina abra uma conexão de saída para um serviço de túnel (Cloudflare
  Tunnel, ngrok, etc.) que então expõe um endereço público que redireciona
  pra ela.

## Opções avaliadas para o servidor de controle

| Opção | Custo | IP público | Observação |
|---|---|---|---|
| VPS cloud (Oracle Cloud Free Tier, etc.) | Grátis (tier free) | Sim, nativo | Mais robusto; exige criar conta (cartão só p/ verificação) |
| Máquina local + Cloudflare Tunnel | Grátis | Via túnel | Precisa de domínio + conta Cloudflare |
| Máquina local + port forwarding | Grátis | Só se o link não tiver CGNAT | Não se aplica aqui (sem IP público disponível) |

Decisão registrada em [DECISOES.md](DECISOES.md).

## Componentes

- **Headscale**: servidor de controle, roda em Docker no servidor escolhido.
- **DERP embutido**: relay de fallback, hospedado junto com o Headscale
  (ou, na ausência dele, os relays públicos gratuitos da Tailscale).
- **Cliente Tailscale** em cada totem e em cada máquina do operador.
- **ACLs** no Headscale: o operador alcança todos os totens; totens não se
  alcançam entre si nem alcançam o operador.

## Fluxo de acesso a um totem

1. Totem conecta ao Headscale (`tailscale up --login-server=... --authkey=...`).
2. Operador já está conectado à mesma rede Headscale.
3. MagicDNS dá um nome estável ao totem (ex.: `totem-0001`).
4. SSH: `ssh usuario@totem-0001` (chave pública já provisionada no totem).
5. ADB: `adb connect totem-0001:5555` (porta 5555 aberta só na interface da
   VPN) e depois `adb root` (requer build userdebug/eng ou root via Magisk).
