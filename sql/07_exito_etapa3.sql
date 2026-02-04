-- 7) Metricas de exito Etapa 3 (ex post)
-- Adaptar nombres de eventos y tablas segun tracking real.

WITH params AS (
  SELECT
    DATE '2026-01-01' AS stage3_start_date
),
stage3 AS (
  SELECT
    pos_id,
    ean,
    event_name,
    event_ts
  FROM stage3_events
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
faltas_con_etapa AS (
  SELECT
    f.*,
    CASE
      WHEN f.falta_ts >= params.stage3_start_date THEN 'post'
      ELSE 'pre'
    END AS periodo
  FROM faltas f
  CROSS JOIN params
),
resumen_stage3 AS (
  SELECT
    periodo,
    COUNT(*) FILTER (WHERE event_name = 'missing_pool_entered') AS pool_vivo,
    COUNT(*) FILTER (WHERE event_name = 'ready_to_buy') AS listo_para_comprar,
    COUNT(*) FILTER (WHERE event_name = 'missing_closed') AS cerradas
  FROM stage3 s
  JOIN faltas_con_etapa f
    ON f.pos_id = s.pos_id
   AND f.ean = s.ean
  GROUP BY 1
),
tiempo_cierre AS (
  SELECT
    f.periodo,
    AVG(EXTRACT(EPOCH FROM (c.compra_ts - f.falta_ts)) / 3600.0) AS horas_promedio_cierre
  FROM faltas_con_etapa f
  JOIN compras c
    ON c.pos_id = f.pos_id
   AND c.ean = f.ean
   AND c.compra_ts > f.falta_ts
  GROUP BY 1
)
SELECT
  r.periodo,
  r.pool_vivo,
  r.listo_para_comprar,
  r.cerradas,
  t.horas_promedio_cierre
FROM resumen_stage3 r
LEFT JOIN tiempo_cierre t
  ON t.periodo = r.periodo
ORDER BY r.periodo;
