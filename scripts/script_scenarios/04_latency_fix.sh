#!/usr/bin/env bash
set -euo pipefail

VERBOSE=0
IFACE="lo"
TARGET_URL="http://127.0.0.1:8000/"

log(){ echo "[$(date '+%F %T')] $*"; }
vlog(){ [[ "$VERBOSE" -eq 1 ]] && log "[VERBOSE] $*"; }

usage(){
  cat <<EOF
Usage: $0 [-v] [--iface IFACE] [--url URL]
Removes tc netem latency from an interface.
Proof: qdisc removed + curl timing.

Requires: sudo, tc (iproute2)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v) VERBOSE=1; shift ;;
    --iface) IFACE="${2:?}"; shift 2 ;;
    --url) TARGET_URL="${2:?}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

if ! command -v tc >/dev/null 2>&1; then
  log "[LATENCY][FIX] ERROR: tc not found."
  exit 1
fi

log "[LATENCY][FIX] Step 1: Removing tc qdisc on iface=$IFACE (requires sudo)"
sudo tc qdisc del dev "$IFACE" root 2>/dev/null || true

log "[LATENCY][FIX] Step 2: Showing qdisc state (should be default/no netem)"
sudo tc qdisc show dev "$IFACE" || true

log "[LATENCY][FIX] PROOF: curl timing after fix: $TARGET_URL"
curl -sS -o /dev/null -w "fixed_time_total=%{time_total}\n" "$TARGET_URL" || true

log "[LATENCY][FIX] DONE."
