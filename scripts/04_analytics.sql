-- =============================================================================
-- 04_analytics.sql
-- Conferência de carga seguida de
-- Consultas analíticas em SQL cobrindo diferentes perspectivas do negócio
--
-- Este script pressupõe que as dimensões e a tabela fato já estejam carregadas
-- corretamente.
-- =============================================================================

.print ''
.print '============================================================'
.print ' Conferência de carga'
.print '============================================================'
.print ''

SELECT 'dim_customer' AS tabela, COUNT(*) AS qtd_linhas FROM dim_customer
UNION ALL
SELECT 'dim_date', COUNT(*) FROM dim_date
UNION ALL
SELECT 'dim_product', COUNT(*) FROM dim_product
UNION ALL
SELECT 'dim_seller', COUNT(*) FROM dim_seller
UNION ALL
SELECT 'fact_sales', COUNT(*) FROM fact_sales;

.print ''
.print '============================================================'
.print '01 - Visão geral de vendas'
.print '============================================================'
.print ''

SELECT
    COUNT(DISTINCT order_id) AS total_pedidos,
    COUNT(*) AS total_itens_vendidos,
    ROUND(SUM(price), 2) AS total_preco_produtos,
    ROUND(SUM(freight_value), 2) AS total_frete,
    ROUND(SUM(revenue), 2) AS receita_total,
    ROUND(AVG(revenue), 2) AS ticket_medio_item
FROM fact_sales;


.print ''
.print '============================================================'
.print '02 - Evolução da receita'
.print '============================================================'
.print ''
    
SELECT
    d.year,
    d.month,
    d.month_name,
    COUNT(DISTINCT f.order_id) AS total_pedidos,
    COUNT(*) AS total_itens,
    ROUND(SUM(f.revenue), 2) AS receita_total,
    ROUND(AVG(f.revenue), 2) AS ticket_medio
FROM fact_sales f
JOIN dim_date d
    ON f.date_key = d.date_key
GROUP BY
    d.year,
    d.month,
    d.month_name
ORDER BY
    d.year,
    d.month;


.print ''
.print '============================================================'
.print '03 - Receita por categoria de produto'
.print '============================================================'
.print ''

SELECT
    p.product_category_name,
    COUNT(DISTINCT f.order_id) AS total_pedidos,
    COUNT(*) AS total_itens,
    ROUND(SUM(f.price), 2) AS total_produtos,
    ROUND(SUM(f.freight_value), 2) AS total_frete,
    ROUND(SUM(f.revenue), 2) AS receita_total,
    ROUND(AVG(f.revenue), 2) AS ticket_medio
FROM fact_sales f
JOIN dim_product p
    ON f.product_key = p.product_key
GROUP BY
    p.product_category_name
ORDER BY
    receita_total DESC;

.print ''
.print '============================================================'
.print '04 - Top 10 produtos por receita'
.print '============================================================'
.print ''

SELECT
    p.product_id,
    p.product_category_name,
    COUNT(*) AS qtd_itens_vendidos,
    COUNT(DISTINCT f.order_id) AS qtd_pedidos,
    ROUND(SUM(f.revenue), 2) AS receita_total
FROM fact_sales f
JOIN dim_product p
    ON f.product_key = p.product_key
GROUP BY
    p.product_id,
    p.product_category_name
ORDER BY
    receita_total DESC
LIMIT 10;

.print ''
.print '============================================================'
.print '05 - Receita por estado do cliente'
.print '============================================================'
.print ''

SELECT
    c.customer_state,
    COUNT(DISTINCT f.order_id) AS total_pedidos,
    COUNT(DISTINCT c.customer_unique_id) AS total_clientes,
    ROUND(SUM(f.revenue), 2) AS receita_total,
    ROUND(AVG(f.revenue), 2) AS ticket_medio_item
FROM fact_sales f
JOIN dim_customer c
    ON f.customer_key = c.customer_key
GROUP BY
    c.customer_state
ORDER BY
    receita_total DESC;

.print ''
.print '============================================================'
.print '06 - Receita por cidade do cliente'
.print '============================================================'
.print ''

