#!/usr/bin/env bash
# Provisiona em lote todos os totens listados em um inventário CSV,
# enquanto eles ainda estão alcançáveis pela rede local (antes de entrarem
# na VPN). Depois disso, o acesso passa a ser pelo Headscale.
#
# Formato do CSV (ver docs/inventario.csv.example):
#   hostname,plataforma,arquitetura,ip_local_atual,local_fisico,observacoes
#
# Uso:
#   LOGIN_SERVER=https://hs.seudominio.com \
#   AUTH_KEY=<chave-de-pre-autenticacao-dos-totens> \
#   ./provision-batch.sh docs/inventario.csv
#
# Requisitos por linha:
#   - plataforma=android: binários tailscale/tailscaled arm64 ou armv7 em
#     scripts/bin/<arquitetura>/, acessíveis via `adb push`, e root (su) no
#     aparelho.
#   - plataforma=linux: SSH por chave já configurado (ver docs/RUNBOOK.md).

set -euo pipefail

: "${LOGIN_SERVER:?defina LOGIN_SERVER (URL do Headscale)}"
: "${AUTH_KEY:?defina AUTH_KEY (chave de pré-autenticação dos totens)}"

CSV="${1:?uso: ./provision-batch.sh caminho/para/inventario.csv}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FAILED=()

provision_android() {
  local hostname="$1" arch="$2" ip="$3"
  local bin_dir="$SCRIPT_DIR/bin/$arch"

  if [ ! -x "$bin_dir/tailscale" ] || [ ! -x "$bin_dir/tailscaled" ]; then
    echo "[$hostname] binários ausentes em $bin_dir — pulando" >&2
    return 1
  fi

  adb connect "$ip:5555" >/dev/null
  adb -s "$ip:5555" root >/dev/null 2>&1 || true
  adb -s "$ip:5555" shell mkdir -p /data/tailscale
  adb -s "$ip:5555" push "$bin_dir/tailscale" /data/tailscale/tailscale
  adb -s "$ip:5555" push "$bin_dir/tailscaled" /data/tailscale/tailscaled
  adb -s "$ip:5555" push "$SCRIPT_DIR/provision-totem-android.sh" /data/tailscale/provision.sh
  adb -s "$ip:5555" shell chmod 755 /data/tailscale/tailscale /data/tailscale/tailscaled /data/tailscale/provision.sh
  adb -s "$ip:5555" shell "su -c 'LOGIN_SERVER=$LOGIN_SERVER AUTH_KEY=$AUTH_KEY HOSTNAME=$hostname sh /data/tailscale/provision.sh'"
}

provision_linux() {
  local hostname="$1" ip="$2"

  scp -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
    "$SCRIPT_DIR/provision-linux.sh" "vinicius@$ip:/tmp/provision-linux.sh"
  ssh -o BatchMode=yes "vinicius@$ip" \
    "LOGIN_SERVER=$LOGIN_SERVER AUTH_KEY=$AUTH_KEY HOSTNAME=$hostname sudo -E bash /tmp/provision-linux.sh"
}

# process substitution (não pipe) para que FAILED sobreviva fora do loop
while IFS=, read -r hostname plataforma arquitetura ip local obs; do
  [ -z "$hostname" ] && continue
  echo "== Provisionando $hostname ($plataforma/$arquitetura) em $ip =="

  case "$plataforma" in
    android)
      if ! provision_android "$hostname" "$arquitetura" "$ip"; then
        FAILED+=("$hostname")
      fi
      ;;
    linux)
      if ! provision_linux "$hostname" "$ip"; then
        FAILED+=("$hostname")
      fi
      ;;
    *)
      echo "[$hostname] plataforma desconhecida: $plataforma" >&2
      FAILED+=("$hostname")
      ;;
  esac
done < <(tail -n +2 "$CSV")

if [ "${#FAILED[@]}" -gt 0 ]; then
  echo "Falharam: ${FAILED[*]}" >&2
  exit 1
fi

echo "Lote concluído sem falhas."
