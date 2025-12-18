#!/usr/bin/env bash
set -euo pipefail

VERBOSE=0
HOST="127.0.0.1"
PORT="8000"
STATE="/tmp/incidentops_network_loss.rule"

log(){ echo "[$(date '+%F %T')] $*"; }
vlog(){ [[ "$VERBOSE" -eq 1 ]] && log "[VERBOSE] $*"; }

usage(){
  cat <<EOF
Usage: $0 [-v] [--host HOST] [--port PORT]
Blocks outbound traffic to HOST:PORT using iptables OUTPUT DROP rule.
Proof: curl to HOST:PORT fails.

Requires: sudo, iptables
Defaults: host=127.0.0.1 port=8000
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v) VERBOSE=1; shift ;;
    --host) HOST="${2:?}"; shift 2 ;;
    --port) PORT="${2:?}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

if ! command -v iptables >/dev/null 2>&1; then
  log "[NET_LOSS][CAUSE] ERROR: iptables not found."
  exit 1
fi

log "[NET_LOSS][CAUSE] Step 1: Adding iptables OUTPUT DROP for ${HOST}:${PORT} (requires sudo)"
# Save enough info for removal:
echo "OUTPUT -p tcp -d ${HOST} --dport ${PORT} -j DROP" > "$STATE"

sudo iptables -I OUTPUT -p tcp -d "$HOST" --dport "$PORT" -j DROP

log "[NET_LOSS][CAUSE] Step 2: Showing matching rules"
sudo iptables -S OUTPUT | grep -n " -p tcp -d ${HOST} .* --dport ${PORT} .* -j DROP" || true

log "[NET_LOSS][CAUSE] PROOF: curl should fail or timeout"
curl -sS --max-time 3 "http://${HOST}:${PORT}/" >/dev/null && \
  log "[NET_LOSS][CAUSE] WARNING: curl succeeded (service may not be HTTP or rule not applied)" || \
  log "[NET_LOSS][CAUSE] OK: curl failed as expected"

log "[NET_LOSS][CAUSE] DONE. Fix with: 05_network_loss_fix.sh"
