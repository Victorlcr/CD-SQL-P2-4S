-- =============================================================================
-- 02_dw_model.sql
-- Modelo dimensional estrela — estrutura vazia com chaves substitutas.
-- Recria as tabelas a cada execução para garantir idempotência.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Limpeza prévia — remove tabelas e sequências na ordem correta.
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS fact_sales CASCADE;
DROP TABLE IF EXISTS dim_customer CASCADE;
DROP TABLE IF EXISTS dim_product CASCADE;
DROP TABLE IF EXISTS dim_seller CASCADE;
DROP TABLE IF EXISTS dim_date CASCADE;

DROP SEQUENCE IF EXISTS seq_customer;
DROP SEQUENCE IF EXISTS seq_product;
DROP SEQUENCE IF EXISTS seq_seller;
DROP SEQUENCE IF EXISTS seq_sales;

-- ---------------------------------------------------------------------------
-- Sequências para chaves substitutas.
-- ---------------------------------------------------------------------------
CREATE SEQUENCE seq_customer START 1;
CREATE SEQUENCE seq_product  START 1;
CREATE SEQUENCE seq_seller   START 1;
CREATE SEQUENCE seq_sales    START 1;

-- ---------------------------------------------------------------------------
-- dim_date
-- Dimensão de data gerada a partir de uma série temporal.
-- Cobre o período dos dados do Olist (2016-01-01 a 2018-12-31).
-- ---------------------------------------------------------------------------
CREATE TABLE dim_date (
    date_key        INTEGER PRIMARY KEY,          -- YYYYMMDD como inteiro
    full_date       DATE        NOT NULL,
    year            INTEGER     NOT NULL,
    quarter         INTEGER     NOT NULL,
    month           INTEGER     NOT NULL,
    month_name      VARCHAR(20) NOT NULL,
    day             INTEGER     NOT NULL,
    day_of_week     INTEGER     NOT NULL,         -- 0 = domingo
    day_name        VARCHAR(20) NOT NULL,
    is_weekend      BOOLEAN     NOT NULL
);

-- Popula a dimensão de data com todos os dias do período.
INSERT INTO dim_date
SELECT
    CAST(strftime(d, '%Y%m%d') AS INTEGER)  AS date_key,
    d                                        AS full_date,
    YEAR(d)                                  AS year,
    QUARTER(d)                               AS quarter,
    MONTH(d)                                 AS month,
    monthname(d)                             AS month_name,
    DAY(d)                                   AS day,
    dayofweek(d)                             AS day_of_week,
    dayname(d)                               AS day_name,
    dayofweek(d) IN (0, 6)                   AS is_weekend
FROM generate_series(DATE '2016-01-01', DATE '2018-12-31', INTERVAL 1 DAY) AS t(d);

-- ---------------------------------------------------------------------------
-- dim_customer
-- Dimensão de cliente com suporte a SCD Type 2.
-- Campos start_date, end_date e is_current rastreiam o histórico de mudanças.
-- ---------------------------------------------------------------------------
CREATE TABLE dim_customer (
    customer_key             INTEGER PRIMARY KEY DEFAULT nextval('seq_customer'),
    customer_id              VARCHAR  NOT NULL,     -- chave natural
    customer_unique_id       VARCHAR  NOT NULL,
    customer_city            VARCHAR  NOT NULL,
    customer_state           VARCHAR(2) NOT NULL,
    customer_zip_code_prefix VARCHAR(5) NOT NULL,
    start_date               DATE     NOT NULL,
    end_date                 DATE,                  -- NULL = registro ativo
    is_current               BOOLEAN  NOT NULL DEFAULT TRUE
);

-- ---------------------------------------------------------------------------
-- dim_product
-- Dimensão de produto.
-- ---------------------------------------------------------------------------
CREATE TABLE dim_product (
    product_key             INTEGER PRIMARY KEY DEFAULT nextval('seq_product'),
    product_id              VARCHAR  NOT NULL,     -- chave natural
    product_category_name   VARCHAR  NOT NULL,
    product_weight_g        DOUBLE,
    product_length_cm       DOUBLE,
    product_height_cm       DOUBLE,
    product_width_cm        DOUBLE,
    product_photos_qty      INTEGER
);

-- ---------------------------------------------------------------------------
-- dim_seller
-- Dimensão de vendedor.
-- ---------------------------------------------------------------------------
CREATE TABLE dim_seller (
    seller_key              INTEGER PRIMARY KEY DEFAULT nextval('seq_seller'),
    seller_id               VARCHAR  NOT NULL,     -- chave natural
    seller_city             VARCHAR  NOT NULL,
    seller_state            VARCHAR(2) NOT NULL,
    seller_zip_code_prefix  VARCHAR(5) NOT NULL
);

-- ---------------------------------------------------------------------------
-- fact_sales
-- Tabela fato — granularidade: item do pedido.
-- Referencia as dimensões via chaves substitutas.
-- ---------------------------------------------------------------------------
CREATE TABLE fact_sales (
    sales_key               INTEGER PRIMARY KEY DEFAULT nextval('seq_sales'),
    date_key                INTEGER  NOT NULL,     -- FK → dim_date
    customer_key            INTEGER  NOT NULL,     -- FK → dim_customer
    product_key             INTEGER  NOT NULL,     -- FK → dim_product
    seller_key              INTEGER  NOT NULL,     -- FK → dim_seller
    order_id                VARCHAR  NOT NULL,     -- referência ao pedido original
    order_item_id           INTEGER  NOT NULL,
    order_status            VARCHAR  NOT NULL,
    price                   DOUBLE   NOT NULL,
    freight_value           DOUBLE   NOT NULL,
    revenue                 DOUBLE   NOT NULL      -- price + freight_value
);
