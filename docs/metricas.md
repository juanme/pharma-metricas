## Metricas definidas

1) **Intento de recupero**
   - % de pedidos con faltas que luego compran al menos un EAN faltante.
   - Consulta: `sql/01_intento_recupero.sql`

2) **Tasa de recupero**
   - % de productos en falta que se compran luego.
   - Segmentado por tipo de producto.
   - Consulta: `sql/02_tasa_recupero.sql`

3) **Timing de recupero**
   - Distribucion de tiempo desde falta hasta compra.
   - Buckets: <6h, 6-12h, 12-24h, 24-48h, >48h.
   - Consulta: `sql/03_timing_recupero.sql`

4) **Repeticion de faltas por producto**
   - Promedio de veces que un EAN aparece como falta antes de comprarse.
   - Consulta: `sql/04_repeticion_faltas.sql`

5) **Friccion del flujo actual (Etapa 2)**
   - Descargas de archivo de faltas por POS / semana.
   - % de descargas sin compra posterior.
   - Consulta: `sql/05_friccion_etapa2.sql`

6) **Abandono de faltas**
   - % de productos en falta sin compra posterior en N dias.
   - Consulta: `sql/06_abandono_faltas.sql`

7) **Metricas de exito (Etapa 3)**
   - Pool vivo, listo para comprar, compra final, tiempo de cierre.
   - Comparacion pre vs post `stage3_start_date`.
   - Consulta: `sql/07_exito_etapa3.sql`
