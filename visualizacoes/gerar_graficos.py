"""
gerar_graficos.py
Gera os 3 gráficos PNG individuais e um dashboard HTML completo com
cards de KPI no topo e 6 gráficos interativos abaixo.

Dependências:
  pip install duckdb pandas plotly kaleido
"""

import os
import duckdb
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import plotly.colors as pc

DB_PATH = "olist.duckdb"
OUT_DIR = "visualizacoes"
os.makedirs(OUT_DIR, exist_ok=True)

COR_PRINCIPAL  = "#1a6fc4"
COR_SECUNDARIA = "#90c2f5"

conn = duckdb.connect(DB_PATH)
print("✔ Conectado ao banco:", DB_PATH)

# =============================================================================
# QUERIES
# =============================================================================

kpi = conn.execute("""
    SELECT
        ROUND(SUM(f.revenue), 2)                     AS receita_total,
        COUNT(DISTINCT f.order_id)                    AS total_pedidos,
        ROUND(AVG(f.revenue), 2)                      AS ticket_medio,
        COUNT(DISTINCT c.customer_unique_id)          AS total_clientes,
        COUNT(DISTINCT f.product_key)                 AS total_produtos,
        COUNT(DISTINCT f.seller_key)                  AS total_vendedores
    FROM fact_sales f
    JOIN dim_customer c ON f.customer_key = c.customer_key
""").df().iloc[0]

df_mensal = conn.execute("""
    SELECT
        printf('%d-%02d', d.year, d.month) AS ano_mes,
        d.year, d.month,
        COUNT(DISTINCT f.order_id)          AS total_pedidos,
        ROUND(SUM(f.revenue), 2)            AS receita_total,
        ROUND(AVG(f.revenue), 2)            AS ticket_medio
    FROM fact_sales f
    JOIN dim_date d ON f.date_key = d.date_key
    GROUP BY d.year, d.month
    ORDER BY d.year, d.month
""").df()

df_cat = conn.execute("""
    SELECT
        p.product_category_name  AS categoria,
        COUNT(DISTINCT f.order_id) AS total_pedidos,
        ROUND(SUM(f.revenue), 2)   AS receita_total
    FROM fact_sales f
    JOIN dim_product p ON f.product_key = p.product_key
    GROUP BY p.product_category_name
    ORDER BY receita_total DESC
    LIMIT 10
""").df()

df_heat_raw = conn.execute("""
    SELECT
        c.customer_state                     AS estado,
        printf('%d T%d', d.year, d.quarter) AS trimestre,
        d.year, d.quarter,
        ROUND(SUM(f.revenue), 2)             AS receita_total
    FROM fact_sales f
    JOIN dim_customer c ON f.customer_key = c.customer_key
    JOIN dim_date d     ON f.date_key     = d.date_key
    GROUP BY c.customer_state, d.year, d.quarter
    ORDER BY d.year, d.quarter
""").df()

top_estados = (
    df_heat_raw.groupby("estado")["receita_total"]
    .sum().nlargest(12).index.tolist()
)
pivot = (
    df_heat_raw[df_heat_raw["estado"].isin(top_estados)]
    .pivot_table(index="estado", columns="trimestre",
                 values="receita_total", aggfunc="sum")
    .fillna(0)
)
# Remove colunas anteriores a 2016 T4 (dados inexistentes)
pivot = pivot[[c for c in pivot.columns if c >= "2016 T4"]]

df_status = conn.execute("""
    SELECT order_status,
           COUNT(DISTINCT order_id) AS total_pedidos
    FROM fact_sales
    GROUP BY order_status
    ORDER BY total_pedidos DESC
""").df()

df_dia = conn.execute("""
    SELECT
        CASE WHEN d.is_weekend THEN 'Final de semana' ELSE 'Dia útil' END AS tipo_dia,
        COUNT(DISTINCT f.order_id)  AS total_pedidos,
        ROUND(SUM(f.revenue), 2)    AS receita_total,
        ROUND(AVG(f.revenue), 2)    AS ticket_medio
    FROM fact_sales f
    JOIN dim_date d ON f.date_key = d.date_key
    GROUP BY d.is_weekend
    ORDER BY receita_total DESC
""").df()

