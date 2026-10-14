#!/usr/bin/env bash
# Row counts and content checksums per table, RDS vs AlloyDB.
# Stop the load generator and wait for lag 0 first, or counts will differ.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

TABLES=(customers products orders order_items)
QUERY='select count(*), md5(coalesce(string_agg(t::text, %s order by id), %s)) from %s t'
fail=0

if [[ -f /tmp/dms-load.pid ]] && kill -0 "$(cat /tmp/dms-load.pid)" 2>/dev/null; then
  echo "WARNING: load generator is running; results will drift. Run: bash load.sh stop" >&2
fi

printf '%-12s %10s %10s  %-8s %s\n' TABLE SOURCE DEST CHECKSUM RESULT
for t in "${TABLES[@]}"; do
  # shellcheck disable=SC2059
  q="$(printf "$QUERY" "','" "''" "$t")"
  IFS='|' read -r s_count s_md5 <<<"$(src "$DB_NAME" -tA -c "$q")"
  IFS='|' read -r d_count d_md5 <<<"$(dst "$DB_NAME" -tA -c "$q")"
  if [[ "$s_count" == "$d_count" && "$s_md5" == "$d_md5" ]]; then
    result=PASS
  else
    result=FAIL; fail=1
  fi
  printf '%-12s %10s %10s  %-8s %s\n' "$t" "$s_count" "$d_count" "${s_md5:0:8}" "$result"
done

echo
echo "Sequences (DMS doesn't keep these in sync; fix after promote with post-promote.sh):"
seq_q="select sequencename, coalesce(last_value, 0) from pg_sequences where schemaname = 'public' order by 1"
paste <(src "$DB_NAME" -tA -F ' ' -c "$seq_q") <(dst "$DB_NAME" -tA -F ' ' -c "$seq_q" | awk '{print $2}') \
  | awk 'BEGIN{printf "  %-24s %12s %12s\n","SEQUENCE","SOURCE","DEST"} {printf "  %-24s %12s %12s\n",$1,$2,$3}'

exit "$fail"
