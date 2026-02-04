-- Base de faltas por item
-- Ajustar nombres de tablas y campos segun tu esquema.

WITH params AS (
  SELECT
    7::int AS window_days
),
base_faltas AS (
  SELECT
    o.order_id,
    o.pos_id,
    o.order_ts AS falta_ts,
    oi.ean,
    (oi.qty_requested - oi.qty_purchased) AS falta_qty,
    COALESCE(p.product_type, 'Unknown') AS product_type
  FROM orders o
  JOIN order_items oi
    ON oi.order_id = o.order_id
   AND oi.pos_id = o.pos_id
  LEFT JOIN products p
    ON p.ean = oi.ean
  WHERE oi.qty_requested > oi.qty_purchased
)
SELECT *
FROM base_faltas;
