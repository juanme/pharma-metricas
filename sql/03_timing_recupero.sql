-- 3) Timing de recupero: distribucion de tiempo falta -> compra

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
  LEFT JOIN products p
    ON p.ean = oi.ean
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
primer_recupero AS (
  SELECT
    f.pos_id,
    f.ean,
    f.falta_ts,
    f.product_type,
    MIN(c.compra_ts) AS compra_ts
  FROM faltas f
  JOIN compras c
    ON c.pos_id = f.pos_id
   AND c.ean = f.ean
   AND c.compra_ts > f.falta_ts
   AND c.compra_ts <= f.falta_ts + (params.window_days || ' days')::interval
  CROSS JOIN params
  GROUP BY 1, 2, 3, 4
),
con_delta AS (
  SELECT
    *,
    EXTRACT(EPOCH FROM (compra_ts - falta_ts)) / 3600.0 AS delta_horas
  FROM primer_recupero
)
SELECT
  product_type,
  CASE
    WHEN delta_horas < 6 THEN '<6h'
    WHEN delta_horas < 12 THEN '6-12h'
    WHEN delta_horas < 24 THEN '12-24h'
    WHEN delta_horas < 48 THEN '24-48h'
    ELSE '>48h'
  END AS bucket_tiempo,
  COUNT(*) AS faltas_recuperadas
FROM con_delta
GROUP BY 1, 2
ORDER BY 1, 2;
