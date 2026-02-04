## Modelo de datos esperado (minimo)

Este proyecto asume tres fuentes principales: ordenes, items de orden y catalogo
de productos. Ajusta nombres y campos segun tu esquema real.

### Tabla `orders`

- `order_id` (string/int)
- `pos_id` (string/int)
- `order_ts` (timestamp)

### Tabla `order_items`

- `order_id` (string/int)
- `pos_id` (string/int)
- `ean` (string/int)
- `qty_requested` (numeric)
- `qty_purchased` (numeric)
- `item_ts` (timestamp, opcional)

### Tabla `products`

- `ean` (string/int)
- `product_type` (string)  -- valores esperados: `Medicamentos`, `OTC`

### Tabla `events` (Etapa 2)

Opcional, para friccion:

- `event_id` (string/int)
- `pos_id` (string/int)
- `event_name` (string)  -- `download__missing_items`
- `event_ts` (timestamp)
- `payload` (json, opcional) -- para mapear EAN descargados

### Tabla `stage3_events` (Etapa 3)

Opcional, para ex post:

- `pos_id` (string/int)
- `ean` (string/int)
- `event_name` (string)  -- `missing_pool_entered`, `ready_to_buy`, `missing_closed`
- `event_ts` (timestamp)
