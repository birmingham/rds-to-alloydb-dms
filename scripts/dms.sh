#!/usr/bin/env bash
# Drive the DMS migration job lifecycle.
# Usage: scripts/dms.sh verify | demote | start | status | watch | promote
set -euo pipefail
source "$(dirname "$0")/env.sh"

G=(gcloud database-migration --project "$PROJECT")

# Run an async DMS action and wait for its long-running operation.
run_op() {
  local action="$1"
  local op
  op="$("${G[@]}" migration-jobs "$action" "$JOB" --region "$REGION" --format='value(name)')"
  op="${op##*/}"
  echo "$action: operation $op"
  while true; do
    local res
    res="$("${G[@]}" operations describe "$op" --region "$REGION" --format=json)"
    if [[ "$(jq -r '.done // false' <<<"$res")" == "true" ]]; then
      if jq -e '.error' <<<"$res" >/dev/null; then
        echo "$action FAILED: $(jq -r '.error.message' <<<"$res")" >&2
        exit 1
      fi
      echo "$action: done"
      return
    fi
    sleep 15
  done
}

status() {
  "${G[@]}" migration-jobs describe "$JOB" --region "$REGION" \
    --format="table(state, phase, duration, error.message:label=ERROR)"
}

case "${1:-}" in
  verify)
    run_op verify ;;
  demote)
    echo "Demoting the AlloyDB cluster to a replica of the RDS source (it must be empty)."
    run_op demote-destination ;;
  start)
    echo "Starting: full dump, then CDC. RDS sources pause writes briefly (under a minute) at start."
    run_op start
    status ;;
  status)
    status ;;
  watch)
    while true; do date -u +%H:%M:%S; status; echo; sleep 30; done ;;
  promote)
    read -rp "Promote AlloyDB to a standalone primary? Stop writes to RDS first. [y/N] " ans
    [[ "$ans" == [yY] ]] || { echo "not promoted"; exit 0; }
    run_op promote
    status ;;
  *)
    echo "usage: $0 verify | demote | start | status | watch | promote" >&2; exit 64 ;;
esac
