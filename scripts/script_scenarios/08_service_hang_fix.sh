#!/usr/bin/env bash
set -euo pipefail

VERBOSE=0
STATE="/tmp/incidentops_service_hang.pid"
PORT=8092

log(){ echo "[$(date '+%F %T')] $*"; }
vlog(){ [[ "$VERBOSE" -eq 1 ]] && log "[VERBOSE] $*"; }

usage(){
  cat <<EOF
Usage: $0 [-v] [--port N]
Resumes the hung demo server via SIGCONT.
Proof: curl works and process state is normal.

Requires: python3 (only to ensure server exists; fix is SIGCONT)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v) VERBOSE=1; shift ;;
    --port) PORT="${2:?}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

log "[HANG][FIX] Step 1: Reading PID from $STATE"
if [[ ! -f "$STATE" ]]; then
  log "[HANG][FIX] No state file found. Nothing to resume."
  exit 0
fi

pid="$(cat "$STATE" || true)"
if [[ -z "$pid" ]]; then
  log "[HANG][FIX] Empty PID; cleaning."
  rm -f "$STATE"
  exit 0
fi

log "[HANG][FIX] Step 2: Sending SIGCONT to PID=$pid"
if kill -0 "$pid" 2>/dev/null; then
  kill -CONT "$pid"
else
  log "[HANG][FIX] PID not running."
  rm -f "$STATE"
  exit 0
fi

log "[HANG][FIX] Step 3: PROOF #1: process state should no longer be 'T'"
ps -o pid,stat,comm,etime -p "$pid" || true

log "[HANG][FIX] Step 4: PROOF #2: curl should work now"
curl -sS --max-time 2 "http://127.0.0.1:${PORT}/" >/dev/null
log "[HANG][FIX] OK: curl succeeded"

log "[HANG][FIX] DONE."
