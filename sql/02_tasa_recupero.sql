-- 2) Tasa de recupero de faltas por producto y tipo

WITH params AS (
  SELECT
    7::int AS window_days
),
faltas AS (
  SELECT
    o.pos_id,
    o.order_ts AS falta_ts,
    oi.ean,
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
),
compras AS (
  SELECT
    o.pos_id,
    o.order_ts AS compra_ts,
    oi.ean
  FROM orders o
  JOIN order_items oi
    ON oi.order_id = o.order_id
   AND oi.pos_id = o.pos_id
  JOIN points_of_sale pos
    ON pos.id = o.pos_id
  JOIN clients c
    ON c.id = pos.client_id
  WHERE o.status_id = 2
    AND c.is_demo = 0
    AND c.deleted_at IS NULL
    AND pos.deleted_at IS NULL
    AND oi.qty_requested > 0
    AND oi.qty_purchased > 0
),
faltas_con_match AS (
  SELECT
    f.*,
    CASE
      WHEN EXISTS (
        SELECT 1
        FROM compras c
        WHERE c.pos_id = f.pos_id
          AND c.ean = f.ean
          AND c.compra_ts > f.falta_ts
          AND c.compra_ts <= f.falta_ts + (params.window_days || ' days')::interval
      ) THEN 1 ELSE 0
    END AS recuperada
  FROM faltas f
  CROSS JOIN params
)
SELECT
  product_type,
  COUNT(*) AS faltas_totales,
  SUM(recuperada) AS faltas_recuperadas,
  ROUND(100.0 * SUM(recuperada) / NULLIF(COUNT(*), 0), 2) AS pct_recupero
FROM faltas_con_match
GROUP BY 1
ORDER BY 1;
