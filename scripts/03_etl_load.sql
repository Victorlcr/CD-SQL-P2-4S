-- =============================================================================
-- 03_etl_load.sql
-- Carga ETL do modelo dimensional com SCD Type 2 para dim_customer.
--
-- Pré-requisitos de execução:
--   1) 00_staging.sql
--   2) 01_oltp.sql
--   3) 02_dw_model.sql
--
-- Estratégia:
--   - dim_customer: SCD Type 2
--       * mantém histórico quando cidade, estado, CEP ou customer_unique_id mudam;
--       * encerra o registro atual antigo;
--       * insere uma nova versão ativa.
--   - dim_product e dim_seller: carga incremental simples / Type 1.
--   - fact_sales: recarga completa a partir das tabelas OLTP.
--
-- Observação:
--   Como o dataset Olist é histórico e não possui data de alteração cadastral,
--   a data de vigência do SCD é a data da execução da carga.
-- =============================================================================

BEGIN TRANSACTION;

-- -----------------------------------------------------------------------------
-- Parâmetro de data da carga.
-- Usado como início de vigência das novas versões SCD Type 2.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TEMP TABLE etl_params AS
SELECT CURRENT_DATE AS load_date;

-- =============================================================================
-- 1. CARGA DA DIMENSÃO CLIENTE — SCD TYPE 2
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Fonte tratada da dimensão cliente.
-- Garante uma linha por customer_id.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TEMP TABLE src_dim_customer AS
SELECT
    customer_id,
    customer_unique_id,
    customer_city,
    customer_state,
    customer_zip_code_prefix
FROM (
    SELECT
        c.*,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_id
            ORDER BY c.customer_unique_id
        ) AS rn
    FROM oltp_customers c
) t
WHERE rn = 1;

-- -----------------------------------------------------------------------------
-- 1.1 Encerra versões atuais quando algum atributo rastreado mudou.
-- -----------------------------------------------------------------------------
UPDATE dim_customer AS d
SET
    end_date   = (SELECT load_date - INTERVAL 1 DAY FROM etl_params),
    is_current = FALSE
FROM src_dim_customer AS s
WHERE d.customer_id = s.customer_id
  AND d.is_current = TRUE
  AND (
        d.customer_unique_id       IS DISTINCT FROM s.customer_unique_id
     OR d.customer_city            IS DISTINCT FROM s.customer_city
     OR d.customer_state           IS DISTINCT FROM s.customer_state
     OR d.customer_zip_code_prefix IS DISTINCT FROM s.customer_zip_code_prefix
  );

-- -----------------------------------------------------------------------------
-- 1.2 Insere novos clientes ou novas versões dos clientes alterados.
-- -----------------------------------------------------------------------------
INSERT INTO dim_customer (
    customer_id,
    customer_unique_id,
    customer_city,
    customer_state,
    customer_zip_code_prefix,
    start_date,
    end_date,
    is_current
)
SELECT
    s.customer_id,
    s.customer_unique_id,
    s.customer_city,
    s.customer_state,
    s.customer_zip_code_prefix,
    (SELECT load_date FROM etl_params) AS start_date,
    NULL AS end_date,
    TRUE AS is_current
FROM src_dim_customer AS s
WHERE NOT EXISTS (
    SELECT 1
    FROM dim_customer AS d
    WHERE d.customer_id = s.customer_id
      AND d.is_current = TRUE
);

-- =============================================================================
-- 2. CARGA DA DIMENSÃO PRODUTO — TYPE 1 / INCREMENTAL SIMPLES
-- =============================================================================

CREATE OR REPLACE TEMP TABLE src_dim_product AS
SELECT
    product_id,
    product_category_name,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm,
    product_photos_qty
FROM (
    SELECT
        p.*,
        ROW_NUMBER() OVER (
            PARTITION BY p.product_id
            ORDER BY p.product_category_name
        ) AS rn
    FROM oltp_products p
) t
WHERE rn = 1;

-- Atualiza produtos já existentes quando algum atributo mudou.
UPDATE dim_product AS d
SET
    product_category_name = s.product_category_name,
    product_weight_g      = s.product_weight_g,
    product_length_cm     = s.product_length_cm,
    product_height_cm     = s.product_height_cm,
    product_width_cm      = s.product_width_cm,
    product_photos_qty    = s.product_photos_qty
FROM src_dim_product AS s
WHERE d.product_id = s.product_id
  AND (
        d.product_category_name IS DISTINCT FROM s.product_category_name
     OR d.product_weight_g      IS DISTINCT FROM s.product_weight_g
     OR d.product_length_cm     IS DISTINCT FROM s.product_length_cm
     OR d.product_height_cm     IS DISTINCT FROM s.product_height_cm
     OR d.product_width_cm      IS DISTINCT FROM s.product_width_cm
     OR d.product_photos_qty    IS DISTINCT FROM s.product_photos_qty
  );

