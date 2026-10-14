-- Mock e-commerce schema. Every table has a primary key: without one, DMS
-- (pglogical) replicates only INSERTs during CDC, not UPDATEs or DELETEs.
DROP TABLE IF EXISTS order_items, orders, products, customers, heartbeat CASCADE;

CREATE TABLE customers (
  id         bigserial PRIMARY KEY,
  email      text        NOT NULL UNIQUE,
  full_name  text        NOT NULL,
  country    char(2)     NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE products (
  id          bigserial PRIMARY KEY,
  sku         text        NOT NULL UNIQUE,
  name        text        NOT NULL,
  price_cents integer     NOT NULL CHECK (price_cents > 0),
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE orders (
  id          bigserial PRIMARY KEY,
  customer_id bigint      NOT NULL REFERENCES customers (id),
  status      text        NOT NULL CHECK (status IN ('pending', 'paid', 'shipped', 'delivered', 'cancelled')),
  total_cents bigint      NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX orders_customer_id_idx ON orders (customer_id);
CREATE INDEX orders_status_idx ON orders (status);

CREATE TABLE order_items (
  id               bigserial PRIMARY KEY,
  order_id         bigint  NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
  product_id       bigint  NOT NULL REFERENCES products (id),
  quantity         integer NOT NULL CHECK (quantity > 0),
  unit_price_cents integer NOT NULL
);
CREATE INDEX order_items_order_id_idx ON order_items (order_id);

-- Updated by the load generator every write; comparing it on both sides
-- gives end-to-end replication lag.
CREATE TABLE heartbeat (
  id        integer     PRIMARY KEY,
  source_ts timestamptz NOT NULL
);
INSERT INTO heartbeat VALUES (1, clock_timestamp());