SELECT
    c.customer_state,
    c.customer_city,
    COUNT(DISTINCT f.order_id) AS total_pedidos,
    COUNT(DISTINCT c.customer_unique_id) AS total_clientes,
    ROUND(SUM(f.revenue), 2) AS receita_total
FROM fact_sales f
JOIN dim_customer c
    ON f.customer_key = c.customer_key
GROUP BY
    c.customer_state,
    c.customer_city
ORDER BY
    receita_total DESC
LIMIT 20;

.print ''
.print '============================================================'
.print '07 - Receita por vendedor'
.print '============================================================'
.print ''

SELECT
    s.seller_id,
    s.seller_state,
    s.seller_city,
    COUNT(DISTINCT f.order_id) AS total_pedidos,
    COUNT(*) AS total_itens,
    ROUND(SUM(f.revenue), 2) AS receita_total,
    ROUND(AVG(f.revenue), 2) AS ticket_medio_item
FROM fact_sales f
JOIN dim_seller s
    ON f.seller_key = s.seller_key
GROUP BY
    s.seller_id,
    s.seller_state,
    s.seller_city
ORDER BY
    receita_total DESC
LIMIT 20;

.print ''
.print '============================================================'
.print '08 - Receita por status do pedido'
.print '============================================================'
.print ''

SELECT
    order_status,
    COUNT(DISTINCT order_id) AS total_pedidos,
    COUNT(*) AS total_itens,
    ROUND(SUM(revenue), 2) AS receita_total
FROM fact_sales
GROUP BY
    order_status
ORDER BY
    receita_total DESC;

.print ''
.print '============================================================'
.print '09 - Comparação dias úteis x finais de semana'
.print '============================================================'
.print ''
    
SELECT
    CASE 
        WHEN d.is_weekend THEN 'Final de semana'
        ELSE 'Dia útil'
    END AS tipo_dia,
    COUNT(DISTINCT f.order_id) AS total_pedidos,
    COUNT(*) AS total_itens,
    ROUND(SUM(f.revenue), 2) AS receita_total,
    ROUND(AVG(f.revenue), 2) AS ticket_medio_item
FROM fact_sales f
JOIN dim_date d
    ON f.date_key = d.date_key
GROUP BY
    d.is_weekend
ORDER BY
    receita_total DESC;

.print ''
.print '============================================================'
.print '10 - Ranking mensal com variação de receita'
.print '============================================================'
.print ''
    
WITH vendas_mensais AS (
    SELECT
        d.year,
        d.month,
        d.month_name,
        SUM(f.revenue) AS receita_total
    FROM fact_sales f
    JOIN dim_date d
        ON f.date_key = d.date_key
    GROUP BY
        d.year,
        d.month,
        d.month_name
)

SELECT
    year,
    month,
    month_name,
    ROUND(receita_total, 2) AS receita_total,
    ROUND(
        receita_total - LAG(receita_total) OVER (
            ORDER BY year, month
        ),
        2
    ) AS variacao_absoluta,
    ROUND(
        100.0 * (
            receita_total - LAG(receita_total) OVER (
                ORDER BY year, month
            )
        ) / NULLIF(
            LAG(receita_total) OVER (
                ORDER BY year, month
            ),
            0
        ),
        2
    ) AS variacao_percentual
FROM vendas_mensais
ORDER BY
    year,
    month;

.print ''
.print '============================================================'
.print '11 - Clientes com maior receita'
.print '============================================================'
.print ''

SELECT
    c.customer_unique_id,
    c.customer_state,
    c.customer_city,
    COUNT(DISTINCT f.order_id) AS total_pedidos,
    ROUND(SUM(f.revenue), 2) AS receita_total,
    ROUND(AVG(f.revenue), 2) AS ticket_medio_item
FROM fact_sales f
JOIN dim_customer c
    ON f.customer_key = c.customer_key
GROUP BY
    c.customer_unique_id,
    c.customer_state,
    c.customer_city
ORDER BY
    receita_total DESC
LIMIT 20;
