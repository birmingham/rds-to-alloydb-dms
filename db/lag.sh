#!/usr/bin/env bash
# End-to-end replication lag: compare the heartbeat timestamp on RDS with the
# replicated copy on AlloyDB.
# Usage: bash lag.sh [--watch]
set -euo pipefail
source "$(dirname "$0")/lib.sh"

check() {
  local s d
  s="$(src "$DB_NAME" -tAc 'select source_ts from heartbeat where id = 1')"
  if ! d="$(dst "$DB_NAME" -tAc 'select source_ts from heartbeat where id = 1' 2>/dev/null)" || [[ -z "$d" ]]; then
    echo "$(date -u +%H:%M:%S)  source $s  destination: not replicated yet (full dump in progress?)"
    return
  fi
  local lag
  lag="$(src "$DB_NAME" -tAc "select round(extract(epoch from ('$s'::timestamptz - '$d'::timestamptz))::numeric, 1)")"
  echo "$(date -u +%H:%M:%S)  source $s  destination $d  lag ${lag}s"
}

if [[ "${1:-}" == "--watch" ]]; then
  while true; do check; sleep 5; done
else
  check
fi