# Variação % — filtra para jan/2017–ago/2018 (exclui meses iniciais com base ~zero)
df_var = df_mensal.copy()
df_var["variacao_pct"] = df_var["receita_total"].pct_change() * 100
df_var = df_var.dropna(subset=["variacao_pct"])
df_var = df_var[
    (df_var["year"] >= 2017) &
    ~((df_var["year"] == 2017) & (df_var["month"] == 1)) &
    ~((df_var["year"] == 2018) & (df_var["month"] >= 9))
].copy()
df_var["variacao_pct"] = df_var["variacao_pct"].clip(-80, 120)

print("✔ Queries executadas")

# =============================================================================
# GRÁFICOS INDIVIDUAIS (.png) — valores reais, formatação explícita
# =============================================================================

df_cat_s = df_cat.sort_values("receita_total")
n_cat    = len(df_cat_s)
escala_azul = pc.sample_colorscale("Blues", [i/(n_cat-1) for i in range(n_cat)])

# --- PNG 1: Linha mensal ---
fig1 = px.line(
    df_mensal, x="ano_mes", y="receita_total", markers=True,
    title="Receita Total Cresce ao Longo de 2017 com Pico no Final do Ano",
    labels={"ano_mes": "Mês", "receita_total": "Receita (R$)"},
    color_discrete_sequence=[COR_PRINCIPAL]
)
idx_pico = df_mensal["receita_total"].idxmax()
fig1.add_annotation(
    x=df_mensal.loc[idx_pico, "ano_mes"],
    y=df_mensal.loc[idx_pico, "receita_total"],
    text="Pico", showarrow=True, arrowhead=2,
    bgcolor="white", bordercolor=COR_PRINCIPAL
)
fig1.update_layout(
    xaxis_tickangle=-45, plot_bgcolor="white", paper_bgcolor="white",
    font=dict(family="Arial", size=12), title_font_size=14,
    yaxis_tickprefix="R$ ", yaxis_tickformat=",.0f"
)
fig1.update_xaxes(showgrid=True, gridcolor="#eeeeee")
fig1.update_yaxes(showgrid=True, gridcolor="#eeeeee")
fig1.write_image(f"{OUT_DIR}/grafico_1_evolucao_receita.png", width=1100, height=480)
print("✔ Gráfico 1 salvo")

# --- PNG 2: Top categorias ---
fig2 = go.Figure(go.Bar(
    x=df_cat_s["receita_total"].tolist(),
    y=df_cat_s["categoria"].tolist(),
    orientation="h",
    marker_color=escala_azul,
    text=df_cat_s["receita_total"].apply(lambda v: f"R$ {v/1e3:.0f}k").tolist(),
    textposition="outside",
    textfont=dict(size=11),
    hovertemplate="<b>%{y}</b><br>Receita: R$ %{x:,.0f}<extra></extra>"
))
fig2.update_layout(
    title="Cama/Mesa/Banho e Beleza/Saúde Lideram em Receita",
    plot_bgcolor="white", paper_bgcolor="white",
    font=dict(family="Arial", size=12), title_font_size=14,
    xaxis=dict(tickprefix="R$ ", tickformat=",.0f",
               showgrid=True, gridcolor="#eeeeee"),
    yaxis=dict(showgrid=False)
)
fig2.write_image(f"{OUT_DIR}/grafico_2_top_categorias.png", width=1000, height=540)
print("✔ Gráfico 2 salvo")

