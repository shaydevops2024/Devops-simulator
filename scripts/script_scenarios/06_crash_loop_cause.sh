#!/usr/bin/env bash
set -euo pipefail

VERBOSE=0
PORT=8091
KILL_EVERY=2
STATE_BASE="/tmp/incidentops_crash_loop"
SERVER_PID_FILE="${STATE_BASE}.server.pid"
KILLER_PID_FILE="${STATE_BASE}.killer.pid"

log(){ echo "[$(date '+%F %T')] $*"; }
vlog(){ [[ "$VERBOSE" -eq 1 ]] && log "[VERBOSE] $*"; }

usage(){
  cat <<EOF
Usage: $0 [-v] [--port N] [--kill-every SEC]
Starts a demo HTTP server then continuously kills it to simulate crash loop.
Proof: curl intermittently fails + process restarts visible in logs.

Requires: python3
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v) VERBOSE=1; shift ;;
    --port) PORT="${2:?}"; shift 2 ;;
    --kill-every) KILL_EVERY="${2:?}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

if ! command -v python3 >/dev/null 2>&1; then
  log "[CRASH_LOOP][CAUSE] ERROR: python3 required."
  exit 1
fi

start_server(){
  python3 -m http.server "$PORT" >/dev/null 2>&1 &
  echo $! > "$SERVER_PID_FILE"
  vlog "[CRASH_LOOP][CAUSE] Started server PID=$(cat "$SERVER_PID_FILE")"
}

log "[CRASH_LOOP][CAUSE] Step 1: Starting demo server on port $PORT"
start_server

log "[CRASH_LOOP][CAUSE] Step 2: Starting killer loop (kills server every ${KILL_EVERY}s)"
(
  while true; do
    pid="$(cat "$SERVER_PID_FILE" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      echo "[killer] killing server pid=$pid" >> "${STATE_BASE}.log"
      kill "$pid" 2>/dev/null || true
      sleep 0.3
    fi
    # restart server
    python3 -m http.server "$PORT" >/dev/null 2>&1 &
    newpid=$!
    echo "$newpid" > "$SERVER_PID_FILE"
    echo "[killer] restarted server pid=$newpid" >> "${STATE_BASE}.log"
    sleep "$KILL_EVERY"
  done
) &
echo $! > "$KILLER_PID_FILE"
vlog "[CRASH_LOOP][CAUSE] Killer PID=$(cat "$KILLER_PID_FILE"), log=${STATE_BASE}.log"

log "[CRASH_LOOP][CAUSE] Step 3: PROOF: try curl a few times (some should fail)"
for i in {1..5}; do
  if curl -sS --max-time 1 "http://127.0.0.1:${PORT}/" >/dev/null; then
    log "[CRASH_LOOP][CAUSE] PROOF curl attempt $i: OK"
  else
    log "[CRASH_LOOP][CAUSE] PROOF curl attempt $i: FAIL (expected intermittently)"
  fi
  sleep 1
done

log "[CRASH_LOOP][CAUSE] PROOF: tail crash loop log"
tail -n 10 "${STATE_BASE}.log" 2>/dev/null || true

log "[CRASH_LOOP][CAUSE] DONE. Fix with: 06_crash_loop_fix.sh"