-- Insere produtos novos.
INSERT INTO dim_product (
    product_id,
    product_category_name,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm,
    product_photos_qty
)
SELECT
    s.product_id,
    s.product_category_name,
    s.product_weight_g,
    s.product_length_cm,
    s.product_height_cm,
    s.product_width_cm,
    s.product_photos_qty
FROM src_dim_product AS s
WHERE NOT EXISTS (
    SELECT 1
    FROM dim_product AS d
    WHERE d.product_id = s.product_id
);

-- =============================================================================
-- 3. CARGA DA DIMENSÃO VENDEDOR — TYPE 1 / INCREMENTAL SIMPLES
-- =============================================================================

CREATE OR REPLACE TEMP TABLE src_dim_seller AS
SELECT
    seller_id,
    seller_city,
    seller_state,
    seller_zip_code_prefix
FROM (
    SELECT
        s.*,
        ROW_NUMBER() OVER (
            PARTITION BY s.seller_id
            ORDER BY s.seller_zip_code_prefix
        ) AS rn
    FROM oltp_sellers s
) t
WHERE rn = 1;

-- Atualiza vendedores já existentes quando algum atributo mudou.
UPDATE dim_seller AS d
SET
    seller_city            = s.seller_city,
    seller_state           = s.seller_state,
    seller_zip_code_prefix = s.seller_zip_code_prefix
FROM src_dim_seller AS s
WHERE d.seller_id = s.seller_id
  AND (
        d.seller_city            IS DISTINCT FROM s.seller_city
     OR d.seller_state           IS DISTINCT FROM s.seller_state
     OR d.seller_zip_code_prefix IS DISTINCT FROM s.seller_zip_code_prefix
  );

-- Insere vendedores novos.
INSERT INTO dim_seller (
    seller_id,
    seller_city,
    seller_state,
    seller_zip_code_prefix
)
SELECT
    s.seller_id,
    s.seller_city,
    s.seller_state,
    s.seller_zip_code_prefix
FROM src_dim_seller AS s
WHERE NOT EXISTS (
    SELECT 1
    FROM dim_seller AS d
    WHERE d.seller_id = s.seller_id
);

-- =============================================================================
-- 4. CARGA DA TABELA FATO — fact_sales
-- =============================================================================

-- -----------------------------------------------------------------------------
-- A fato é recarregada por completo para evitar duplicidades.
-- Granularidade: uma linha por item de pedido.
-- -----------------------------------------------------------------------------
DELETE FROM fact_sales;

INSERT INTO fact_sales (
    date_key,
    customer_key,
    product_key,
    seller_key,
    order_id,
    order_item_id,
    order_status,
    price,
    freight_value,
    revenue
)
SELECT
    dd.date_key,
    dc.customer_key,
    dp.product_key,
    ds.seller_key,
    oi.order_id,
    oi.order_item_id,
    o.order_status,
    oi.price,
    oi.freight_value,
    oi.price + oi.freight_value AS revenue
FROM oltp_order_items AS oi
INNER JOIN oltp_orders AS o
    ON o.order_id = oi.order_id
INNER JOIN dim_date AS dd
    ON dd.full_date = CAST(o.order_purchase_timestamp AS DATE)
INNER JOIN dim_customer AS dc
    ON dc.customer_id = o.customer_id
   AND dc.is_current = TRUE
INNER JOIN dim_product AS dp
    ON dp.product_id = oi.product_id
INNER JOIN dim_seller AS ds
    ON ds.seller_id = oi.seller_id;

-- =============================================================================
-- 5. CONSULTAS DE CONFERÊNCIA DA CARGA
-- =============================================================================

-- Quantidade de registros carregados em cada tabela dimensional/fato.
SELECT 'dim_customer' AS table_name, COUNT(*) AS total_rows FROM dim_customer
UNION ALL
SELECT 'dim_product'  AS table_name, COUNT(*) AS total_rows FROM dim_product
UNION ALL
SELECT 'dim_seller'   AS table_name, COUNT(*) AS total_rows FROM dim_seller
UNION ALL
SELECT 'dim_date'     AS table_name, COUNT(*) AS total_rows FROM dim_date
UNION ALL
SELECT 'fact_sales'   AS table_name, COUNT(*) AS total_rows FROM fact_sales;

-- Verificação específica do SCD Type 2.
-- Deve haver apenas uma versão ativa por customer_id.
SELECT
    customer_id,
    COUNT(*) AS active_versions
FROM dim_customer
WHERE is_current = TRUE
GROUP BY customer_id
HAVING COUNT(*) > 1;

COMMIT;
