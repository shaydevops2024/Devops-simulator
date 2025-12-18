#!/usr/bin/env bash
set -euo pipefail

VERBOSE=0
IFACE="lo"
DELAY_MS=500
TARGET_URL="http://127.0.0.1:8000/"

log(){ echo "[$(date '+%F %T')] $*"; }
vlog(){ [[ "$VERBOSE" -eq 1 ]] && log "[VERBOSE] $*"; }

usage(){
  cat <<EOF
Usage: $0 [-v] [--iface IFACE] [--delay-ms N] [--url URL]
Adds network latency using tc netem on an interface.
Proof: curl timing before/after.

Requires: sudo, tc (iproute2)

Defaults:
  --iface lo
  --delay-ms 500
  --url http://127.0.0.1:8000/
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v) VERBOSE=1; shift ;;
    --iface) IFACE="${2:?}"; shift 2 ;;
    --delay-ms) DELAY_MS="${2:?}"; shift 2 ;;
    --url) TARGET_URL="${2:?}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

if ! command -v tc >/dev/null 2>&1; then
  log "[LATENCY][CAUSE] ERROR: tc not found. Install iproute2."
  exit 1
fi

log "[LATENCY][CAUSE] Step 1: PROOF baseline curl timing: $TARGET_URL"
curl -sS -o /dev/null -w "baseline_time_total=%{time_total}\n" "$TARGET_URL" || true

log "[LATENCY][CAUSE] Step 2: Adding tc netem delay=${DELAY_MS}ms on iface=$IFACE (requires sudo)"
sudo tc qdisc replace dev "$IFACE" root netem delay "${DELAY_MS}ms"

log "[LATENCY][CAUSE] Step 3: Showing qdisc state"
sudo tc qdisc show dev "$IFACE" || true

log "[LATENCY][CAUSE] PROOF after injection: curl timing should increase"
curl -sS -o /dev/null -w "after_time_total=%{time_total}\n" "$TARGET_URL" || true

log "[LATENCY][CAUSE] DONE. Fix with: 04_latency_fix.sh"
