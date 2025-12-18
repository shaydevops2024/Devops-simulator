#!/usr/bin/env bash
set -euo pipefail

VERBOSE=0
CORES=1
DURATION=0  # 0 = run until fixed
STATE="/tmp/incidentops_cpu_spike.pids"

log(){ echo "[$(date '+%F %T')] $*"; }
vlog(){ [[ "$VERBOSE" -eq 1 ]] && log "[VERBOSE] $*"; }

usage(){
  cat <<EOF
Usage: $0 [-v] [--cores N] [--duration SEC]
Creates a CPU spike by running tight loops in the background.
Proof: shows 'top' snapshot.

Options:
  -v              Verbose logs
  --cores N       Number of busy loops (default: 1)
  --duration SEC  Auto-stop after SEC (default: 0 = run until fixed)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v) VERBOSE=1; shift ;;
    --cores) CORES="${2:?}"; shift 2 ;;
    --duration) DURATION="${2:?}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

log "[CPU_SPIKE][CAUSE] Step 1: Preparing state file: $STATE"
: > "$STATE"

log "[CPU_SPIKE][CAUSE] Step 2: Starting $CORES CPU burners"
for i in $(seq 1 "$CORES"); do
  ( while :; do :; done ) &
  pid=$!
  echo "$pid" >> "$STATE"
  vlog "[CPU_SPIKE][CAUSE] Started burner $i with PID=$pid"
done

log "[CPU_SPIKE][CAUSE] Step 3: Waiting briefly for CPU usage to rise"
sleep 2

log "[CPU_SPIKE][CAUSE] PROOF: top snapshot (first ~20 lines)"
top -b -n 1 | head -n 20 || true

if [[ "$DURATION" -gt 0 ]]; then
  log "[CPU_SPIKE][CAUSE] Step 4: Auto-stop requested after ${DURATION}s"
  sleep "$DURATION"
  log "[CPU_SPIKE][CAUSE] Auto-stop: run the fix script or kill burners manually."
fi

log "[CPU_SPIKE][CAUSE] DONE. Fix with: 01_cpu_spike_fix.sh"
