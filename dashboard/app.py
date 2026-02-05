"""
Dashboard Faltas y Reposición — Validación de impacto (puntos 1, 2, 3, 4 y 6).
Lee el CSV exportado del query y muestra las métricas.
"""
import os
import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go

CSV_DIR = os.path.join(os.path.dirname(__file__), "..", "csv")
DATA_CSV = os.path.join(os.path.dirname(__file__), "data", "faltas_recompra.csv")


def load_data(path: str) -> pd.DataFrame:
    df = pd.read_csv(path)
    # Asegurar tipos numéricos
    for col in ("reintento_reposicion", "compra_efectiva", "veces_falta_antes"):
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")
    return df


def list_csv_files(csv_dir: str) -> list:
    if not os.path.isdir(csv_dir):
        return []
    files = [f for f in os.listdir(csv_dir) if f.lower().endswith(".csv")]
    files.sort(key=lambda f: os.path.getmtime(os.path.join(csv_dir, f)), reverse=True)
    return files


def main():
    st.set_page_config(page_title="Faltas y Reposición", layout="wide")
    st.title("Dashboard — Faltas y Reposición")
    st.caption("Métricas 1, 2, 3, 4 y 6 — Validación de impacto")

    # Cargar CSV: listado en directorio o subida
    csv_files = list_csv_files(CSV_DIR)
    selected_csv = None
    if csv_files:
        selected_csv = st.sidebar.selectbox("CSV disponibles", csv_files, index=0)
    uploaded = st.sidebar.file_uploader("Subir CSV de faltas/recompra", type=["csv"])
    if uploaded:
        df = load_data(uploaded)
        st.sidebar.success(f"Filas cargadas: {len(df):,}")
    elif selected_csv:
        csv_path = os.path.join(CSV_DIR, selected_csv)
        df = load_data(csv_path)
        st.sidebar.success(f"CSV seleccionado: {selected_csv} ({len(df):,} filas)")
    elif os.path.isfile(DATA_CSV):
        df = load_data(DATA_CSV)
        st.sidebar.success(f"CSV por defecto (fallback): {len(df):,} filas")
    else:
        st.warning("No hay CSV. Colocá archivos en la carpeta `csv/` del proyecto o subí un archivo desde el panel.")
        st.stop()

    # Filtros opcionales
    with st.sidebar.expander("Filtros"):
        tipos = ["Todos"] + sorted(df["tipo_producto"].dropna().unique().tolist())
        tipo_sel = st.selectbox("Tipo producto", tipos)
        if tipo_sel != "Todos":
            df = df[df["tipo_producto"] == tipo_sel].copy()

    # --- Punto 1: Tasa de reintento ---
    st.header("1. Tasa de reintento de reposición")
    total_pedidos = df["order_id_falta"].nunique()
    pedidos_reintento = df[df["reintento_reposicion"] == 1]["order_id_falta"].nunique()
    tasa_reintento = (pedidos_reintento / total_pedidos * 100) if total_pedidos else 0
    c1, c2, c3 = st.columns(3)
    with c1:
        st.metric("Pedidos con faltas", f"{total_pedidos:,}")
    with c2:
        st.metric("Pedidos con al menos un reintento", f"{pedidos_reintento:,}")
    with c3:
        st.metric("Tasa de reintento", f"{tasa_reintento:.1f}%")

    # --- Punto 2: Tasa de faltas recuperadas ---
    st.header("2. Tasa de faltas recuperadas")
    total_faltas = len(df)
    recuperadas = (df["compra_efectiva"] == 1).sum()
    tasa_recup = (recuperadas / total_faltas * 100) if total_faltas else 0
    c1, c2, c3 = st.columns(3)
    with c1:
        st.metric("Total faltas", f"{total_faltas:,}")
    with c2:
        st.metric("Faltas recuperadas (compra efectiva)", f"{recuperadas:,}")
    with c3:
        st.metric("Tasa recuperadas", f"{tasa_recup:.1f}%")

    by_tipo = df.groupby("tipo_producto", dropna=False).agg(
        total=("compra_efectiva", "count"),
        recuperadas=("compra_efectiva", lambda s: (s == 1).sum()),
    ).assign(tasa=lambda x: (x["recuperadas"] / x["total"] * 100).round(1))
    st.subheader("Por tipo de producto")
    by_tipo = by_tipo.rename(
        columns={
            "total": "faltas_totales",
            "recuperadas": "faltas_recuperadas",
            "tasa": "tasa_recuperadas_pct",
        }
    )
    st.dataframe(by_tipo, use_container_width=True, hide_index=True)
    fig2 = px.bar(
        by_tipo.reset_index(),
        x="tipo_producto",
        y="tasa_recuperadas_pct",
        title="Tasa de faltas recuperadas por tipo",
        labels={"tipo_producto": "Tipo producto", "tasa_recuperadas_pct": "Tasa (%)"},
    )
    st.plotly_chart(fig2, use_container_width=True)

    # --- Punto 3: Timing de recuperación ---
    st.header("3. Timing de recuperación")
    con_recompra = df[df["reintento_reposicion"] == 1].dropna(subset=["bucket_timing_recompra"])
    con_recompra = con_recompra[con_recompra["bucket_timing_recompra"].astype(str).str.len() > 0]
    if len(con_recompra):
        order_bucket = ["< 6 h", "6-12 h", "12-24 h", "24-48 h", "48 h+"]
        dist = con_recompra["bucket_timing_recompra"].value_counts().reindex(order_bucket).fillna(0)
        fig3 = px.bar(
            x=dist.index,
            y=dist.values,
            title="Distribución: tiempo hasta recompra",
            labels={"x": "Bucket", "y": "Cantidad"},
        )
        st.plotly_chart(fig3, use_container_width=True)
    else:
        st.info("No hay datos de timing (recompras con bucket).")

    # --- Punto 4: Repetición de faltas por producto ---
    st.header("4. Repetición de faltas por producto")
    con_compra_efectiva = df[df["compra_efectiva"] == 1]
    if len(con_compra_efectiva):
        prom_veces = con_compra_efectiva["veces_falta_antes"].mean()
        st.metric("Promedio de veces que el EAN apareció como falta antes de compra efectiva", f"{prom_veces:.2f}")
        st.caption("Calculado sobre filas con compra_efectiva = 1.")
    else:
        st.info("No hay filas con compra efectiva para calcular el promedio.")

    # --- Punto 6: Abandono ---
    st.header("6. Abandono de faltas")
    sin_recompra = (df["reintento_reposicion"] == 0).sum()
    tasa_abandono = (sin_recompra / total_faltas * 100) if total_faltas else 0
    c1, c2, c3 = st.columns(3)
    with c1:
        st.metric("Faltas sin recompra en ventana", f"{sin_recompra:,}")
    with c2:
        st.metric("Total faltas", f"{total_faltas:,}")
    with c3:
        st.metric("Tasa abandono", f"{tasa_abandono:.1f}%")


if __name__ == "__main__":
    main()
