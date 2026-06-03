"""
gerar_graficos.py
Gera os 4 gráficos obrigatórios do projeto DW Olist a partir das
queries definidas em 04_analytics.sql.

Gráficos gerados:
  grafico_1_evolucao_receita.png   — Linha: receita mensal ao longo do tempo
  grafico_2_top_categorias.png     — Barras: top 10 categorias por receita
  grafico_3_heatmap_estados.png    — Heatmap: receita por estado × trimestre
  grafico_4_dashboard.html         — Dashboard interativo com os 4 gráficos

Dependências:
  pip install duckdb pandas plotly kaleido
"""

import os
import duckdb
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots

# =============================================================================
# Configuração
# =============================================================================

DB_PATH  = "olist.duckdb"
OUT_DIR  = "visualizacoes"
os.makedirs(OUT_DIR, exist_ok=True)

PALETA = px.colors.sequential.Blues[::-1]   # azuis escuros → claros
COR_DESTAQUE = "#1a6fc4"                     # azul principal

conn = duckdb.connect(DB_PATH)
print(" Conectado ao banco:", DB_PATH)

# =============================================================================
# Consultas (espelham as queries do 04_analytics.sql)
# =============================================================================

# Query 02 — Evolução mensal de receita
df_mensal = conn.execute("""
    SELECT
        d.year,
        d.month,
        d.month_name,
        printf('%d-%02d', d.year, d.month)  AS ano_mes,
        COUNT(DISTINCT f.order_id)           AS total_pedidos,
        ROUND(SUM(f.revenue), 2)             AS receita_total,
        ROUND(AVG(f.revenue), 2)             AS ticket_medio
    FROM fact_sales f
    JOIN dim_date d ON f.date_key = d.date_key
    GROUP BY d.year, d.month, d.month_name
    ORDER BY d.year, d.month
""").df()

# Query 03 — Receita por categoria (top 10)
df_categorias = conn.execute("""
    SELECT
        p.product_category_name             AS categoria,
        COUNT(DISTINCT f.order_id)           AS total_pedidos,
        ROUND(SUM(f.revenue), 2)             AS receita_total,
        ROUND(AVG(f.revenue), 2)             AS ticket_medio
    FROM fact_sales f
    JOIN dim_product p ON f.product_key = p.product_key
    GROUP BY p.product_category_name
    ORDER BY receita_total DESC
    LIMIT 10
""").df()

# Query 05 — Receita por estado (para heatmap com trimestres)
df_estado = conn.execute("""
    SELECT
        c.customer_state                     AS estado,
        d.year,
        d.quarter,
        printf('%d T%d', d.year, d.quarter) AS ano_trimestre,
        ROUND(SUM(f.revenue), 2)             AS receita_total
    FROM fact_sales f
    JOIN dim_customer c ON f.customer_key = c.customer_key
    JOIN dim_date d     ON f.date_key     = d.date_key
    GROUP BY c.customer_state, d.year, d.quarter
    ORDER BY d.year, d.quarter
""").df()

# Query 09 — Dias úteis vs finais de semana
df_tipo_dia = conn.execute("""
    SELECT
        CASE WHEN d.is_weekend THEN 'Final de semana' ELSE 'Dia útil' END AS tipo_dia,
        COUNT(DISTINCT f.order_id)   AS total_pedidos,
        ROUND(SUM(f.revenue), 2)     AS receita_total,
        ROUND(AVG(f.revenue), 2)     AS ticket_medio
    FROM fact_sales f
    JOIN dim_date d ON f.date_key = d.date_key
    GROUP BY d.is_weekend
    ORDER BY receita_total DESC
""").df()

print("✔ Queries executadas com sucesso")

# =============================================================================
# Gráfico 1 — Linha: Evolução mensal de receita
# =============================================================================

fig1 = px.line(
    df_mensal,
    x="ano_mes",
    y="receita_total",
    markers=True,
    title="Evolução Mensal da Receita — Olist (2016–2018)",
    labels={
        "ano_mes":      "Mês",
        "receita_total": "Receita Total (R$)"
    },
    color_discrete_sequence=[COR_DESTAQUE]
)

# Destaca o mês de pico
idx_pico = df_mensal["receita_total"].idxmax()
fig1.add_annotation(
    x=df_mensal.loc[idx_pico, "ano_mes"],
    y=df_mensal.loc[idx_pico, "receita_total"],
    text="Pico de vendas",
    showarrow=True,
    arrowhead=2,
    bgcolor="white",
    bordercolor=COR_DESTAQUE
)

fig1.update_layout(
    xaxis_tickangle=-45,
    plot_bgcolor="white",
    paper_bgcolor="white",
    font=dict(family="Arial", size=12),
    title_font_size=16,
    yaxis_tickprefix="R$ ",
    yaxis_tickformat=",.0f"
)
fig1.update_xaxes(showgrid=True, gridcolor="#eeeeee")
fig1.update_yaxes(showgrid=True, gridcolor="#eeeeee")

fig1.write_image(f"{OUT_DIR}/grafico_1_evolucao_receita.png", width=1100, height=500)
print("✔ Gráfico 1 salvo — grafico_1_evolucao_receita.png")

