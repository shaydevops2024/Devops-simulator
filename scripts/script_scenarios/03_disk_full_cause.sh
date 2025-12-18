#!/usr/bin/env bash
set -euo pipefail

VERBOSE=0
TARGET_DIR="/tmp/incidentops_disk_full"
SIZE_MB=1024
STATE="/tmp/incidentops_disk_full.file"

log(){ echo "[$(date '+%F %T')] $*"; }
vlog(){ [[ "$VERBOSE" -eq 1 ]] && log "[VERBOSE] $*"; }

usage(){
  cat <<EOF
Usage: $0 [-v] [--dir PATH] [--size-mb N]
Fills disk space in a controlled way by creating a large file.
Proof: shows 'df -h' for the target filesystem.

Options:
  -v            Verbose logs
  --dir PATH    Target directory (default: /tmp/incidentops_disk_full)
  --size-mb N   File size in MB (default: 1024)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v) VERBOSE=1; shift ;;
    --dir) TARGET_DIR="${2:?}"; shift 2 ;;
    --size-mb) SIZE_MB="${2:?}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

mkdir -p "$TARGET_DIR"
file="$TARGET_DIR/fillfile.bin"

log "[DISK_FULL][CAUSE] Step 1: Creating $SIZE_MB MB file at $file"
if command -v fallocate >/dev/null 2>&1; then
  vlog "[DISK_FULL][CAUSE] Using fallocate"
  fallocate -l "${SIZE_MB}M" "$file"
else
  vlog "[DISK_FULL][CAUSE] fallocate not found; using dd (slower)"
  dd if=/dev/zero of="$file" bs=1M count="$SIZE_MB" status=progress
fi

echo "$file" > "$STATE"

log "[DISK_FULL][CAUSE] PROOF: df -h (filesystem for $TARGET_DIR)"
df -h "$TARGET_DIR" || true

log "[DISK_FULL][CAUSE] DONE. Fix with: 03_disk_full_fix.sh"
