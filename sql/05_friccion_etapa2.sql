-- 5) Friccion del flujo actual (Etapa 2)
-- Nota: requiere mapear descargas a EAN faltantes via payload o tabla intermedia.

WITH params AS (
  SELECT
    7::int AS window_days
),
descargas AS (
  SELECT
    e.event_id,
    e.pos_id,
    e.event_ts
  FROM events e
  JOIN points_of_sale pos
    ON pos.id = e.pos_id
  JOIN clients c
    ON c.id = pos.client_id
  WHERE e.event_name = 'download__missing_items'
    AND c.is_demo = 0
    AND c.deleted_at IS NULL
    AND pos.deleted_at IS NULL
),
descarga_items AS (
  -- Reemplazar por el parseo real del payload.
  -- Esperado: una fila por (event_id, pos_id, ean)
  SELECT
    event_id,
    pos_id,
    ean
  FROM event_missing_items
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
descarga_con_compra AS (
  SELECT
    d.event_id,
    d.pos_id,
    d.event_ts,
    EXISTS (
      SELECT 1
      FROM descarga_items di
      JOIN compras c
        ON c.pos_id = di.pos_id
       AND c.ean = di.ean
      WHERE di.event_id = d.event_id
        AND c.compra_ts > d.event_ts
        AND c.compra_ts <= d.event_ts + (params.window_days || ' days')::interval
    ) AS tuvo_compra
  FROM descargas d
  CROSS JOIN params
)
SELECT
  DATE_TRUNC('week', event_ts) AS semana,
  pos_id,
  COUNT(*) AS descargas,
  SUM(CASE WHEN tuvo_compra THEN 1 ELSE 0 END) AS descargas_con_compra,
  ROUND(100.0 * SUM(CASE WHEN tuvo_compra THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS pct_descargas_con_compra
FROM descarga_con_compra
GROUP BY 1, 2
ORDER BY 1, 2;
