-- Deterministic mock data (no random()), so row content is reproducible.
-- psql variable :scale multiplies customers and orders.

INSERT INTO customers (email, full_name, country, created_at)
SELECT 'customer' || g || '@example.com',
       'Customer ' || g,
       (ARRAY['US','CA','GB','DE','FR','JP','AU','BR','IN','MX'])[1 + (g % 10)],
       now() - (g % 730) * interval '1 day'
FROM generate_series(1, 50000 * :scale) AS g;

INSERT INTO products (sku, name, price_cents)
SELECT 'SKU-' || lpad(g::text, 6, '0'),
       'Product ' || g,
       199 + (g * 7919 % 20000)
FROM generate_series(1, 5000) AS g;

INSERT INTO orders (customer_id, status, created_at, updated_at)
SELECT 1 + (g * 7 % (50000 * :scale)),
       (ARRAY['pending','paid','shipped','delivered','cancelled'])[1 + (g % 5)],
       now() - (g % 365) * interval '1 day',
       now() - (g % 365) * interval '1 day'
FROM generate_series(1, 200000 * :scale) AS g;

-- Three line items per order.
INSERT INTO order_items (order_id, product_id, quantity, unit_price_cents)
SELECT o.id, p.id, 1 + (o.id + n) % 4, p.price_cents
FROM orders o
CROSS JOIN generate_series(1, 3) AS n
JOIN products p ON p.id = 1 + ((o.id * 31 + n * 17) % 5000);

UPDATE orders o
SET total_cents = s.total
FROM (SELECT order_id, sum(quantity * unit_price_cents) AS total FROM order_items GROUP BY order_id) s
WHERE s.order_id = o.id;

ANALYZE;