# --- PNG 3: Heatmap ---
fig3 = go.Figure(go.Heatmap(
    z=pivot.values.tolist(),
    x=pivot.columns.tolist(),
    y=pivot.index.tolist(),
    colorscale="Blues",
    text=[[f"{v/1e3:.0f}k" if v < 1e6 else f"{v/1e6:.1f}M" for v in row]
          for row in pivot.values],
    texttemplate="%{text}",
    hovertemplate="<b>%{y}</b> — %{x}<br>Receita: R$ %{z:,.0f}<extra></extra>",
    colorbar=dict(title="Receita (R$)")
))
fig3.update_layout(
    title="SP e RJ Dominam Receita em Todos os Trimestres",
    paper_bgcolor="white", plot_bgcolor="white",
    font=dict(family="Arial", size=10), title_font_size=14,
    margin=dict(t=50, b=60, l=60, r=120)
)
fig3.write_image(f"{OUT_DIR}/grafico_3_heatmap_estados.png", width=1100, height=520)
print("✔ Gráfico 3 salvo")

# =============================================================================
# DASHBOARD HTML — valores em MILHÕES para evitar bug de escala do Plotly
# =============================================================================

def ch(fig):
    """Serializa um Figure para fragmento HTML sem a lib plotly.js."""
    return fig.to_html(include_plotlyjs=False, full_html=False,
                       config={"responsive": True})

# Dados pré-convertidos para milhões
mensal_x   = df_mensal["ano_mes"].tolist()
mensal_y_M = (df_mensal["receita_total"] / 1e6).round(3).tolist()

cat_x_M    = (df_cat_s["receita_total"] / 1e6).round(3).tolist()
cat_y      = df_cat_s["categoria"].tolist()

pivot_M    = (pivot / 1e6).round(3)

dia_x      = df_dia["tipo_dia"].tolist()
dia_y_M    = (df_dia["receita_total"] / 1e6).round(2).tolist()
dia_text   = [f"R$ {v:.1f}M" for v in dia_y_M]

var_x      = df_var["ano_mes"].tolist()
var_y      = df_var["variacao_pct"].round(1).tolist()
var_cores  = [COR_PRINCIPAL if v >= 0 else "#e05c5c" for v in var_y]

# --- figA: Linha mensal (em milhões) ---
figA = go.Figure(go.Scatter(
    x=mensal_x, y=mensal_y_M,
    mode="lines+markers",
    line=dict(color=COR_PRINCIPAL, width=2),
    marker=dict(size=6),
    hovertemplate="<b>%{x}</b><br>Receita: R$ %{y:.2f}M<extra></extra>"
))
figA.update_layout(
    title="Evolução Mensal da Receita",
    plot_bgcolor="white", paper_bgcolor="rgba(0,0,0,0)",
    margin=dict(t=40, b=60, l=70, r=20),
    xaxis=dict(type="category", tickangle=-45,
               showgrid=True, gridcolor="#eeeeee"),
    yaxis=dict(title="R$ (milhões)", tickprefix="R$ ", ticksuffix="M",
               tickformat=".1f", showgrid=True, gridcolor="#eeeeee"),
    font=dict(family="Arial", size=11)
)

# --- figB: Top categorias (em milhões) ---
figB = go.Figure(go.Bar(
    x=cat_x_M, y=cat_y,
    orientation="h",
    marker_color=escala_azul,
    text=[f"R$ {v:.2f}M" for v in cat_x_M],
    textposition="outside",
    hovertemplate="<b>%{y}</b><br>Receita: R$ %{x:.2f}M<extra></extra>"
))
figB.update_layout(
    title="Top 10 Categorias por Receita",
    plot_bgcolor="white", paper_bgcolor="rgba(0,0,0,0)",
    margin=dict(t=40, b=40, l=160, r=80),
    xaxis=dict(title="Receita (R$ M)", tickprefix="R$ ", ticksuffix="M",
               tickformat=".1f", showgrid=True, gridcolor="#eeeeee"),
    yaxis=dict(showgrid=False),
    font=dict(family="Arial", size=11)
)

