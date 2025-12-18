#!/usr/bin/env bash
set -euo pipefail

VERBOSE=0
MB_PER_SEC=50
STATE="/tmp/incidentops_memory_leak.pid"

log(){ echo "[$(date '+%F %T')] $*"; }
vlog(){ [[ "$VERBOSE" -eq 1 ]] && log "[VERBOSE] $*"; }

usage(){
  cat <<EOF
Usage: $0 [-v] [--mb-per-sec N]
Simulates a memory leak by allocating memory continuously (Python3 required).
Proof: shows 'free -m' and process RSS.

Options:
  -v               Verbose logs
  --mb-per-sec N   Allocation rate (default: 50)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v) VERBOSE=1; shift ;;
    --mb-per-sec) MB_PER_SEC="${2:?}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

if ! command -v python3 >/dev/null 2>&1; then
  log "[MEM_LEAK][CAUSE] ERROR: python3 is required for this scenario."
  exit 1
fi

log "[MEM_LEAK][CAUSE] Step 1: Starting memory allocator (rate=${MB_PER_SEC}MB/s)"
cat > /tmp/incidentops_memleak_worker.py <<'PY'
import os, time, sys
mb_per_sec = int(os.environ.get("MB_PER_SEC","50"))
chunks = []
step = 1
try:
    while True:
        # allocate mb_per_sec MB each second in 1MB chunks
        for _ in range(mb_per_sec):
            chunks.append(bytearray(1024*1024))
        print(f"[memleak] step={step} allocated_total_mb={len(chunks)}", flush=True)
        step += 1
        time.sleep(1)
except KeyboardInterrupt:
    print("[memleak] interrupted, exiting", flush=True)
PY

MB_PER_SEC="$MB_PER_SEC" python3 /tmp/incidentops_memleak_worker.py >/tmp/incidentops_memleak.log 2>&1 &
pid=$!
echo "$pid" > "$STATE"
vlog "[MEM_LEAK][CAUSE] Allocator PID=$pid, log=/tmp/incidentops_memleak.log"

log "[MEM_LEAK][CAUSE] Step 2: Waiting briefly for memory usage to rise"
sleep 3

log "[MEM_LEAK][CAUSE] PROOF #1: free -m"
free -m || true

log "[MEM_LEAK][CAUSE] PROOF #2: process RSS/VSZ"
ps -o pid,comm,rss,vsz,etime -p "$pid" || true

log "[MEM_LEAK][CAUSE] DONE. Fix with: 02_memory_leak_fix.sh"
