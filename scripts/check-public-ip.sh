#!/usr/bin/env bash
# Verifica o IP público atual da rede e, se mudou desde a última checagem,
# avisa (não existe conta/serviço de terceiro envolvido: só consulta um
# serviço público de "qual é meu IP" e compara com o valor salvo localmente).
#
# Uso:
#   ./check-public-ip.sh                 # mostra o IP atual e o hostname sslip.io
#   ./check-public-ip.sh --cron          # roda silencioso, só avisa se mudou
#                                          (agende no cron/Agendador de Tarefas)
#
# Se o IP mudou, o hostname sslip.io muda também — é preciso:
#   1. atualizar server_url no config.yaml do Headscale e reiniciar;
#   2. atualizar o Caddyfile com o novo hostname;
#   3. os totens continuam funcionando com o IP antigo até você rodar de novo
#      `tailscale up --login-server=<novo-hostname>` neles (ou, mais simples,
#      migrar para DDNS — ver docs/RUNBOOK.md, seção "IP dinâmico").

set -euo pipefail

STATE_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.last-public-ip"
CRON_MODE=false
[ "${1:-}" = "--cron" ] && CRON_MODE=true

CURRENT_IP="$(curl -s -4 --max-time 10 https://ifconfig.me)"
if [ -z "$CURRENT_IP" ]; then
  echo "Não consegui determinar o IP público agora (sem internet ou serviço fora)." >&2
  exit 1
fi

SSLIP_HOST="$(echo "$CURRENT_IP" | tr '.' '-').sslip.io"

if [ -f "$STATE_FILE" ]; then
  LAST_IP="$(cat "$STATE_FILE")"
else
  LAST_IP=""
fi

if [ "$CURRENT_IP" != "$LAST_IP" ]; then
  echo "$CURRENT_IP" > "$STATE_FILE"
  if [ -n "$LAST_IP" ]; then
    echo "AVISO: IP público mudou de $LAST_IP para $CURRENT_IP."
    echo "Novo hostname: https://$SSLIP_HOST"
    echo "Atualize server_url no config.yaml e o Caddyfile, depois:"
    echo "  docker compose -f headscale/docker-compose.yml restart"
  else
    echo "IP público atual: $CURRENT_IP"
    echo "Hostname sslip.io correspondente: $SSLIP_HOST"
  fi
elif [ "$CRON_MODE" = false ]; then
  echo "IP público sem alteração: $CURRENT_IP ($SSLIP_HOST)"
fi
