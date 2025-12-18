#!/usr/bin/env bash
set -euo pipefail

VERBOSE=0
STATE="/tmp/incidentops_disk_full.file"

log(){ echo "[$(date '+%F %T')] $*"; }
vlog(){ [[ "$VERBOSE" -eq 1 ]] && log "[VERBOSE] $*"; }

usage(){
  cat <<EOF
Usage: $0 [-v]
Removes the large file created by 03_disk_full_cause.sh
Proof: shows 'df -h' after cleanup.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

log "[DISK_FULL][FIX] Step 1: Reading state file $STATE"
if [[ ! -f "$STATE" ]]; then
  log "[DISK_FULL][FIX] No state found. Nothing to remove."
  exit 0
fi

file="$(cat "$STATE" || true)"
if [[ -z "$file" ]]; then
  log "[DISK_FULL][FIX] Empty state. Cleaning."
  rm -f "$STATE"
  exit 0
fi

log "[DISK_FULL][FIX] Step 2: Removing $file"
rm -f "$file" || true

log "[DISK_FULL][FIX] Step 3: Cleanup state"
rm -f "$STATE" || true

log "[DISK_FULL][FIX] Step 4: PROOF: df -h (filesystem after cleanup)"
dir="$(dirname "$file")"
df -h "$dir" || true

log "[DISK_FULL][FIX] DONE."
