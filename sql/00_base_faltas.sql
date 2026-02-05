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
  JOIN points_of_sale pos
    ON pos.id = o.pos_id
  JOIN clients c
    ON c.id = pos.client_id
  LEFT JOIN products p
    ON p.ean = oi.ean
  WHERE o.status_id = 2
    AND c.is_demo = 0
    AND c.deleted_at IS NULL
    AND pos.deleted_at IS NULL
    AND oi.qty_requested > 0
    AND oi.qty_requested > oi.qty_purchased
)
SELECT *
FROM base_faltas;
