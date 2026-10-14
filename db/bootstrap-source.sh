#!/usr/bin/env bash
# Prepare the RDS source for DMS and load mock data.
# Usage: bash bootstrap-source.sh [scale]   (scale 1 = 50k customers, 200k orders, 600k items)
set -euo pipefail
source "$(dirname "$0")/lib.sh"
SCALE="${1:-1}"

echo "== 1/5 checking RDS parameters"
spl="$(src postgres -tAc 'show shared_preload_libraries')"
wal="$(src postgres -tAc 'show wal_level')"
echo "shared_preload_libraries = $spl"
echo "wal_level                = $wal"
if [[ "$spl" != *pglogical* || "$wal" != "logical" ]]; then
  cat >&2 <<MSG
The parameter group isn't active yet. Reboot the instance and re-run:
  aws rds reboot-db-instance --db-instance-identifier <rds_identifier from terraform output>
MSG
  exit 1
fi

echo "== 2/5 creating database $DB_NAME"
if ! src postgres -tAc "select 1 from pg_database where datname = '$DB_NAME'" | grep -q 1; then
  src postgres -c "create database \"$DB_NAME\""
fi

echo "== 3/5 schema + mock data (scale $SCALE)"
src "$DB_NAME" -f "$SCRIPT_DIR/sql/schema.sql"
time src "$DB_NAME" -v scale="$SCALE" -f "$SCRIPT_DIR/sql/seed.sql"

echo "== 4/5 DMS user"
DMS_PW="$(secret dms-user)" src postgres -v dms_user="$DMS_USER" -f "$SCRIPT_DIR/sql/dms-user.sql"

echo "== 5/5 pglogical + grants in every database (postgres and $DB_NAME)"
for db in postgres "$DB_NAME"; do
  src "$db" -v dms_user="$DMS_USER" -f "$SCRIPT_DIR/sql/dms-grants.sql"
  echo "  $db: ok"
done

echo
src "$DB_NAME" -c "
  select 'customers' as table_name, count(*) from customers union all
  select 'products', count(*) from products union all
  select 'orders', count(*) from orders union all
  select 'order_items', count(*) from order_items"
echo "Source ready for DMS."