# --- figC: Heatmap (go.Heatmap para serializar corretamente) ---
text_heat = [
    [f"{v:.1f}M" if v >= 1 else f"{v*1000:.0f}k" for v in row]
    for row in pivot_M.values
]
figC = go.Figure(go.Heatmap(
    z=pivot_M.values.tolist(),
    x=pivot_M.columns.tolist(),
    y=pivot_M.index.tolist(),
    colorscale="Blues",
    text=text_heat,
    texttemplate="%{text}",
    hovertemplate="<b>%{y}</b> — %{x}<br>Receita: R$ %{z:.2f}M<extra></extra>",
    showscale=True,
    colorbar=dict(title="R$ M", tickformat=".1f", ticksuffix="M",
                  len=0.8, thickness=12)
))
figC.update_layout(
    title="Receita por Estado × Trimestre (R$ M)",
    paper_bgcolor="rgba(0,0,0,0)",
    margin=dict(t=40, b=60, l=50, r=80),
    xaxis=dict(type="category"),
    font=dict(family="Arial", size=10)
)

# --- figD: Donut status do pedido (go.Pie com .tolist() para serializar corretamente) ---
figD = go.Figure(go.Pie(
    values=df_status["total_pedidos"].tolist(),
    labels=df_status["order_status"].tolist(),
    hole=0.55,
    marker=dict(colors=px.colors.sequential.Blues_r[:len(df_status)]),
    hovertemplate="<b>%{label}</b><br>Pedidos: %{value:,}<br>%{percent}<extra></extra>",
    textinfo="label+percent"
))
figD.update_layout(
    title="Distribuição por Status do Pedido",
    paper_bgcolor="rgba(0,0,0,0)",
    margin=dict(t=40, b=20, l=20, r=20),
    font=dict(family="Arial", size=11),
    legend=dict(orientation="v", x=1.05, y=0.5)
)

# --- figE: Dias úteis vs fins de semana (em milhões) ---
figE = go.Figure(go.Bar(
    x=dia_x, y=dia_y_M,
    marker_color=[COR_PRINCIPAL, COR_SECUNDARIA],
    text=dia_text,
    textposition="outside",
    hovertemplate="<b>%{x}</b><br>Receita: R$ %{y:.1f}M<extra></extra>"
))
figE.update_layout(
    title="Receita: Dias Úteis vs Fins de Semana",
    plot_bgcolor="white", paper_bgcolor="rgba(0,0,0,0)",
    margin=dict(t=40, b=40, l=70, r=20),
    xaxis=dict(showgrid=False),
    yaxis=dict(title="R$ (milhões)", tickprefix="R$ ", ticksuffix="M",
               tickformat=".1f", showgrid=True, gridcolor="#eeeeee"),
    font=dict(family="Arial", size=11)
)

# --- figF: Variação % mensal (jan/2017–ago/2018, sem outliers dos primeiros meses) ---
figF = go.Figure(go.Bar(
    x=var_x, y=var_y,
    marker_color=var_cores,
    text=[f"{v:+.1f}%" for v in var_y],
    textposition="outside",
    hovertemplate="<b>%{x}</b><br>Variação: %{y:+.1f}%<extra></extra>"
))
figF.update_layout(
    title="Variação % de Receita Mês a Mês (2017–2018)",
    plot_bgcolor="white", paper_bgcolor="rgba(0,0,0,0)",
    margin=dict(t=40, b=60, l=60, r=20),
    xaxis=dict(type="category", tickangle=-45, showgrid=False),
    yaxis=dict(ticksuffix="%", showgrid=True, gridcolor="#eeeeee",
               zeroline=True, zerolinecolor="#aaaaaa", zerolinewidth=1.5),
    font=dict(family="Arial", size=11)
)

# =============================================================================
# KPIs formatados
# =============================================================================
receita_fmt  = f"R$ {kpi['receita_total']/1e6:.2f}M"
pedidos_fmt  = f"{int(kpi['total_pedidos']):,}".replace(",", ".")
ticket_fmt   = f"R$ {kpi['ticket_medio']:.2f}"
clientes_fmt = f"{int(kpi['total_clientes']):,}".replace(",", ".")
produtos_fmt = f"{int(kpi['total_produtos']):,}".replace(",", ".")
vendor_fmt   = f"{int(kpi['total_vendedores']):,}".replace(",", ".")

