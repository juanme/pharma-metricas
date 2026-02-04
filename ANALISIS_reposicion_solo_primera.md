# Análisis: reposición = solo la primera compra posterior

## Qué muestra hoy el query (General_202602040906.csv)

Para cada **falta** (ean + order_id_falta + POS), el query une con **todas** las órdenes del mismo POS donde ese EAN aparece dentro de la ventana de 10 días. Eso genera **varias filas por falta** cuando el POS compra ese producto más de una vez en ese período.

### Ejemplo 1: EAN 0000000000114, order_id_falta 397325, POS 501

| order_id_recompra | fecha_pedido_recompra | dias_hasta_recompra |
|-------------------|------------------------|---------------------|
| 397940            | 2026-01-03 16:01:51   | 1                   |
| 399145            | 2026-01-06 16:58:03   | 4                   |
| 399708            | 2026-01-07 15:36:37   | 5                   |
| 400366            | 2026-01-08 15:57:05   | 6                   |
| 400934            | 2026-01-09 15:25:53   | 7                   |
| 401491            | 2026-01-10 14:47:00   | 8                   |
| 401513            | 2026-01-10 15:08:39   | 8                   |
| 401516            | 2026-01-10 15:10:34   | 8                   |

**8 filas** para una sola falta. La única que debería contar como **reposición** de esa falta es la **primera**: 397940 (día 1). El resto son compras normales del producto una vez que ya repusieron.

### Ejemplo 2: EAN 0000077951823, order_id_falta 397594, POS 624

Aparecen **10 filas** (órdenes 398079, 398080, 398081, 398777, …). La primera recompra es 398079 el 2026-01-04 (día 2). Solo esa es reposición de la falta del pedido 397594; las demás son compras posteriores del mismo producto.

---

## Comportamiento deseado

- **Una falta** (ean + order_id_falta + point_of_sale_id) se considera **reposta** la **primera vez** que el mismo POS compra ese EAN en otro pedido dentro de la ventana (p. ej. 10 días).
- Después de esa primera compra, las siguientes compras del mismo producto **no** son reposición de esa falta; son consumo/reabastecimiento normal.
- Por tanto: **una fila por falta** (o cero si no hubo recompra en la ventana), mostrando solo la **primera** recompra (order_id_recompra, fecha, días, cantidad de esa orden).

---

## Conclusión

- **Problema:** El query actual no limita por “primera recompra”; une con todas las compras del producto en la ventana y por eso multiplica filas.
- **Ajuste a hacer:** Por cada (ean, order_id_falta, point_of_sale_id), quedarse solo con la recompra cuya **fecha de pedido es la mínima** dentro del rango (fecha_falta, fecha_falta + 10 días). En el resultado final debe haber como máximo **una fila por falta**, con los datos de esa primera recompra.

Cuando quieras, el siguiente paso es modificar el query para implementar este criterio (por ejemplo con subconsulta que calcule `MIN(o_recompra.created_at)` por falta y un JOIN que deje solo esa fila).
