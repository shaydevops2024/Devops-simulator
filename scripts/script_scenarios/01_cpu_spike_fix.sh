#!/usr/bin/env bash
set -euo pipefail

VERBOSE=0
STATE="/tmp/incidentops_cpu_spike.pids"

log(){ echo "[$(date '+%F %T')] $*"; }
vlog(){ [[ "$VERBOSE" -eq 1 ]] && log "[VERBOSE] $*"; }

usage(){
  cat <<EOF
Usage: $0 [-v]
Stops CPU burners created by 01_cpu_spike_cause.sh
Proof: shows 'top' snapshot.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

log "[CPU_SPIKE][FIX] Step 1: Reading state from $STATE"
if [[ ! -f "$STATE" ]]; then
  log "[CPU_SPIKE][FIX] No state file found. Nothing to stop."
  exit 0
fi

pids=$(cat "$STATE" || true)
if [[ -z "${pids// }" ]]; then
  log "[CPU_SPIKE][FIX] State file empty. Nothing to stop."
  rm -f "$STATE"
  exit 0
fi

log "[CPU_SPIKE][FIX] Step 2: Killing burner PIDs"
for pid in $pids; do
  if kill -0 "$pid" 2>/dev/null; then
    vlog "[CPU_SPIKE][FIX] Killing PID=$pid"
    kill "$pid" 2>/dev/null || true
  else
    vlog "[CPU_SPIKE][FIX] PID=$pid not running"
  fi
done

log "[CPU_SPIKE][FIX] Step 3: Cleanup state file"
rm -f "$STATE"

log "[CPU_SPIKE][FIX] Step 4: Waiting briefly for CPU to normalize"
sleep 2

log "[CPU_SPIKE][FIX] PROOF: top snapshot (first ~20 lines)"
top -b -n 1 | head -n 20 || true

log "[CPU_SPIKE][FIX] DONE."
