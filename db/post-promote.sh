#!/usr/bin/env bash
# Run on AlloyDB right after promotion:
#   1. advance every serial sequence past the highest replicated id
#      (DMS doesn't guarantee sequence state matches the source), and
#   2. prove the new primary accepts writes, in a transaction that's rolled back.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

echo "== resetting sequences on AlloyDB"
dst "$DB_NAME" <<'SQL'
SELECT format(
  'SELECT %L AS sequence, setval(%L, (SELECT coalesce(max(%I), 0) + 1 FROM %I.%I), false) AS next_value',
  seq, seq, column_name, table_schema, table_name)
FROM (
  SELECT table_schema, table_name, column_name,
         pg_get_serial_sequence(format('%I.%I', table_schema, table_name), column_name) AS seq
  FROM information_schema.columns
  WHERE column_default LIKE 'nextval(%'
    AND table_schema NOT IN ('pg_catalog', 'information_schema', 'pglogical')
) s
WHERE seq IS NOT NULL
\gexec
SQL

echo "== write test on the promoted primary (rolled back)"
dst "$DB_NAME" <<'SQL'
BEGIN;
INSERT INTO orders (customer_id, status) VALUES (1, 'pending') RETURNING id AS new_order_id;
ROLLBACK;
SQL

cat <<'MSG'
AlloyDB is serving writes with correct sequences.
Note: database users and roles aren't migrated by DMS. Recreate application
users on AlloyDB before pointing applications at it.
MSG
