#!/usr/bin/env bash
# Provisiona o Tailscale (apontando para nosso Headscale) em uma máquina
# Linux (operador ou totem baseado em Linux), como serviço systemd.
#
# Uso:
#   LOGIN_SERVER=https://hs.seudominio.com \
#   AUTH_KEY=<chave-de-pre-autenticacao> \
#   HOSTNAME=totem-0001 \
#   sudo -E ./provision-linux.sh

set -euo pipefail

: "${LOGIN_SERVER:?defina LOGIN_SERVER (URL do Headscale)}"
: "${AUTH_KEY:?defina AUTH_KEY (chave de pré-autenticação)}"
: "${HOSTNAME:?defina HOSTNAME (nome único desta máquina)}"

if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi

systemctl enable --now tailscaled

tailscale up \
  --login-server="$LOGIN_SERVER" \
  --authkey="$AUTH_KEY" \
  --hostname="$HOSTNAME" \
  --advertise-tags=tag:totem \
  --ssh=false \
  --accept-dns=true

echo "Provisionado: $HOSTNAME via $LOGIN_SERVER"
tailscale status
