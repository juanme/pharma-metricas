# Análisis: Validación de impacto vs. query de recompra

Documento que cruza los requisitos del doc **Validación de impacto** (métricas de producto) con lo que aporta el query actual de recompra en mismo POS. Sirve para ver qué análisis se pueden hacer ya y qué datos o queries adicionales hacen falta.

---

## Qué aporta el query actual

El query `query_recompra_mismo_pos.sql` devuelve, para un periodo de pedidos con falta (1–2 días) y una ventana de 10 días:

- **ean**, **order_id_falta**, **cantidad_solicitada_falta**
- **point_of_sale_id**, **nombre_pos**
- **tipo_producto** (MEDICINAL / NO MEDICINAL según `api_products.iva_percentage`)
- **fecha_pedido_falta**, **order_id_recompra**, **fecha_pedido_recompra**
- **dias_hasta_recompra**, **cantidad_recompra**

Es decir: **solo las faltas que tuvieron al menos una “recompra”** (el mismo EAN vuelve a aparecer en otro pedido del mismo POS dentro de la ventana), mostrando solo la **primera** de esas recompras.

---

## 1. Tasa de reintento de reposición

**Pregunta:** Cuando un pedido termina con faltas, ¿la farmacia vuelve a intentar pedir esos productos en compras posteriores?

**Métrica:** % de pedidos con faltas en los que al menos uno de los EAN en falta vuelve a aparecer en un pedido posterior del mismo POS (dentro de X días), aunque no se logre comprar.

**Con el query actual:** Se tienen todas las **faltas que sí tuvieron** al menos un pedido posterior del mismo POS con ese EAN (reintento).

**Falta:** El **denominador**: lista de **todos los pedidos con faltas** en el periodo (o todas las faltas) para calcular  
`pedidos_con_reintento / total_pedidos_con_faltas`. Hoy solo se tienen los que tienen reintento, no los que no.

---

## 2. Tasa de faltas recuperadas

**Pregunta:** Del total de productos en falta, ¿cuántos se terminan comprando?

**Métrica:** (productos en falta que luego se compran) / (total de productos en falta). Separado por Medicamentos vs OTC.

**Con el query actual:** Se tiene **tipo_producto** (MEDICINAL / NO MEDICINAL) y la **primera vez** que el EAN reaparece en un pedido.

**Falta:**
- **Compra efectiva:** en el pedido de “recompra” hay que poder saber si ese EAN **se compró** (p. ej. que no figure en `order_shortages` de ese pedido, o que figure con `purchased_quantity` ≥ lo pedido), no solo que figure en el pedido.
- **Denominador:** total de faltas en el periodo para el %.

---

## 3. Timing de recuperación (ventana óptima)

**Pregunta:** ¿En cuánto tiempo se recuperan las faltas que sí se compran?

**Métrica:** Distribución del tiempo entre generación de la falta y compra posterior del mismo EAN (buckets: &lt;6 h, 6–12 h, 12–24 h, 24–48 h, 48 h+).

**Con el query actual:** Se tienen **fecha_pedido_falta**, **fecha_pedido_recompra** y **dias_hasta_recompra**. Se puede armar la distribución en días y aproximar horas con la diferencia de timestamps.

**Falta (solo si se exige “compra efectiva”):** Fecha de **compra efectiva** en lugar de fecha del pedido donde reaparece. Si se acepta “fecha del pedido donde reaparece”, con lo actual alcanza.

---

## 4. Repetición de faltas por producto

**Pregunta:** ¿Un mismo producto vuelve a aparecer en faltas antes de ser comprado?

**Métrica:** Promedio de veces que un EAN aparece como falta antes de “cerrarse” (compra o caducar).

**Con el query actual:** No se puede; el query da “una falta → primera recompra”, no la **secuencia de faltas** por EAN+POS hasta compra o caducidad.

**Falta:** Otra fuente o query que cuente **eventos de falta consecutivos** por (EAN, POS) hasta compra o fin de ventana.

---

## 5. Fricción del flujo actual (Etapa 2)

**Pregunta:** ¿Cuánto esfuerzo operativo implica hoy recuperar faltas?

**Métricas:** Promedio de descargas de archivo de faltas por POS/semana. % de descargas que no terminan en compra. Evento: `download__missing_items`.

**Con el query actual:** No aplica; eso viene de **analytics/GA** (eventos de descarga), no del query de faltas/recompras.

**Falta:** Datos de eventos (GA o tabla de eventos) y su cruce con compras.

---

## 6. Abandono de faltas

**Pregunta:** ¿Cuántas faltas nunca se recuperan?

**Métrica:** % de productos en falta sin compra posterior dentro de N días (7/14).

**Con el query actual:** Solo se tienen las faltas **con** recompra. No se tienen las que **no** tuvieron compra posterior.

**Falta:** Lista de **todas** las faltas del periodo y señal de “sin compra posterior en N días”, o un query que las devuelva explícitamente.

---

## 7. Métricas de éxito para Etapa 3 (ex post)

**Preguntas:** ¿Sube la tasa de recuperación? ¿Baja el tiempo hasta la compra? ¿Disminuye la fricción manual?

**Métricas:** % en pool vivo, “Listo para comprar”, compra, tiempo de cierre. Comparación Etapa 2 vs Etapa 3.

**Con el query actual:** No aplica; depende de **estados y eventos de Etapa 3**, no del query de recompras.

**Falta:** Datos de estados/eventos de la Etapa 3.

---

## Resumen: qué falta para cubrir el doc de Validación de impacto

| Punto del doc | ¿Se puede con el resultado actual? | Dato/query que falta |
|---------------|------------------------------------|------------------------|
| **1. Reintento** | Parcial (solo los que sí reintentan) | Total de pedidos con faltas (o de faltas) en el periodo para el denominador. |
| **2. Faltas recuperadas** | Parcial (tipo producto y recompra) | (a) Indicador de **compra efectiva** en el pedido de recompra; (b) total de faltas (denominador). |
| **3. Timing** | Sí (días y aproximable a horas) | Solo si se exige “fecha de compra efectiva” en lugar de “fecha de pedido”. |
| **4. Repetición por producto** | No | Conteo de **faltas consecutivas** por EAN+POS hasta compra/caducidad (otro query/lógica). |
| **5. Fricción Etapa 2** | No | Eventos de descarga (GA/DB). |
| **6. Abandono** | No (solo con recompra) | **Faltas sin recompra** en N días (mismo periodo y ventana). |
| **7. Etapa 3** | No | Datos de Etapa 3. |

---

## Conclusión

- Con el resultado del query actual se puede avanzar en **1 (reintento)** y **3 (timing)** si se agrega el total de pedidos/faltas; y en **2** si además se incorpora **compra efectiva** y total de faltas.
- Para **4, 5, 6 y 7** hace falta otro dato u otro query: faltas sin recompra, secuencia de faltas por producto, eventos de descarga, datos de Etapa 3.

---

*Documento generado a partir del análisis del doc Validación de impacto y del query `query_recompra_mismo_pos.sql`.*
