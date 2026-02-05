## pharma-metricas

Proyecto de analisis para validar recupero de faltas y reintento de reposicion.
Incluye definiciones, queries SQL (MySQL 5.7) y un dashboard opcional.

### Contenido

- `docs/`: definiciones, supuestos y modelo de datos.
- `sql/`: queries base por metrica.
- `query_recompra_mismo_pos.sql`: query principal para analisis de reintento.
- `dashboard/`: app y requisitos (ver `dashboard/README_INFRAESTRUCTURA.md`).
- `data/`: datasets de ejemplo o exportados.

### Uso rapido

1) Ajustar ventanas de fechas y `@window_days` en las queries.
2) Ejecutar queries en MySQL 5.7.
3) Exportar resultados para analisis y dashboard.

### Notas

- Reintento de reposicion: EAN faltante aparece en un pedido posterior del mismo POS.
- Faltas recuperadas: EAN faltante comprado en ventana X por el mismo POS.
