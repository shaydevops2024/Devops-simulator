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
Simulates a bad deploy by corrupting a JSON config.
Proof: jq parse fails (or python json parse fails).

Creates backup at: $BACKUP
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

log "[BAD_DEPLOY][CAUSE] Step 1: Ensuring config exists at $CONFIG"
if [[ ! -f "$CONFIG" ]]; then
  log "[BAD_DEPLOY][CAUSE] Config not found. Creating a valid sample config."
  cat > "$CONFIG" <<'JSON'
{ "serviceName": "demo", "port": 8000, "featureFlag": true }
JSON
fi

log "[BAD_DEPLOY][CAUSE] Step 2: Backing up config to $BACKUP"
cp -f "$CONFIG" "$BACKUP"

log "[BAD_DEPLOY][CAUSE] Step 3: Writing INVALID JSON to config (bad deploy)"
cat > "$CONFIG" <<'JSON'
{ "serviceName": "demo", "port": 8000, "featureFlag": truE,,, }
JSON

log "[BAD_DEPLOY][CAUSE] Step 4: PROOF: config parsing should fail"
if command -v jq >/dev/null 2>&1; then
  jq . "$CONFIG" >/dev/null && \
    log "[BAD_DEPLOY][CAUSE] WARNING: jq succeeded unexpectedly" || \
    log "[BAD_DEPLOY][CAUSE] OK: jq failed as expected (invalid JSON)"
else
  log "[BAD_DEPLOY][CAUSE] jq not found. Using python3 json parse as proof."
  python3 -c "import json; json.load(open('$CONFIG'))" >/dev/null 2>&1 && \
    log "[BAD_DEPLOY][CAUSE] WARNING: python parse succeeded unexpectedly" || \
    log "[BAD_DEPLOY][CAUSE] OK: python parse failed as expected"
fi

log "[BAD_DEPLOY][CAUSE] DONE. Fix with: 07_bad_deploy_fix.sh"
