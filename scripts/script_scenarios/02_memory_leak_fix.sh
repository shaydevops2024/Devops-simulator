#!/usr/bin/env bash
set -euo pipefail

VERBOSE=0
STATE="/tmp/incidentops_memory_leak.pid"

log(){ echo "[$(date '+%F %T')] $*"; }
vlog(){ [[ "$VERBOSE" -eq 1 ]] && log "[VERBOSE] $*"; }

usage(){
  cat <<EOF
Usage: $0 [-v]
Stops the memory leak allocator.
Proof: shows 'free -m' and confirms process gone.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

log "[MEM_LEAK][FIX] Step 1: Reading PID from $STATE"
if [[ ! -f "$STATE" ]]; then
  log "[MEM_LEAK][FIX] No state file found. Nothing to stop."
  exit 0
fi

pid="$(cat "$STATE" || true)"
if [[ -z "$pid" ]]; then
  log "[MEM_LEAK][FIX] Empty PID. Cleaning state."
  rm -f "$STATE"
  exit 0
fi

log "[MEM_LEAK][FIX] Step 2: Stopping allocator PID=$pid"
if kill -0 "$pid" 2>/dev/null; then
  kill "$pid" 2>/dev/null || true
  sleep 1
  kill -9 "$pid" 2>/dev/null || true
else
  vlog "[MEM_LEAK][FIX] PID=$pid not running."
fi

log "[MEM_LEAK][FIX] Step 3: Cleanup state/log"
rm -f "$STATE" /tmp/incidentops_memleak_worker.py || true

log "[MEM_LEAK][FIX] Step 4: Waiting briefly for memory to normalize"
sleep 2

log "[MEM_LEAK][FIX] PROOF #1: free -m"
free -m || true

log "[MEM_LEAK][FIX] PROOF #2: allocator process should be gone"
ps -p "$pid" >/dev/null 2>&1 && log "[MEM_LEAK][FIX] WARNING: PID still exists!" || log "[MEM_LEAK][FIX] OK: PID not found"

log "[MEM_LEAK][FIX] DONE."
