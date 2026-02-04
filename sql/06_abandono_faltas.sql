-- 6) Abandono de faltas: productos sin compra posterior en N dias

WITH params AS (
  SELECT
    14::int AS abandon_days
),
faltas AS (
  SELECT
    o.pos_id,
    o.order_ts AS falta_ts,
    oi.ean
  FROM orders o
  JOIN order_items oi
    ON oi.order_id = o.order_id
   AND oi.pos_id = o.pos_id
  WHERE oi.qty_requested > oi.qty_purchased
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
  WHERE oi.qty_purchased > 0
),
faltas_con_estado AS (
  SELECT
    f.*,
    CASE
      WHEN EXISTS (
        SELECT 1
        FROM compras c
        WHERE c.pos_id = f.pos_id
          AND c.ean = f.ean
          AND c.compra_ts > f.falta_ts
          AND c.compra_ts <= f.falta_ts + (params.abandon_days || ' days')::interval
      ) THEN 0 ELSE 1
    END AS abandonada
  FROM faltas f
  CROSS JOIN params
)
SELECT
  COUNT(*) AS faltas_totales,
  SUM(abandonada) AS faltas_abandonadas,
  ROUND(100.0 * SUM(abandonada) / NULLIF(COUNT(*), 0), 2) AS pct_abandono
FROM faltas_con_estado;
