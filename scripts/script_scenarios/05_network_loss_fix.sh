#!/usr/bin/env bash
set -euo pipefail

VERBOSE=0
STATE="/tmp/incidentops_network_loss.rule"

log(){ echo "[$(date '+%F %T')] $*"; }
vlog(){ [[ "$VERBOSE" -eq 1 ]] && log "[VERBOSE] $*"; }

usage(){
  cat <<EOF
Usage: $0 [-v]
Removes the iptables DROP rule created by 05_network_loss_cause.sh
Proof: curl attempt (may still fail if service is actually down).

Requires: sudo, iptables
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

if ! command -v iptables >/dev/null 2>&1; then
  log "[NET_LOSS][FIX] ERROR: iptables not found."
  exit 1
fi

log "[NET_LOSS][FIX] Step 1: Reading rule state from $STATE"
if [[ ! -f "$STATE" ]]; then
  log "[NET_LOSS][FIX] No state file found. Nothing to remove."
  exit 0
fi

rule="$(cat "$STATE" || true)"
rm -f "$STATE" || true

if [[ -z "$rule" ]]; then
  log "[NET_LOSS][FIX] Empty rule state. Done."
  exit 0
fi

log "[NET_LOSS][FIX] Step 2: Removing rule (requires sudo): iptables -D $rule"
sudo iptables -D $rule 2>/dev/null || true

log "[NET_LOSS][FIX] Step 3: Showing OUTPUT chain (sanity)"
sudo iptables -S OUTPUT | head -n 30 || true

# Attempt proof if we can parse host/port from rule:
host="$(echo "$rule" | awk '{for(i=1;i<=NF;i++) if($i=="-d") print $(i+1)}')"
port="$(echo "$rule" | awk '{for(i=1;i<=NF;i++) if($i=="--dport") print $(i+1)}')"

if [[ -n "$host" && -n "$port" ]]; then
  log "[NET_LOSS][FIX] PROOF: curl now should no longer be blocked (success depends on service)"
  curl -sS --max-time 3 "http://${host}:${port}/" >/dev/null && \
    log "[NET_LOSS][FIX] curl succeeded (or at least not blocked)" || \
    log "[NET_LOSS][FIX] curl failed (service may be down, but rule is removed)"
fi

log "[NET_LOSS][FIX] DONE."
