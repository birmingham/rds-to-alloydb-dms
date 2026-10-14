#!/usr/bin/env bash
# Live writes against the RDS source while DMS replicates: INSERTs (new
# orders + items), UPDATEs (status changes), DELETEs (old cancelled orders),
# and a heartbeat for lag measurement.
# Usage: bash load.sh start [interval_seconds] | stop | status
set -euo pipefail
source "$(dirname "$0")/lib.sh"

PID_FILE=/tmp/dms-load.pid
LOG_FILE=/tmp/dms-load.log

run() {
  local interval="${1:-0.5}"
  local max_customer
  max_customer="$(src "$DB_NAME" -tAc 'select max(id) from customers')"
  local n=0
  while true; do
    src "$DB_NAME" -c "
      BEGIN;
      -- Pick the line items first, so the order is inserted with its total.
      -- (An outer UPDATE can't see rows a CTE inserted in the same statement.)
      WITH picks AS (
        SELECT id, price_cents, 1 + floor(random() * 3)::int AS qty
        FROM products ORDER BY random() LIMIT 2
      ), new_order AS (
        INSERT INTO orders (customer_id, status, total_cents)
        SELECT 1 + floor(random() * $max_customer)::bigint, 'pending', sum(qty * price_cents)
        FROM picks
        RETURNING id
      )
      INSERT INTO order_items (order_id, product_id, quantity, unit_price_cents)
      SELECT new_order.id, picks.id, picks.qty, picks.price_cents
      FROM new_order, picks;

      UPDATE orders SET status = 'paid', updated_at = now()
      WHERE id = (SELECT id FROM orders WHERE status = 'pending' ORDER BY id LIMIT 1);

      DELETE FROM orders
      WHERE id = (SELECT id FROM orders WHERE status = 'cancelled' ORDER BY id LIMIT 1);

      UPDATE heartbeat SET source_ts = clock_timestamp() WHERE id = 1;
      COMMIT;"
    n=$((n + 1))
    if (( n % 20 == 0 )); then
      echo "$(date -u +%H:%M:%S) $n write batches (1 insert order + 2 items, 1 update, 1 delete, heartbeat each)"
    fi
    sleep "$interval"
  done
}

case "${1:-}" in
  start)
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "already running (pid $(cat "$PID_FILE"))"; exit 0
    fi
    setsid nohup bash "$0" run "${2:-0.5}" >"$LOG_FILE" 2>&1 < /dev/null &
    echo $! >"$PID_FILE"
    echo "load generator started (pid $!), log: $LOG_FILE"
    ;;
  run)
    run "${2:-0.5}"
    ;;
  stop)
    if [[ -f "$PID_FILE" ]] && kill "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "load generator stopped"
    else
      echo "not running"
    fi
    rm -f "$PID_FILE"
    ;;
  status)
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "running (pid $(cat "$PID_FILE"))"; tail -3 "$LOG_FILE"
    else
      echo "not running"
    fi
    ;;
  *)
    echo "usage: $0 start [interval] | stop | status" >&2; exit 64 ;;
esac
