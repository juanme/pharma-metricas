# Modelo de datos: Análisis de Faltas y Reposición

Documento que describe las tablas y relaciones necesarias para analizar faltas (shortages) y reposición en el sistema.

---

## Diagrama de relaciones

```
orders ──┬── order_shortages ── order_products
         │         │                    │
         │         │                    └── api_products (iva → medicinal/no medicinal)
         │         │
         └── order_products
         │
         └── points_of_sale (point_of_sale_id)
```

---

## Tablas

### 1. `order_shortages` (faltas por pedido)

Registra las faltas de productos en cada línea de pedido: cuánto se pidió, cuánto se compró y cuánto faltó.

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | bigint(20) unsigned | PK, auto-increment |
| `ean` | varchar(191) | Código de barras (EAN) del producto |
| `requested_quantity` | int(11) | Cantidad solicitada |
| `purchased_quantity` | int(11) | Cantidad efectivamente comprada (default 0) |
| `shortage_quantity` | int(11) | Cantidad en falta (default 0) |
| `description` | text | Descripción opcional |
| `order_id` | int(10) unsigned | **FK → orders.id** |
| `order_product_id` | int(10) unsigned | **FK → order_products.id** |
| `order_shortage_type_id` | int(10) unsigned | Tipo de falta |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

**Uso en el análisis:** base de las métricas de faltas (unidades faltantes, líneas con falta, etc.).

---

### 2. `order_products` (líneas de pedido)

Cada fila es un producto dentro de un pedido (cantidad pedida, barcode, descripción).

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | int(10) unsigned | PK, auto-increment |
| `barcode` | varchar(191) | Código de barras principal |
| `alternative_barcode1` … `alternative_barcode4` | varchar(20) | Códigos alternativos |
| `troquel` | int(10) unsigned | Troquel |
| `description` | varchar(191) | Descripción del producto |
| `quantity` | decimal(13,3) | Cantidad en el pedido |
| `order_id` | int(10) unsigned | **FK → orders.id** |
| `product_id` | bigint(20) unsigned | Referencia a producto (si existe) |
| `is_recommended` | tinyint(4) | Recomendado (0/1) |
| `is_included` | tinyint(4) | Incluido (0/1) |
| `included_at` | timestamp | |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |
| `deleted_at` | timestamp | Soft delete |

**Relaciones:**  
- `order_shortages.order_product_id` → `order_products.id`  
- `api_products.order_product_id` → `order_products.id`

---

### 3. `api_products` (catálogo / datos de producto por pedido)

Datos de producto asociados a la línea de pedido (precios, IVA, disponibilidad).  
**Clasificación medicinal / no medicinal:** según IVA.

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | int(10) unsigned | PK |
| `barcode` | varchar(191) | Código de barras |
| `normalized_barcode` | varchar(13) | Código normalizado |
| `troquel` | int(10) unsigned | Troquel |
| `description` | varchar(191) | Descripción |
| `price_with_discount` | decimal(13,3) | Precio con descuento |
| `public_price` | decimal(13,3) | Precio público |
| **`iva_percentage`** | **decimal(4,2)** | **% IVA → define medicinal vs no medicinal** |
| `available` | tinyint(1) | Disponible (0/1) |
| `mincant` | int(11) | Cantidad mínima |
| `maxcant` | int(11) | Cantidad máxima |
| `drug_manufacturer_id` | int(10) unsigned | Laboratorio |
| `order_product_id` | int(10) unsigned | **FK → order_products.id** |
| `order_id` | int(10) unsigned | order_id de contexto |
| `ca_list_id` | int(10) unsigned | Lista CA |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

**Regla para el análisis:**

- **Producto MEDICINAL:** `iva_percentage = 0` (o NULL tratado como 0).
- **Producto NO MEDICINAL:** `iva_percentage > 0`.

El análisis de faltas y reposición debe desglosar siempre por **MEDICINAL** vs **NO MEDICINAL** usando esta regla.

---

### 4. `orders` (pedidos)

