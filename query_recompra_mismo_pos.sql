-- =============================================================================
-- Faltas y recompra (mismo POS) — para Validación de impacto puntos 1 a 4
-- =============================================================================
-- Incluye TODAS las faltas del periodo (con y sin recompra).
-- Recompra = primera vez que el EAN reaparece en otro pedido del mismo POS (ventana 10 días).
-- Columnas para: reintento (1), tasa recuperadas (compra_efectiva), timing (horas/bucket), repetición (veces_falta_antes).
--
-- CAMBIAR A MANO:
--   - FECHA_INICIO y FECHA_FIN en todos los WHERE / subconsulta (periodo de pedidos con falta).
--   - Los "10" en DATE_ADD (ventana de días para recompra).
-- =============================================================================

SELECT
    os.ean,
    os.order_id                    AS order_id_falta,
    os.requested_quantity           AS cantidad_solicitada_falta,
    o_falta.point_of_sale_id       AS point_of_sale_id,
    pos.name                       AS nombre_pos,
    CASE WHEN COALESCE(ap.iva_percentage, 0) = 0 THEN 'MEDICINAL' ELSE 'NO MEDICINAL' END AS tipo_producto,
    o_falta.created_at             AS fecha_pedido_falta,
    -- Punto 1: reintento = este EAN reapareció en un pedido posterior del mismo POS
    CASE WHEN primera.order_id_primera_recompra IS NOT NULL THEN 1 ELSE 0 END AS reintento_reposicion,
    o_recompra.id                  AS order_id_recompra,
    o_recompra.created_at           AS fecha_pedido_recompra,
    DATEDIFF(o_recompra.created_at, o_falta.created_at) AS dias_hasta_recompra,
    TIMESTAMPDIFF(HOUR, o_falta.created_at, o_recompra.created_at) AS horas_hasta_recompra,
    -- Bucket para timing (punto 3): <6h, 6-12h, 12-24h, 24-48h, 48h+
    CASE
        WHEN o_recompra.created_at IS NULL THEN NULL
        WHEN TIMESTAMPDIFF(HOUR, o_falta.created_at, o_recompra.created_at) < 6 THEN '< 6 h'
        WHEN TIMESTAMPDIFF(HOUR, o_falta.created_at, o_recompra.created_at) < 12 THEN '6-12 h'
        WHEN TIMESTAMPDIFF(HOUR, o_falta.created_at, o_recompra.created_at) < 24 THEN '12-24 h'
        WHEN TIMESTAMPDIFF(HOUR, o_falta.created_at, o_recompra.created_at) < 48 THEN '24-48 h'
        ELSE '48 h+'
    END AS bucket_timing_recompra,
    op_recompra.quantity           AS cantidad_recompra,
    -- Punto 2: compra efectiva = en el pedido de recompra ese EAN se compró (no volvió a faltar)
    CASE
        WHEN o_recompra.id IS NULL THEN NULL
        WHEN os_recompra.id IS NULL OR COALESCE(os_recompra.shortage_quantity, 0) = 0 THEN 1
        ELSE 0
    END AS compra_efectiva,
    -- Punto 4: veces que este EAN apareció como falta (en órdenes del mismo POS) hasta esta orden
    (
        SELECT COUNT(DISTINCT o2.id)
        FROM order_shortages os2
        INNER JOIN orders o2 ON o2.id = os2.order_id
        INNER JOIN order_products op2
            ON op2.id = os2.order_product_id
            AND op2.quantity > 0
            AND op2.deleted_at IS NULL
        INNER JOIN points_of_sale pos2
            ON pos2.id = o2.point_of_sale_id
        INNER JOIN clients c2
            ON c2.id = pos2.client_id
        WHERE os2.ean = os.ean
          AND o2.point_of_sale_id = o_falta.point_of_sale_id
          AND o2.status_id = 2
          AND c2.is_demo = 0
          AND c2.deleted_at IS NULL
          AND pos2.deleted_at IS NULL
          AND o2.created_at BETWEEN '2026-01-01 00:00:00' AND o_falta.created_at
    ) AS veces_falta_antes
FROM order_shortages os
INNER JOIN orders o_falta
    ON o_falta.id = os.order_id
