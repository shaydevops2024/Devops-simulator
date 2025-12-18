#!/usr/bin/env bash
set -euo pipefail

VERBOSE=0
PORT=8091
STATE_BASE="/tmp/incidentops_crash_loop"
SERVER_PID_FILE="${STATE_BASE}.server.pid"
KILLER_PID_FILE="${STATE_BASE}.killer.pid"

log(){ echo "[$(date '+%F %T')] $*"; }
vlog(){ [[ "$VERBOSE" -eq 1 ]] && log "[VERBOSE] $*"; }

usage(){
  cat <<EOF
Usage: $0 [-v] [--port N]
Stops the killer loop, and leaves a stable demo server running.
Proof: curl should succeed consistently.

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
  log "[CRASH_LOOP][FIX] ERROR: python3 required."
  exit 1
fi

log "[CRASH_LOOP][FIX] Step 1: Stopping killer loop"
if [[ -f "$KILLER_PID_FILE" ]]; then
  kpid="$(cat "$KILLER_PID_FILE" || true)"
  if [[ -n "$kpid" ]] && kill -0 "$kpid" 2>/dev/null; then
    kill "$kpid" 2>/dev/null || true
    sleep 0.5
    kill -9 "$kpid" 2>/dev/null || true
    vlog "[CRASH_LOOP][FIX] Killed killer PID=$kpid"
  fi
  rm -f "$KILLER_PID_FILE" || true
else
  vlog "[CRASH_LOOP][FIX] No killer PID file found."
fi

log "[CRASH_LOOP][FIX] Step 2: Ensuring a stable server is running on port $PORT"
# Kill existing server if any, then start once
if [[ -f "$SERVER_PID_FILE" ]]; then
  spid="$(cat "$SERVER_PID_FILE" || true)"
  if [[ -n "$spid" ]] && kill -0 "$spid" 2>/dev/null; then
    kill "$spid" 2>/dev/null || true
    sleep 0.2
  fi
fi

python3 -m http.server "$PORT" >/dev/null 2>&1 &
echo $! > "$SERVER_PID_FILE"
vlog "[CRASH_LOOP][FIX] Stable server PID=$(cat "$SERVER_PID_FILE")"

log "[CRASH_LOOP][FIX] Step 3: PROOF: curl should succeed multiple times"
for i in {1..5}; do
  curl -sS --max-time 2 "http://127.0.0.1:${PORT}/" >/dev/null
  log "[CRASH_LOOP][FIX] PROOF curl attempt $i: OK"
  sleep 0.5
done

log "[CRASH_LOOP][FIX] DONE."