Cabecera del pedido; permite enlazar faltas con punto de venta y cliente.

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | int(10) unsigned | PK |
| `user_id` | int(10) unsigned | Usuario |
| **`point_of_sale_id`** | **int(10) unsigned** | **FK → points_of_sale.id** |
| `status_id` | int(10) unsigned | Estado del pedido |
| `cart_id` | int(10) unsigned | Carrito |
| `priority_id` | int(10) unsigned | Prioridad |
| `credit_id` | bigint(20) unsigned | Crédito |
| `tolerance` | decimal(5,2) | Tolerancia |
| `distribution_id` | int(10) unsigned | Distribución |
| `d_tolerance` | decimal(5,2) | Tolerancia distribución |
| `service_id` | int(10) unsigned | Servicio |
| `is_automatic` | tinyint(1) | Pedido automático (0/1) |
| `file_name` | varchar(191) | Nombre de archivo |
| `created_at` | timestamp | Fecha de creación del pedido |
| `updated_at` | timestamp | |

**Relación:** `order_shortages.order_id` → `orders.id` → con esto se obtiene `point_of_sale_id` para cada falta.

---

### 5. `points_of_sale` (puntos de venta)

Datos del punto de venta (farmacia/sucursal) para segmentar el análisis por ubicación o cliente.

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | int(10) unsigned | PK |
| `name` | varchar(191) | Nombre del punto de venta |
| `address` | varchar(191) | Dirección |
| `latitude` | decimal(11,8) | Latitud |
| `longitude` | decimal(11,8) | Longitud |
| `geohash` | varchar(600) | Geohash |
| `timezone` | varchar(191) | Zona horaria |
| **`client_id`** | **int(10) unsigned** | **Cliente (agrupación útil para análisis)** |
| `access_status_id` | int(10) unsigned | Estado de acceso |
| `status_id` | int(10) unsigned | Estado |
| `priority_id` | int(10) unsigned | Prioridad |
| `tolerance` | decimal(5,2) | Tolerancia |
| `distribution_id` | int(10) unsigned | Distribución |
| `service_id` | int(10) unsigned | Servicio |
| `company_name` | varchar(191) | Razón social |
| `tax_id` | varchar(191) | CUIT/CUIL/etc. |
| … | … | (otros campos de negocio) |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |
| `deleted_at` | datetime | Soft delete |

**Relación:** `orders.point_of_sale_id` → `points_of_sale.id`.

---

## Consulta base sugerida para el análisis

Para unir todo lo necesario en un solo dataset (ej. para BI o exportar a CSV):

- **Desde:** `order_shortages`
- **JOIN** `order_products` ON `order_shortages.order_product_id = order_products.id`
- **JOIN** `orders` ON `order_shortages.order_id = orders.id`
- **JOIN** `points_of_sale` ON `orders.point_of_sale_id = points_of_sale.id`
- **LEFT JOIN** `api_products` ON `order_shortages.order_product_id = api_products.order_product_id`  
  (LEFT por si no siempre hay registro en api_products)

Campos típicos para el análisis:

- De **order_shortages:** `ean`, `requested_quantity`, `purchased_quantity`, `shortage_quantity`, `order_shortage_type_id`, `created_at`
- De **orders:** `created_at` (fecha del pedido), `point_of_sale_id`
- De **points_of_sale:** `name`, `client_id`, `company_name`
- De **api_products:** `iva_percentage` → derivar **tipo_producto**: `MEDICINAL` si `iva_percentage = 0`, sino `NO MEDICINAL`

Con esto se puede analizar faltas y reposición por fecha, por punto de venta, por cliente y por tipo de producto (medicinal / no medicinal).

---

## Resumen de FKs para el análisis

| Tabla origen      | Campo            | Tabla destino   | Campo |
|-------------------|------------------|-----------------|-------|
| order_shortages   | order_id         | orders          | id    |
| order_shortages   | order_product_id | order_products  | id    |
| order_products    | order_id         | orders          | id    |
| orders            | point_of_sale_id | points_of_sale  | id    |
| api_products      | order_product_id | order_products  | id    |

---

*Documento generado para el análisis de faltas compradas y reposición. Última actualización: febrero 2025.*
