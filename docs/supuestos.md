## Supuestos y decisiones

1) **Compra posterior**: una compra se considera posterior si ocurre en una
   orden con `order_ts` > `falta_ts` para el mismo `pos_id` y `ean`.
2) **Fuente de tiempo**: se usa `orders.order_ts` como momento de compra y
   `orders.order_ts` del pedido con faltas como momento de falta.
3) **Falta**: se define cuando `qty_requested > qty_purchased` en `order_items`.
4) **Ventanas**: por defecto se usa `window_days = 7` para recupero y
   `abandon_days = 14` para abandono. Ajustar segun negocio.
5) **Producto**: se segmenta por `products.product_type` con valores
   `Medicamentos` y `OTC`. Ajustar mapeos si difieren.
6) **Etapa 2 (friccion)**: se asume evento `download__missing_items`. La
   vinculacion a EAN faltantes puede requerir parsing de `payload`.
7) **Etapa 3**: se asume tabla de eventos con estados; adaptar a tu tracking.