# =============================================================================
# MONTAGEM DO HTML
# =============================================================================
html = f"""<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<title>Dashboard — DW Olist</title>
<script src="https://cdn.plot.ly/plotly-2.27.0.min.js"></script>
<style>
  *{{box-sizing:border-box;margin:0;padding:0}}
  body{{font-family:Arial,sans-serif;background:#f0f4f8;color:#1a2b3c}}
  header{{background:{COR_PRINCIPAL};color:white;padding:18px 32px;display:flex;align-items:center;gap:12px}}
  header h1{{font-size:22px;font-weight:700}}
  header p{{font-size:13px;opacity:.85;margin-top:2px}}
  .container{{max-width:1400px;margin:0 auto;padding:24px 32px}}
  .kpi-grid{{display:grid;grid-template-columns:repeat(6,1fr);gap:16px;margin-bottom:28px}}
  @media(max-width:1100px){{.kpi-grid{{grid-template-columns:repeat(3,1fr)}}}}
  @media(max-width:650px){{.kpi-grid{{grid-template-columns:repeat(2,1fr)}}}}
  .card{{background:white;border-radius:10px;padding:20px 18px;box-shadow:0 2px 8px rgba(0,0,0,.07);border-top:4px solid {COR_PRINCIPAL};display:flex;flex-direction:column;gap:6px}}
  .card .label{{font-size:11px;text-transform:uppercase;letter-spacing:.6px;color:#7a8fa6;font-weight:600}}
  .card .value{{font-size:24px;font-weight:700;color:{COR_PRINCIPAL}}}
  .card .sub{{font-size:11px;color:#9aabbf}}
  .charts-grid{{display:grid;grid-template-columns:repeat(2,1fr);gap:20px}}
  @media(max-width:850px){{.charts-grid{{grid-template-columns:1fr}}}}
  .chart-box{{background:white;border-radius:10px;padding:16px;box-shadow:0 2px 8px rgba(0,0,0,.07)}}
  .chart-box.full{{grid-column:1 / -1}}
  footer{{text-align:center;padding:20px;font-size:12px;color:#9aabbf;margin-top:24px}}
</style>
</head>
<body>
<header>
  <div>
    <h1> Dashboard — Olist E-Commerce</h1>
    <p>Data Warehouse · DuckDB · Período: 2016–2018</p>
  </div>
</header>
<div class="container">
  <div class="kpi-grid">
    <div class="card"><span class="label">Receita Total</span><span class="value">{receita_fmt}</span><span class="sub">price + frete</span></div>
    <div class="card"><span class="label">Pedidos</span><span class="value">{pedidos_fmt}</span><span class="sub">pedidos únicos</span></div>
    <div class="card"><span class="label">Ticket Médio</span><span class="value">{ticket_fmt}</span><span class="sub">por item vendido</span></div>
    <div class="card"><span class="label">Clientes</span><span class="value">{clientes_fmt}</span><span class="sub">clientes únicos</span></div>
    <div class="card"><span class="label">Produtos</span><span class="value">{produtos_fmt}</span><span class="sub">SKUs distintos</span></div>
    <div class="card"><span class="label">Vendedores</span><span class="value">{vendor_fmt}</span><span class="sub">sellers ativos</span></div>
  </div>
  <div class="charts-grid">
    <div class="chart-box full">{ch(figA)}</div>
    <div class="chart-box">{ch(figB)}</div>
    <div class="chart-box">{ch(figE)}</div>
    <div class="chart-box full">{ch(figC)}</div>
  </div>
</div>
<footer>Projeto DW Olist · Banco e Armazém de Dados · Fatec 2026</footer>
</body>
</html>"""

path_dash = f"{OUT_DIR}/grafico_4_dashboard.html"
with open(path_dash, "w", encoding="utf-8") as f:
    f.write(html)
print("✔ Dashboard salvo —", path_dash)

conn.close()
print()
print("="*50)
print("  Todos os arquivos gerados com sucesso!")
print(f"  Pasta: {OUT_DIR}/")
print("="*50)