-- 1) Intento de recupero: pedidos con faltas que luego compran algun EAN faltante

WITH params AS (
  SELECT
    7::int AS window_days
),
faltas_por_pedido AS (
  SELECT
    o.order_id,
    o.pos_id,
    o.order_ts AS falta_ts,
    ARRAY_AGG(DISTINCT oi.ean) AS faltas_ean
  FROM orders o
  JOIN order_items oi
    ON oi.order_id = o.order_id
   AND oi.pos_id = o.pos_id
  WHERE oi.qty_requested > oi.qty_purchased
  GROUP BY 1, 2, 3
),
compras_posteriores AS (
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
pedido_con_intento AS (
  SELECT
    f.order_id,
    f.pos_id,
    f.falta_ts,
    EXISTS (
      SELECT 1
      FROM compras_posteriores c
      WHERE c.pos_id = f.pos_id
        AND c.compra_ts > f.falta_ts
        AND c.compra_ts <= f.falta_ts + (params.window_days || ' days')::interval
        AND c.ean = ANY (f.faltas_ean)
    ) AS intento_reponer
  FROM faltas_por_pedido f
  CROSS JOIN params
)
SELECT
  COUNT(*) AS pedidos_con_faltas,
  SUM(CASE WHEN intento_reponer THEN 1 ELSE 0 END) AS pedidos_con_intento,
  ROUND(100.0 * SUM(CASE WHEN intento_reponer THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS pct_intento
FROM pedido_con_intento;
