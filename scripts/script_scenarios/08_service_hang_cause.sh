#!/usr/bin/env bash
set -euo pipefail

VERBOSE=0
PORT=8092
STATE="/tmp/incidentops_service_hang.pid"

log(){ echo "[$(date '+%F %T')] $*"; }
vlog(){ [[ "$VERBOSE" -eq 1 ]] && log "[VERBOSE] $*"; }

usage(){
  cat <<EOF
Usage: $0 [-v] [--port N]
Starts a demo HTTP server and then SIGSTOPs it (hang).
Proof: process state shows 'T' and curl times out.

Requires: python3
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

if ! command -v python3 >/dev/null 2>&1; then
  log "[HANG][CAUSE] ERROR: python3 required."
  exit 1
fi

log "[HANG][CAUSE] Step 1: Starting demo server on port $PORT"
python3 -m http.server "$PORT" >/dev/null 2>&1 &
pid=$!
echo "$pid" > "$STATE"
vlog "[HANG][CAUSE] Server PID=$pid"

log "[HANG][CAUSE] Step 2: Baseline PROOF: curl should work"
curl -sS --max-time 2 "http://127.0.0.1:${PORT}/" >/dev/null
log "[HANG][CAUSE] Baseline OK"

log "[HANG][CAUSE] Step 3: Sending SIGSTOP (hang the process)"
kill -STOP "$pid"

log "[HANG][CAUSE] Step 4: PROOF #1: process state should include 'T' (stopped)"
ps -o pid,stat,comm,etime -p "$pid" || true

log "[HANG][CAUSE] PROOF #2: curl should timeout/fail"
curl -sS --max-time 2 "http://127.0.0.1:${PORT}/" >/dev/null && \
  log "[HANG][CAUSE] WARNING: curl succeeded unexpectedly" || \
  log "[HANG][CAUSE] OK: curl failed (expected for hung process)"

log "[HANG][CAUSE] DONE. Fix with: 08_service_hang_fix.sh"
