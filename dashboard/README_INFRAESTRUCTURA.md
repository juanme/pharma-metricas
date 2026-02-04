# Infraestructura del dashboard – Faltas y reposición (puntos 1, 2, 3, 4 y 6)

## Cómo ejecutar (con venv, sin pisar tu Python local)

Todo el Python del dashboard corre en un **entorno virtual** dentro de `dashboard/`, así no se mezcla con tu instalación global.

```bash
cd dashboard
python3 -m venv venv
source venv/bin/activate   # En Windows: venv\Scripts\activate
pip install -r requirements.txt
streamlit run app.py
```

Se abre en **http://localhost:8501**. Para salir: `Ctrl+C`. Para desactivar el venv: `deactivate`.

**Datos:** La app busca el CSV en la carpeta padre (`../202602041012.csv`) o en `dashboard/data/faltas_recompra.csv`. También podés subir el archivo desde el panel lateral del dashboard.

---

## Objetivo

Servir un dashboard para visualizar:

- **1** Tasa de reintento de reposición  
- **2** Tasa de faltas recuperadas (por tipo producto)  
- **3** Timing de recuperación (buckets)  
- **4** Repetición de faltas por producto  
- **6** Abandono de faltas  

---

## Qué hace falta

### 1. Datos de entrada

- **Archivo:** el CSV resultante del query (ej. `202602041012.csv`), con las columnas que ya tenés.
- **Ubicación:** el dashboard debe poder leer ese CSV (ruta relativa desde la carpeta del dashboard, o ruta configurable).
- **Actualización:** 
  - **Opción A (simple):** el dashboard lee el CSV estático; para actualizar, se vuelve a exportar el CSV y se refresca la página (o se recarga el dato).
  - **Opción B (avanzada):** el backend ejecuta el query contra MySQL y sirve JSON; el dashboard consume esa API. Requiere conexión a la DB y un pequeño backend.

Para arrancar, alcanza con **Opción A** (CSV estático).

---

### 2. Stack técnico (recomendado para arrancar)

- **Frontend del dashboard:** una sola aplicación que lea el CSV y dibuje los gráficos.
- **Opciones razonables:**
  - **Streamlit (Python):** un script que lee el CSV, hace los cálculos y muestra cards + gráficos. Se sirve con `streamlit run app.py`. Muy rápido de armar.
  - **HTML + JavaScript:** página estática que carga el CSV (o un JSON generado desde el CSV) y usa una librería de gráficos (Chart.js, Plotly.js, etc.). Se puede servir con cualquier servidor estático (ej. `npx serve`, Python `http.server`, etc.).

Recomendación inicial: **Streamlit** (menos piezas, fácil de correr en local y luego exponer si hace falta).

---

### 3. Estructura de carpeta sugerida

```
dashboard/
├── README_INFRAESTRUCTURA.md   # este doc
├── app.py                      # app Streamlit (o index.html + js si es estático)
├── requirements.txt            # si usás Python (streamlit, pandas, etc.)
├── data/                       # opcional: copia del CSV o symlink
│   └── .gitkeep
└── assets/                     # opcional: estilos, logos
```

- El CSV puede vivir **fuera** de `dashboard/` (por ejemplo en la raíz del proyecto) y la app lee por ruta relativa `../202602041012.csv`, o se copia/symlink a `dashboard/data/`.

---

### 4. Componentes del dashboard (qué tiene que mostrar)

| Punto | Métrica | Qué mostrar |
|------|--------|-------------|
| **1** | Tasa de reintento | Card con % (pedidos con al menos un reintento / total pedidos con faltas). Opcional: tabla o gráfico por POS. |
| **2** | Faltas recuperadas | Card con % global; gráfico de barras o pie por `tipo_producto` (MEDICINAL / NO MEDICINAL). |
| **3** | Timing | Gráfico de barras con distribución por `bucket_timing_recompra` (< 6 h, 6–12 h, …). Opcional: filtro por compra efectiva. |
| **4** | Repetición | Card con promedio de `veces_falta_antes` (ej. solo filas con `compra_efectiva = 1`). Opcional: distribución o por tipo_producto. |
| **6** | Abandono | Card con % de filas con `reintento_reposicion = 0` (sin recompra en ventana). Opcional: por POS o tipo_producto. |

Además:

- **Filtros globales (opcionales):** rango de fechas (si en el futuro el CSV incluye más de un periodo), tipo_producto, POS.
- **Resumen:** una fila de KPIs (cards) arriba y debajo los gráficos por punto.

---

### 5. Cómo “servir” el dashboard

- **Local:**  
  - Streamlit: `streamlit run app.py` → abre en `http://localhost:8501`.  
  - Estático: `npx serve .` o `python -m http.server 8000` en la carpeta del dashboard.
- **Red interna / producción:**  
  - Exponer el mismo proceso (Streamlit o servidor estático) en un puerto y poner detrás de un reverse proxy (Nginx, Caddy) o acceder por IP:puerto.  
  - Si más adelante querés autenticación o HTTPS, se agrega en el proxy o con un servicio tipo Cloudflare.

No hace falta contenedor ni Kubernetes para empezar; con un solo proceso (Streamlit o servidor estático) alcanza.

---

### 6. Checklist de lo que hace falta

- [ ] Definir si los datos entran por **CSV estático** (recomendado al inicio) o por **API/DB** más adelante.
- [ ] Crear la carpeta `dashboard/` y, si usás Python, `requirements.txt` (p. ej. `streamlit`, `pandas`).
- [ ] Implementar la app que: lea el CSV, calcule las métricas de los puntos 1, 2, 3, 4 y 6, y muestre cards + gráficos.
- [ ] Decidir dónde deja el CSV: misma carpeta, `dashboard/data/` o ruta configurable por variable de entorno.
- [ ] Documentar en el README cómo ejecutar (ej. `streamlit run app.py`) y cómo actualizar el CSV.
- [ ] (Opcional) Servir en un puerto estable para acceso en red o detrás de un proxy.

Con esto tenés claro qué hace falta; el siguiente paso sería bajar a código (por ejemplo una app Streamlit que implemente las 5 vistas).
