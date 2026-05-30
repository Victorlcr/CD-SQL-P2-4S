-- =============================================================================
-- 00_staging.sql
-- Camada de staging — leitura dos CSVs brutos do Olist via DuckDB.
-- Cria views que apontam diretamente para os arquivos CSV.
-- Nenhuma transformação é aplicada nesta etapa.
-- Idempotente: CREATE OR REPLACE garante reexecução segura.
-- =============================================================================

-- Pedidos
CREATE OR REPLACE VIEW stg_orders AS
SELECT *
FROM read_csv_auto('data/olist_orders_dataset.csv', header = true, all_varchar = true);

-- Itens de pedido
CREATE OR REPLACE VIEW stg_order_items AS
SELECT *
FROM read_csv_auto('data/olist_order_items_dataset.csv', header = true, all_varchar = true);

-- Produtos
CREATE OR REPLACE VIEW stg_products AS
SELECT *
FROM read_csv_auto('data/olist_products_dataset.csv', header = true, all_varchar = true);

-- Clientes
CREATE OR REPLACE VIEW stg_customers AS
SELECT *
FROM read_csv_auto('data/olist_customers_dataset.csv', header = true, all_varchar = true);

-- Vendedores
CREATE OR REPLACE VIEW stg_sellers AS
SELECT *
FROM read_csv_auto('data/olist_sellers_dataset.csv', header = true, all_varchar = true);

-- Pagamentos
CREATE OR REPLACE VIEW stg_payments AS
SELECT *
FROM read_csv_auto('data/olist_order_payments_dataset.csv', header = true, all_varchar = true);

-- Avaliações
CREATE OR REPLACE VIEW stg_reviews AS
SELECT *
FROM read_csv_auto('data/olist_order_reviews_dataset.csv', header = true, all_varchar = true);

-- Geolocalização
CREATE OR REPLACE VIEW stg_geolocation AS
SELECT *
FROM read_csv_auto('data/olist_geolocation_dataset.csv', header = true, all_varchar = true);

-- Tradução de categorias de produto
CREATE OR REPLACE VIEW stg_category_translation AS
SELECT *
FROM read_csv_auto('data/product_category_name_translation.csv', header = true, all_varchar = true);
