-- =============================================================================
-- 01_oltp.sql
-- Camada OLTP — tabelas normalizadas com tratamento de nulos e deduplicação.
-- Recria as tabelas a cada execução (DROP + CREATE) para garantir idempotência.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Clientes
-- Deduplica pelo customer_id (chave de negócio), mantendo o registro mais
-- recente por customer_unique_id.
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS oltp_customers CASCADE;
CREATE TABLE oltp_customers AS
SELECT
    customer_id,
    customer_unique_id,
    COALESCE(customer_zip_code_prefix, '00000')  AS customer_zip_code_prefix,
    COALESCE(customer_city, 'desconhecido')       AS customer_city,
    COALESCE(customer_state, 'XX')                AS customer_state
FROM (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY customer_unique_id) AS rn
    FROM stg_customers
) t
WHERE rn = 1;

-- ---------------------------------------------------------------------------
-- Vendedores
-- Deduplica pelo seller_id.
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS oltp_sellers CASCADE;
CREATE TABLE oltp_sellers AS
SELECT
    seller_id,
    COALESCE(seller_zip_code_prefix, '00000')  AS seller_zip_code_prefix,
    COALESCE(seller_city, 'desconhecido')       AS seller_city,
    COALESCE(seller_state, 'XX')                AS seller_state
FROM (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY seller_id ORDER BY seller_zip_code_prefix) AS rn
    FROM stg_sellers
) t
WHERE rn = 1;

-- ---------------------------------------------------------------------------
-- Produtos
-- Junta a tradução de categorias e deduplica pelo product_id.
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS oltp_products CASCADE;
CREATE TABLE oltp_products AS
SELECT
    p.product_id,
    COALESCE(t.product_category_name_english, p.product_category_name, 'sem_categoria')
        AS product_category_name,
    COALESCE(TRY_CAST(p.product_name_lenght   AS INTEGER), 0)  AS product_name_length,
    COALESCE(TRY_CAST(p.product_description_lenght AS INTEGER), 0) AS product_description_length,
    COALESCE(TRY_CAST(p.product_photos_qty    AS INTEGER), 0)  AS product_photos_qty,
    COALESCE(TRY_CAST(p.product_weight_g      AS DOUBLE), 0)   AS product_weight_g,
    COALESCE(TRY_CAST(p.product_length_cm     AS DOUBLE), 0)   AS product_length_cm,
    COALESCE(TRY_CAST(p.product_height_cm     AS DOUBLE), 0)   AS product_height_cm,
    COALESCE(TRY_CAST(p.product_width_cm      AS DOUBLE), 0)   AS product_width_cm
FROM (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY product_category_name) AS rn
    FROM stg_products
) p
LEFT JOIN stg_category_translation t
    ON p.product_category_name = t.product_category_name
WHERE p.rn = 1;

-- ---------------------------------------------------------------------------
-- Pedidos
-- Deduplica pelo order_id. Converte datas de VARCHAR para TIMESTAMP.
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS oltp_orders CASCADE;
CREATE TABLE oltp_orders AS
SELECT
    order_id,
    customer_id,
    COALESCE(order_status, 'unknown')                           AS order_status,
    TRY_CAST(order_purchase_timestamp       AS TIMESTAMP)       AS order_purchase_timestamp,
    TRY_CAST(order_approved_at              AS TIMESTAMP)       AS order_approved_at,
    TRY_CAST(order_delivered_carrier_date   AS TIMESTAMP)       AS order_delivered_carrier_date,
    TRY_CAST(order_delivered_customer_date  AS TIMESTAMP)       AS order_delivered_customer_date,
    TRY_CAST(order_estimated_delivery_date  AS TIMESTAMP)       AS order_estimated_delivery_date
FROM (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY order_purchase_timestamp DESC) AS rn
    FROM stg_orders
) t
WHERE rn = 1;

-- ---------------------------------------------------------------------------
-- Itens de pedido
-- Deduplica pelo par (order_id, order_item_id). Converte valores numéricos.
-- Mantém somente itens cujo pedido e produto existam nas tabelas-pai.
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS oltp_order_items CASCADE;
CREATE TABLE oltp_order_items AS
SELECT
    i.order_id,
    CAST(i.order_item_id AS INTEGER)                     AS order_item_id,
    i.product_id,
    i.seller_id,
    TRY_CAST(i.shipping_limit_date AS TIMESTAMP)         AS shipping_limit_date,
    COALESCE(TRY_CAST(i.price AS DOUBLE), 0)             AS price,
    COALESCE(TRY_CAST(i.freight_value AS DOUBLE), 0)     AS freight_value
FROM (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY order_id, order_item_id
               ORDER BY shipping_limit_date DESC
           ) AS rn
    FROM stg_order_items
) i
WHERE i.rn = 1
  AND EXISTS (SELECT 1 FROM oltp_orders    o WHERE o.order_id   = i.order_id)
  AND EXISTS (SELECT 1 FROM oltp_products  p WHERE p.product_id = i.product_id)
  AND EXISTS (SELECT 1 FROM oltp_sellers   s WHERE s.seller_id  = i.seller_id);
