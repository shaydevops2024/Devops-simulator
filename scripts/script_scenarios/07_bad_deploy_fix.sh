#!/usr/bin/env bash
set -euo pipefail

VERBOSE=0
CONFIG="./config.json"
BACKUP="/tmp/incidentops_bad_deploy.config.bak"

log(){ echo "[$(date '+%F %T')] $*"; }
vlog(){ [[ "$VERBOSE" -eq 1 ]] && log "[VERBOSE] $*"; }

usage(){
  cat <<EOF
Usage: $0 [-v] [--config PATH]
Restores JSON config from backup.
Proof: jq (or python) parse succeeds.

Backup expected at: $BACKUP
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v) VERBOSE=1; shift ;;
    --config) CONFIG="${2:?}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

log "[BAD_DEPLOY][FIX] Step 1: Restoring backup to $CONFIG"
if [[ ! -f "$BACKUP" ]]; then
  log "[BAD_DEPLOY][FIX] ERROR: Backup not found at $BACKUP"
  exit 1
fi

cp -f "$BACKUP" "$CONFIG"

log "[BAD_DEPLOY][FIX] Step 2: PROOF: config parsing should succeed"
if command -v jq >/dev/null 2>&1; then
  jq . "$CONFIG" >/dev/null
  log "[BAD_DEPLOY][FIX] OK: jq parsed config successfully"
else
  python3 -c "import json; json.load(open('$CONFIG'))" >/dev/null
  log "[BAD_DEPLOY][FIX] OK: python parsed config successfully"
fi

log "[BAD_DEPLOY][FIX] DONE."
