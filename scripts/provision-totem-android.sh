#!/system/bin/sh
# Provisiona o Tailscale (apontando para nosso Headscale) em um totem Android
# com root. Roda DENTRO do totem (via `adb shell` ou terminal local).
#
# Uso:
#   LOGIN_SERVER=https://hs.seudominio.com \
#   AUTH_KEY=<chave-de-pre-autenticacao> \
#   HOSTNAME=totem-0001 \
#   sh provision-totem-android.sh
#
# Pré-requisitos:
#   - Binário tailscaled/tailscale arm64 (ou armv7) estático, copiado
#     previamente para /data/tailscale/ no totem.
#   - Root (su) disponível.

set -eu

: "${LOGIN_SERVER:?defina LOGIN_SERVER (URL do Headscale)}"
: "${AUTH_KEY:?defina AUTH_KEY (chave de pré-autenticação, gerada por lote/tag)}"
: "${HOSTNAME:?defina HOSTNAME (nome único deste totem, ex.: totem-0001)}"

BIN_DIR=/data/tailscale
STATE_DIR=/data/tailscale/state

mkdir -p "$STATE_DIR"

# Mata uma instância anterior, se houver, antes de reconfigurar.
pkill -f tailscaled 2>/dev/null || true

# tun real se o kernel tiver o módulo; caso contrário, modo userspace.
if [ -e /dev/net/tun ]; then
  TUN_MODE=""
else
  TUN_MODE="--tun=userspace-networking"
fi

"$BIN_DIR/tailscaled" --state="$STATE_DIR/tailscaled.state" $TUN_MODE &
sleep 2

"$BIN_DIR/tailscale" up \
  --login-server="$LOGIN_SERVER" \
  --authkey="$AUTH_KEY" \
  --hostname="$HOSTNAME" \
  --advertise-tags=tag:totem \
  --ssh=false \
  --accept-dns=true

# ADB acessível só pela interface do Tailscale, nunca pela rede local/wifi aberta.
setprop service.adb.tcp.port 5555
stop adbd
start adbd

echo "Provisionado: $HOSTNAME via $LOGIN_SERVER"
"$BIN_DIR/tailscale" status
