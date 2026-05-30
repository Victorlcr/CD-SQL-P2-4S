# Projeto Data Warehouse — Olist E-Commerce

Data Warehouse completo construído sobre o dataset brasileiro de e-commerce [Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), utilizando **DuckDB** como motor analítico.

## Integrantes

Daiane
Enrico
Wellington
Victor


## Estrutura do Projeto

```
projeto-dw-olist/
├── README.md
├── data/                         # Arquivos CSV do Olist
├── scripts/
│   ├── 00_staging.sql            # Leitura dos CSVs em views
│   ├── 01_oltp.sql               # Tabelas normalizadas (dedup + nulos)
│   ├── 02_dw_model.sql           # Modelo estrela (dimensões + fato)
│   ├── 03_etl_load.sql           # Carga ETL com SCD Type 2
│   ├── 04_analytics.sql          # Consultas analíticas
│   └── 05_performance.sql        # Índices e otimizações
├── visualizacoes/
│   └── gerar_graficos.py         # Geração de gráficos
└── docs/
    ├── relatorio_tecnico.pdf
    ├── diagrama_modelo_estrela.png
    └── dicionario_dados.md
```

## Modelo Dimensional

| Tabela | Tipo | Descrição |
|--------|------|-----------|
| `dim_date` | Dimensão | Calendário completo (2016–2018) |
| `dim_customer` | Dimensão (SCD2) | Clientes com histórico de mudanças |
| `dim_product` | Dimensão | Catálogo de produtos |
| `dim_seller` | Dimensão | Vendedores |
| `fact_sales` | Fato | Itens de pedido (granularidade mais fina) |

## Como Executar

```bash
# Instalar DuckDB
pip install duckdb

# Executar os scripts na ordem
duckdb olist.duckdb < scripts/00_staging.sql
duckdb olist.duckdb < scripts/01_oltp.sql
duckdb olist.duckdb < scripts/02_dw_model.sql
duckdb olist.duckdb < scripts/03_etl_load.sql
```

## Dataset

Arquivos CSVs do Kaggle adicionados na pasta `data/`:
- https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

## Tecnologias

- **DuckDB** — banco analítico in-process
- **SQL** — modelagem e ETL
- **Python** — visualizações
