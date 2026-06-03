# Data Warehouse — Olist E-Commerce

Data Warehouse completo construído sobre o dataset brasileiro de e-commerce [Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), utilizando **DuckDB** como motor analítico e **Python/Plotly** para visualizações.

> **Disciplina:** Banco e Armazém de Dados em Ciências de Dados — Fatec Dep. Ary Fossen · 4º Semestre · 2026

---

## Integrantes

| Nome | RA |
|------|----|
| Daianne Soares Silva | 1141352423022 |
| Enrico Sablich Aoyama | 1141352513022 |
| Wellington Bianchetti Paes | 1141352513024 |
| Victor Lorenzo Castro Rodrigues | 1141352423041 |

---

## Estrutura do Projeto

```
CD-SQL-P2-4S/
├── README.md
├── olist.duckdb                      # Banco gerado após execução dos scripts
├── data/                             # CSVs do Olist (não versionados)
│   ├── olist_orders_dataset.csv
│   ├── olist_order_items_dataset.csv
│   ├── olist_customers_dataset.csv
│   ├── olist_products_dataset.csv
│   ├── olist_sellers_dataset.csv
│   ├── olist_order_payments_dataset.csv
│   ├── olist_order_reviews_dataset.csv
│   ├── olist_geolocation_dataset.csv
│   └── product_category_name_translation.csv
├── scripts/
│   ├── 00_staging.sql                # Leitura dos CSVs em views (sem transformação)
│   ├── 01_oltp.sql                   # Normalização, deduplicação e tratamento de nulos
│   ├── 02_dw_model.sql               # Criação do esquema estrela + dim_date populada
│   ├── 03_etl_load.sql               # Carga ETL com SCD Type 2 em dim_customer
│   ├── 04_analytics.sql              # 11 consultas analíticas de negócio
│   └── 05_performance.sql            # Tabelas agregadas e otimizações (bônus)
├── visualizacoes/
│   ├── gerar_graficos.py             # Geração dos 3 PNGs + dashboard HTML
│   ├── medir_performance.py          # Comparação de tempo: queries originais vs agregadas
│   ├── grafico_1_evolucao_receita.png
│   ├── grafico_2_top_categorias.png
│   ├── grafico_3_heatmap_estados.png
│   └── grafico_4_dashboard.html      # Dashboard interativo (abrir no navegador)
└── docs/
    ├── relatorio_tecnico_dw_olist.pdf
    ├── diagrama_modelo_estrela.png   # Versão estática para o relatório
    └── dicionario_dados.md
```

---

## Pré-requisitos

- Python 3.8+
- DuckDB (`pip install duckdb`)
- Bibliotecas Python para visualização:

```bash
pip install duckdb pandas plotly kaleido
```

---

## Como Executar

### 1. Clonar o repositório e entrar na pasta

```bash
git clone https://github.com/Victorlcr/CD-SQL-P2-4S
cd CD-SQL-P2-4S
```

### 2. Adicionar os CSVs

Baixar o dataset do Kaggle e extrair os arquivos na pasta `data/`:

```
https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
```

### 3. Criar o ambiente virtual e instalar dependências

```bash
python -m venv .venv

# Windows
.venv\Scripts\activate

# Linux / Mac
source .venv/bin/activate

pip install duckdb pandas plotly kaleido
```

### 4. Executar o pipeline ETL

Rodar os scripts **na ordem**, todos apontando para o mesmo arquivo `olist.duckdb`:

```bash
duckdb olist.duckdb -c ".read scripts/00_staging.sql"
duckdb olist.duckdb -c ".read scripts/01_oltp.sql"
duckdb olist.duckdb -c ".read scripts/02_dw_model.sql"
duckdb olist.duckdb -c ".read scripts/03_etl_load.sql"
duckdb olist.duckdb -c ".read scripts/04_analytics.sql"
duckdb olist.duckdb -c ".read scripts/05_performance.sql"
```

### 5. Gerar as visualizações

```bash
python visualizacoes/gerar_graficos.py
```

Os arquivos serão salvos na pasta `visualizacoes/`. Para visualizar o dashboard, abrir `grafico_4_dashboard.html` no navegador.

### 6. Medir performance (opcional)

```bash
python visualizacoes/medir_performance.py
```

Exibe no terminal a comparação de tempo entre queries diretas na `fact_sales` e queries nas tabelas agregadas geradas pelo `05_performance.sql`.

---

## Modelo Dimensional

**Esquema estrela** — granularidade: **1 linha por item de pedido** (`order_id` + `order_item_id`)

| Tabela | Tipo | Descrição |
|--------|------|-----------|
| `dim_date` | Dimensão | Calendário completo de 2016-01-01 a 2018-12-31 (1.096 registros) |
| `dim_customer` | Dimensão — **SCD Type 2** | Clientes com rastreamento histórico de cidade e estado |
| `dim_product` | Dimensão | Catálogo de produtos com categoria em inglês e atributos físicos |
| `dim_seller` | Dimensão | Vendedores com localização (cidade, estado, CEP) |
| `fact_sales` | Fato | Itens de pedido: preço, frete e receita total (R$) |

O diagrama completo está disponível em `docs/diagrama_modelo_estrela.html`.

---

## Pipeline ETL

```
CSVs  ──►  00_staging  ──►  01_oltp  ──►  02_dw_model  ──►  03_etl_load  ──►  olist.duckdb
            (views)       (normaliza)    (cria esquema)    (carrega DW)
```

Todos os scripts são **idempotentes**: podem ser reexecutados sem duplicar dados.

---

## Consultas Analíticas

O `04_analytics.sql` responde 11 perguntas de negócio, incluindo:

- Evolução mensal de receita e variação percentual mês a mês
- Top 10 categorias e produtos por receita
- Receita por estado e cidade do cliente (com SCD Type 2)
- Comparação entre dias úteis e finais de semana
- Ranking de vendedores e clientes com maior receita

---

## Visualizações

| Arquivo | Tipo | Descrição |
|---------|------|-----------|
| `grafico_1_evolucao_receita.png` | Linha | Receita mensal de 2016 a 2018 |
| `grafico_2_top_categorias.png` | Barras | Top 10 categorias por receita total |
| `grafico_3_heatmap_estados.png` | Mapa de calor | Receita por estado × trimestre |
| `grafico_4_dashboard.html` | Dashboard | Painel interativo com KPIs e 3 gráficos |

---

## Tecnologias

| Ferramenta | Uso |
|------------|-----|
| **DuckDB** | Banco analítico in-process, execução dos scripts SQL |
| **SQL** | Modelagem dimensional, ETL, consultas analíticas |
| **Python** | Geração de gráficos e medição de performance |
| **Plotly** | Visualizações interativas e estáticas |
| **Pandas** | Manipulação dos resultados das queries |
| **Git/GitHub** | Versionamento do código |

---

## Dataset

- **Nome:** Brazilian E-Commerce Public Dataset by Olist
- **Fonte:** [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
- **Tamanho:** ~45 MB · 9 arquivos CSV
- **Período:** 2016–2018 · 99.441 pedidos únicos

> Os CSVs **não são versionados** no repositório por conta do tamanho. Baixar diretamente do Kaggle e colocar na pasta `data/`.
