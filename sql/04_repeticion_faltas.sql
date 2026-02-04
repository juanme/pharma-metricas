-- 4) Repeticion de faltas por producto antes de compra

WITH faltas AS (
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
falta_con_cierre AS (
  SELECT
    f.pos_id,
    f.ean,
    f.falta_ts,
    (
      SELECT MIN(c.compra_ts)
      FROM compras c
      WHERE c.pos_id = f.pos_id
        AND c.ean = f.ean
        AND c.compra_ts > f.falta_ts
    ) AS cierre_ts
  FROM faltas f
),
faltas_por_ciclo AS (
  SELECT
    pos_id,
    ean,
    cierre_ts,
    COUNT(*) AS faltas_en_ciclo
  FROM falta_con_cierre
  WHERE cierre_ts IS NOT NULL
  GROUP BY 1, 2, 3
)
SELECT
  AVG(faltas_en_ciclo)::numeric(10,2) AS promedio_faltas_antes_de_compra,
  COUNT(*) AS ciclos_con_compra
FROM faltas_por_ciclo;