# =============================================================================
# Gráfico 2 — Barras horizontais: Top 10 categorias por receita
# =============================================================================

df_cat_sorted = df_categorias.sort_values("receita_total")   # menor → maior (barras horizontais)

fig2 = px.bar(
    df_cat_sorted,
    x="receita_total",
    y="categoria",
    orientation="h",
    title="Top 10 Categorias de Produtos por Receita Total",
    labels={
        "receita_total": "Receita Total (R$)",
        "categoria":     "Categoria"
    },
    text=df_cat_sorted["receita_total"].apply(lambda v: f"R$ {v:,.0f}"),
    color="receita_total",
    color_continuous_scale=px.colors.sequential.Blues
)

fig2.update_traces(textposition="outside", textfont_size=11)
fig2.update_layout(
    plot_bgcolor="white",
    paper_bgcolor="white",
    font=dict(family="Arial", size=12),
    title_font_size=16,
    coloraxis_showscale=False,
    xaxis_tickprefix="R$ ",
    xaxis_tickformat=",.0f"
)
fig2.update_xaxes(showgrid=True, gridcolor="#eeeeee")
fig2.update_yaxes(showgrid=False)

fig2.write_image(f"{OUT_DIR}/grafico_2_top_categorias.png", width=1000, height=560)
print("✔ Gráfico 2 salvo — grafico_2_top_categorias.png")

# =============================================================================
# Gráfico 3 — Heatmap: Receita por estado × trimestre
# =============================================================================

# Seleciona os 12 estados com maior receita total
top_estados = (
    df_estado.groupby("estado")["receita_total"]
    .sum()
    .nlargest(12)
    .index.tolist()
)
df_heat = df_estado[df_estado["estado"].isin(top_estados)]

pivot = df_heat.pivot_table(
    index="estado",
    columns="ano_trimestre",
    values="receita_total",
    aggfunc="sum"
).fillna(0)

fig3 = px.imshow(
    pivot,
    color_continuous_scale=px.colors.sequential.Blues,
    title="Receita por Estado × Trimestre (Top 12 Estados)",
    labels=dict(x="Trimestre", y="Estado", color="Receita (R$)"),
    aspect="auto",
    text_auto=".3s"
)

fig3.update_layout(
    plot_bgcolor="white",
    paper_bgcolor="white",
    font=dict(family="Arial", size=11),
    title_font_size=16,
    coloraxis_colorbar=dict(title="Receita (R$)", tickprefix="R$ ", tickformat=",.0f")
)

fig3.write_image(f"{OUT_DIR}/grafico_3_heatmap_estados.png", width=1050, height=520)
print("✔ Gráfico 3 salvo — grafico_3_heatmap_estados.png")

# =============================================================================
# Gráfico 4 — Dashboard interativo (HTML) com 4 painéis
# =============================================================================

fig4 = make_subplots(
    rows=2, cols=2,
    subplot_titles=(
        "Evolução Mensal da Receita",
        "Top 10 Categorias por Receita",
        "Receita por Estado × Trimestre",
        "Receita: Dias Úteis vs Finais de Semana"
    ),
    vertical_spacing=0.14,
    horizontal_spacing=0.10
)

# Painel 1 — linha
fig4.add_trace(
    go.Scatter(
        x=df_mensal["ano_mes"],
        y=df_mensal["receita_total"],
        mode="lines+markers",
        name="Receita mensal",
        line=dict(color=COR_DESTAQUE, width=2),
        marker=dict(size=5)
    ),
    row=1, col=1
)

# Painel 2 — barras horizontais
fig4.add_trace(
    go.Bar(
        x=df_cat_sorted["receita_total"],
        y=df_cat_sorted["categoria"],
        orientation="h",
        name="Receita por categoria",
        marker_color=COR_DESTAQUE
    ),
    row=1, col=2
)

# Painel 3 — heatmap
fig4.add_trace(
    go.Heatmap(
        z=pivot.values,
        x=pivot.columns.tolist(),
        y=pivot.index.tolist(),
        colorscale="Blues",
        showscale=False,
        name="Heatmap estados"
    ),
    row=2, col=1
)

# Painel 4 — barras dias úteis vs fim de semana
fig4.add_trace(
    go.Bar(
        x=df_tipo_dia["tipo_dia"],
        y=df_tipo_dia["receita_total"],
        name="Receita por tipo de dia",
        marker_color=[COR_DESTAQUE, "#90c2f5"],
        text=df_tipo_dia["receita_total"].apply(lambda v: f"R$ {v:,.0f}"),
        textposition="outside"
    ),
    row=2, col=2
)

fig4.update_layout(
    title_text="Dashboard — DW Olist E-Commerce",
    title_font_size=20,
    height=850,
    plot_bgcolor="white",
    paper_bgcolor="white",
    font=dict(family="Arial", size=11),
    showlegend=False
)

fig4.write_html(f"{OUT_DIR}/grafico_4_dashboard.html")
print("✔ Gráfico 4 salvo — grafico_4_dashboard.html")

# =============================================================================
# Fechamento
# =============================================================================

conn.close()
print()
print("=" * 50)
print("  Todos os gráficos gerados com sucesso!")
print(f"  Pasta: {OUT_DIR}/")
print("=" * 50)