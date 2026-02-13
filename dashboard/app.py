"""
Dashboard Faltas y Reposición — Validación de impacto (puntos 1, 2, 3, 4 y 6).
Lee el CSV exportado del query y muestra las métricas.
"""
import os
import json
import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go

CSV_DIR = os.path.join(os.path.dirname(__file__), "..", "csv")
COMPARATIVAS_DIR = os.path.join(CSV_DIR, "comparativas")
COMPARATIVAS_RESUMEN = os.path.join(COMPARATIVAS_DIR, "resumen_reintentos.json")
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


def load_comparativas(path: str) -> pd.DataFrame:
    df = pd.read_csv(path)
    if "estado_personalizado" in df.columns:
        df["estado_personalizado"] = df["estado_personalizado"].astype(str).str.strip().str.lower()
    return df


def load_comparativas_reintentos(path: str) -> pd.DataFrame:
    df = pd.read_csv(path)
    for col in ("retry_24h_any", "retry_24h_same_file", "same_file"):
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")
    return df


def load_comparativas_resumen(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def main():
    st.set_page_config(page_title="Faltas y Reposición", layout="wide")
    st.title("Dashboard — Faltas y Reposición")
    st.caption("Métricas 1, 2, 3, 4 y 6 — Validación de impacto")

    reporte = st.sidebar.radio("Reporte", ["Faltas y Reposición", "Comparativas canceladas"])

    if reporte == "Faltas y Reposición":
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
    else:
        comp_files = list_csv_files(COMPARATIVAS_DIR)
        selected_comp = None
        if comp_files:
            selected_comp = st.sidebar.selectbox("CSV comparativas", comp_files, index=0)
        comp_uploaded = st.sidebar.file_uploader("Subir CSV de comparativas", type=["csv"], key="comparativas")
        if comp_uploaded:
            df = load_comparativas(comp_uploaded)
            st.sidebar.success(f"Filas cargadas: {len(df):,}")
        elif selected_comp:
            comp_path = os.path.join(COMPARATIVAS_DIR, selected_comp)
            df = load_comparativas(comp_path)
            st.sidebar.success(f"CSV seleccionado: {selected_comp} ({len(df):,} filas)")
        else:
            st.warning("No hay CSV de comparativas. Colocá archivos en `csv/comparativas/` o subí uno desde el panel.")
            st.stop()

        reintentos_files = [
            f for f in list_csv_files(COMPARATIVAS_DIR)
            if "reintent" in f.lower()
        ]
        selected_reintentos = None
        if reintentos_files:
            selected_reintentos = st.sidebar.selectbox(
                "CSV reintentos (canceladas)",
                reintentos_files,
                index=0,
                key="comparativas_reintentos",
            )
        reintentos_uploaded = st.sidebar.file_uploader(
            "Subir CSV reintentos",
            type=["csv"],
            key="comparativas_reintentos_upload",
        )
        resumen = None
        if os.path.isfile(COMPARATIVAS_RESUMEN):
            resumen = load_comparativas_resumen(COMPARATIVAS_RESUMEN)

        if reintentos_uploaded:
            df_reintentos = load_comparativas_reintentos(reintentos_uploaded)
            st.sidebar.success(f"Reintentos cargados: {len(df_reintentos):,}")
        elif selected_reintentos:
            reintentos_path = os.path.join(COMPARATIVAS_DIR, selected_reintentos)
            df_reintentos = load_comparativas_reintentos(reintentos_path)
            st.sidebar.success(f"CSV reintentos: {selected_reintentos} ({len(df_reintentos):,} filas)")
        else:
            df_reintentos = None

    if reporte == "Faltas y Reposición":
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
        ean_reintentadas = (df["reintento_reposicion"] == 1).sum()
        tasa_reintento_ean = (ean_reintentadas / total_faltas * 100) if total_faltas else 0
        c1, c2, c3, c4, c5 = st.columns(5)
        with c1:
            st.metric("Total faltas (EAN)", f"{total_faltas:,}")
        with c2:
            st.metric("EAN reintentados", f"{ean_reintentadas:,}")
        with c3:
            st.metric("Tasa reintentados", f"{tasa_reintento_ean:.1f}%")
        with c4:
            st.metric("Faltas recuperadas (compra efectiva)", f"{recuperadas:,}")
        with c5:
            st.metric("Tasa recuperadas", f"{tasa_recup:.1f}%")

        by_tipo = df.groupby("tipo_producto", dropna=False).agg(
            total=("compra_efectiva", "size"),
            reintentadas=("reintento_reposicion", lambda s: (s == 1).sum()),
            recuperadas=("compra_efectiva", lambda s: (s == 1).sum()),
        ).assign(
            tasa_reintento=lambda x: (x["reintentadas"] / x["total"] * 100).round(1),
            tasa=lambda x: (x["recuperadas"] / x["total"] * 100).round(1),
        )
        st.subheader("Por tipo de producto")
        by_tipo = by_tipo.rename(
            columns={
                "total": "faltas_totales",
                "reintentadas": "faltas_reintentadas",
                "recuperadas": "faltas_recuperadas",
                "tasa_reintento": "tasa_reintentadas_pct",
                "tasa": "tasa_recuperadas_pct",
            }
        )
        by_tipo = by_tipo.reset_index().rename(columns={"tipo_producto": "tipo_producto"})
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
        con_recompra = df[df["compra_efectiva"] == 1].dropna(subset=["bucket_timing_recompra"])
        con_recompra = con_recompra[con_recompra["bucket_timing_recompra"].astype(str).str.len() > 0]
        if len(con_recompra):
            order_bucket = ["< 6 h", "6-12 h", "12-24 h", "24-48 h", "48 h+"]
            dist = con_recompra["bucket_timing_recompra"].value_counts().reindex(order_bucket).fillna(0)
            fig3 = px.bar(
                x=dist.index,
                y=dist.values,
                title="Distribución: tiempo hasta recompra (compra efectiva)",
                labels={"x": "Bucket", "y": "Cantidad"},
            )
            st.plotly_chart(fig3, use_container_width=True)
        else:
            st.info("No hay datos de timing (compras efectivas con bucket).")

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
    else:
        st.header("Comparativas — Resumen")
        total = df["total_pedidos"].sum()
        canceladas = df.loc[df["estado_personalizado"] == "cancelada", "total_pedidos"].sum()
        abandonadas = df.loc[df["estado_personalizado"] == "abandonada", "total_pedidos"].sum()
        concretadas = df.loc[df["estado_personalizado"] == "compra concretada", "total_pedidos"].sum()
        pct_cancel = (canceladas / total * 100) if total else 0
        pct_aband = (abandonadas / total * 100) if total else 0
        pct_conc = (concretadas / total * 100) if total else 0

        c1, c2, c3, c4 = st.columns(4)
        with c1:
            st.metric("Comparativas totales", f"{total:,}")
        with c2:
            st.metric("Canceladas", f"{canceladas:,}")
        with c3:
            st.metric("Abandonadas", f"{abandonadas:,}")
        with c4:
            st.metric("Concretadas", f"{concretadas:,}")

        st.subheader("% sobre total")
        c1, c2, c3 = st.columns(3)
        with c1:
            st.metric("% Cancelación", f"{pct_cancel:.2f}%")
        with c2:
            st.metric("% Abandono", f"{pct_aband:.2f}%")
        with c3:
            st.metric("% Concreción", f"{pct_conc:.2f}%")

        dist = df.groupby("estado_personalizado", dropna=False)["total_pedidos"].sum().reset_index()
        dist["pct"] = (dist["total_pedidos"] / total * 100).round(2)
        st.subheader("Distribución de estados")
        st.dataframe(dist, use_container_width=True, hide_index=True)
        fig_comp = px.bar(
            dist,
            x="estado_personalizado",
            y="pct",
            title="Distribución de estados (%)",
            labels={"estado_personalizado": "Estado", "pct": "%"},
        )
        st.plotly_chart(fig_comp, use_container_width=True)

        st.header("Canceladas — Reintento con mismo archivo (24h)")
        if resumen:
            c1, c2, c3, c4 = st.columns(4)
            with c1:
                st.metric("Canceladas", f"{resumen.get('cancelled_total', 0):,}")
            with c2:
                st.metric("Reintento <= 24h", f"{resumen.get('retry_24h_any', 0):,}")
            with c3:
                st.metric("Reintento <= 24h mismo archivo", f"{resumen.get('retry_24h_same_file', 0):,}")
            with c4:
                st.metric("% mismo archivo", f"{resumen.get('pct_same_file_over_cancelled', 0):.2f}%")
            st.caption("Fuente: resumen agregado.")
        elif df_reintentos is None or df_reintentos.empty:
            st.info("No hay resumen agregado ni CSV de reintentos cargado.")
        else:
            required_cols = {"retry_24h_any", "retry_24h_same_file"}
            missing_cols = required_cols.difference(df_reintentos.columns)
            if missing_cols:
                st.warning(
                    "El CSV de reintentos no tiene las columnas esperadas: "
                    + ", ".join(sorted(missing_cols))
                )
                return
            cancelled_total = len(df_reintentos)
            retry_24h_any = (df_reintentos["retry_24h_any"] == 1).sum()
            retry_24h_same = (df_reintentos["retry_24h_same_file"] == 1).sum()
            pct_same = (retry_24h_same / cancelled_total * 100) if cancelled_total else 0

            c1, c2, c3, c4 = st.columns(4)
            with c1:
                st.metric("Canceladas", f"{cancelled_total:,}")
            with c2:
                st.metric("Reintento <= 24h", f"{retry_24h_any:,}")
            with c3:
                st.metric("Reintento <= 24h mismo archivo", f"{retry_24h_same:,}")
            with c4:
                st.metric("% mismo archivo", f"{pct_same:.2f}%")
            st.caption("Fuente: CSV detallado.")


if __name__ == "__main__":
    main()