INNER JOIN order_products op_falta
    ON op_falta.id = os.order_product_id
    AND op_falta.quantity > 0
    AND op_falta.deleted_at IS NULL
INNER JOIN points_of_sale pos
    ON pos.id = o_falta.point_of_sale_id
INNER JOIN clients c
    ON c.id = pos.client_id
LEFT JOIN api_products ap
    ON ap.order_product_id = os.order_product_id
LEFT JOIN (
    SELECT
        os_inner.ean,
        os_inner.order_id          AS order_id_falta,
        o_falta_inner.point_of_sale_id,
        o_falta_inner.created_at   AS fecha_pedido_falta,
        MIN(o_recompra_inner.created_at) AS primera_fecha_recompra,
        SUBSTRING_INDEX(GROUP_CONCAT(o_recompra_inner.id ORDER BY o_recompra_inner.created_at, o_recompra_inner.id), ',', 1) AS order_id_primera_recompra
    FROM order_shortages os_inner
    INNER JOIN orders o_falta_inner
        ON o_falta_inner.id = os_inner.order_id
    INNER JOIN order_products op_falta_inner
        ON op_falta_inner.id = os_inner.order_product_id
        AND op_falta_inner.quantity > 0
        AND op_falta_inner.deleted_at IS NULL
    INNER JOIN points_of_sale pos_inner
        ON pos_inner.id = o_falta_inner.point_of_sale_id
    INNER JOIN clients c_inner
        ON c_inner.id = pos_inner.client_id
    INNER JOIN orders o_recompra_inner
        ON o_recompra_inner.point_of_sale_id = o_falta_inner.point_of_sale_id
        AND o_recompra_inner.id <> os_inner.order_id
        AND o_recompra_inner.created_at > o_falta_inner.created_at
        AND o_recompra_inner.created_at <= DATE_ADD(o_falta_inner.created_at, INTERVAL 10 DAY)
        AND o_recompra_inner.status_id = 2
    INNER JOIN order_products op_inner
        ON op_inner.order_id = o_recompra_inner.id
        AND op_inner.quantity > 0
        AND op_inner.deleted_at IS NULL
        AND (
            op_inner.barcode = os_inner.ean
            OR op_inner.alternative_barcode1 = os_inner.ean
            OR op_inner.alternative_barcode2 = os_inner.ean
            OR op_inner.alternative_barcode3 = os_inner.ean
            OR op_inner.alternative_barcode4 = os_inner.ean
        )
    WHERE o_falta_inner.status_id = 2
      AND c_inner.is_demo = 0
      AND c_inner.deleted_at IS NULL
      AND pos_inner.deleted_at IS NULL
      AND o_falta_inner.created_at BETWEEN '2026-01-01 00:00:00' AND '2026-01-02 23:59:59'
    GROUP BY os_inner.ean, os_inner.order_id, o_falta_inner.point_of_sale_id, o_falta_inner.created_at
) primera
    ON primera.ean = os.ean
    AND primera.order_id_falta = os.order_id
    AND primera.point_of_sale_id = o_falta.point_of_sale_id
    AND primera.fecha_pedido_falta = o_falta.created_at
LEFT JOIN orders o_recompra
    ON o_recompra.id = primera.order_id_primera_recompra
LEFT JOIN order_products op_recompra
    ON op_recompra.order_id = o_recompra.id
    AND op_recompra.quantity > 0
    AND op_recompra.deleted_at IS NULL
    AND (
        op_recompra.barcode = os.ean
        OR op_recompra.alternative_barcode1 = os.ean
        OR op_recompra.alternative_barcode2 = os.ean
        OR op_recompra.alternative_barcode3 = os.ean
        OR op_recompra.alternative_barcode4 = os.ean
    )
LEFT JOIN order_shortages os_recompra
    ON os_recompra.order_id = o_recompra.id
    AND os_recompra.ean = os.ean
WHERE o_falta.created_at BETWEEN '2026-01-01 00:00:00' AND '2026-01-02 23:59:59'
  AND o_falta.status_id = 2
  AND c.is_demo = 0
  AND c.deleted_at IS NULL
  AND pos.deleted_at IS NULL
ORDER BY os.ean, o_falta.created_at;
