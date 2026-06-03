-- =============================================================================
-- 05_performance.sql
-- Otimização de performance — tabelas agregadas e análise comparativa.
--
-- Estratégia:
--   1. Medir o tempo da query original diretamente na fact_sales (EXPLAIN ANALYZE)
--   2. Criar 3 tabelas agregadas pré-calculadas
--   3. Medir o tempo das queries otimizadas nas tabelas agregadas
--   4. Comparar resultados e documentar o ganho
--
-- Idempotente: DROP IF EXISTS antes de cada CREATE.
-- =============================================================================
 
-- =============================================================================
-- 1. QUERY ORIGINAL — sem otimização
--    Lê toda a fact_sales + JOIN com dim_date a cada execução.
--    Em produção, com milhões de linhas, isso seria lento.
-- =============================================================================
 
.print ''
.print '============================================================'
.print ' EXPLAIN ANALYZE — Query original (fact_sales + JOIN)'
.print '============================================================'
.print ''
 
EXPLAIN ANALYZE
SELECT
    d.year,
    d.month,
    d.month_name,
    COUNT(DISTINCT f.order_id) AS total_pedidos,
    COUNT(*)                   AS total_itens,
    ROUND(SUM(f.revenue), 2)   AS receita_total,
    ROUND(AVG(f.revenue), 2)   AS ticket_medio
FROM fact_sales f
JOIN dim_date d
    ON f.date_key = d.date_key
GROUP BY d.year, d.month, d.month_name
ORDER BY d.year, d.month;
 
-- =============================================================================
-- 2. CRIAÇÃO DAS TABELAS AGREGADAS
--    Equivalente a Materialized Views no DuckDB.
--    Pré-calculam os resultados mais acessados para evitar
--    varreduras completas da tabela fato a cada consulta.
-- =============================================================================
 
-- ---------------------------------------------------------------------------
-- 2.1 agg_vendas_mensais
-- Agrega receita, pedidos e ticket médio por ano e mês.
-- Substitui queries que antes precisavam varrer toda a fact_sales.
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS agg_vendas_mensais;
CREATE TABLE agg_vendas_mensais AS
SELECT
    d.year,
    d.quarter,
    d.month,
    d.month_name,
    COUNT(DISTINCT f.order_id)      AS total_pedidos,
    COUNT(*)                         AS total_itens,
    ROUND(SUM(f.price), 2)           AS total_preco,
    ROUND(SUM(f.freight_value), 2)   AS total_frete,
    ROUND(SUM(f.revenue), 2)         AS receita_total,
    ROUND(AVG(f.revenue), 2)         AS ticket_medio,
    ROUND(MIN(f.revenue), 2)         AS menor_ticket,
    ROUND(MAX(f.revenue), 2)         AS maior_ticket
FROM fact_sales f
JOIN dim_date d
    ON f.date_key = d.date_key
GROUP BY d.year, d.quarter, d.month, d.month_name
ORDER BY d.year, d.month;
 
-- ---------------------------------------------------------------------------
-- 2.2 agg_vendas_por_categoria
-- Agrega receita por categoria de produto e mês.
-- Substitui queries que cruzavam fact_sales + dim_product + dim_date.
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS agg_vendas_por_categoria;
CREATE TABLE agg_vendas_por_categoria AS
SELECT
    p.product_category_name,
    d.year,
    d.month,
    d.month_name,
    COUNT(DISTINCT f.order_id)    AS total_pedidos,
    COUNT(*)                       AS total_itens,
    ROUND(SUM(f.revenue), 2)       AS receita_total,
    ROUND(AVG(f.revenue), 2)       AS ticket_medio
FROM fact_sales f
JOIN dim_product p
    ON f.product_key = p.product_key
JOIN dim_date d
    ON f.date_key = d.date_key
GROUP BY p.product_category_name, d.year, d.month, d.month_name
ORDER BY d.year, d.month, receita_total DESC;
 
-- ---------------------------------------------------------------------------
-- 2.3 agg_vendas_por_estado
-- Agrega receita por estado do cliente e mês.
-- Substitui queries que cruzavam fact_sales + dim_customer + dim_date.
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS agg_vendas_por_estado;
CREATE TABLE agg_vendas_por_estado AS
SELECT
    c.customer_state,
    d.year,
    d.month,
    d.month_name,
    COUNT(DISTINCT f.order_id)          AS total_pedidos,
    COUNT(DISTINCT c.customer_unique_id) AS total_clientes,
    ROUND(SUM(f.revenue), 2)             AS receita_total,
    ROUND(AVG(f.revenue), 2)             AS ticket_medio
FROM fact_sales f
JOIN dim_customer c
    ON f.customer_key = c.customer_key
JOIN dim_date d
    ON f.date_key = d.date_key
GROUP BY c.customer_state, d.year, d.month, d.month_name
ORDER BY d.year, d.month, receita_total DESC;
 
-- =============================================================================
-- 3. QUERY OTIMIZADA — usando tabela agregada
--    Mesma informação da query original, mas lendo de agg_vendas_mensais.
--    Não precisa mais varrer a fact_sales nem fazer JOIN com dim_date.
-- =============================================================================
 
.print ''
.print '============================================================'
.print ' EXPLAIN ANALYZE — Query otimizada (agg_vendas_mensais)'
.print '============================================================'
.print ''
 
EXPLAIN ANALYZE
SELECT
    year,
    month,
    month_name,
    total_pedidos,
    total_itens,
    receita_total,
    ticket_medio
FROM agg_vendas_mensais
ORDER BY year, month;
 
-- =============================================================================
-- 4. VERIFICAÇÃO DAS TABELAS AGREGADAS
-- =============================================================================
 
.print ''
.print '============================================================'
.print ' Linhas carregadas nas tabelas agregadas'
.print '============================================================'
.print ''
 
SELECT 'agg_vendas_mensais'       AS tabela, COUNT(*) AS linhas FROM agg_vendas_mensais
UNION ALL
SELECT 'agg_vendas_por_categoria' AS tabela, COUNT(*) AS linhas FROM agg_vendas_por_categoria
UNION ALL
SELECT 'agg_vendas_por_estado'    AS tabela, COUNT(*) AS linhas FROM agg_vendas_por_estado;
 
-- =============================================================================
-- 5. EXEMPLOS DE USO DAS TABELAS AGREGADAS
-- =============================================================================
 
.print ''
.print '============================================================'
.print ' Exemplo 1 — Evolução mensal de receita (via agregada)'
.print '============================================================'
.print ''
 
SELECT
    year,
    month,
    month_name,
    receita_total,
    ROUND(
        100.0 * (receita_total - LAG(receita_total) OVER (ORDER BY year, month))
        / NULLIF(LAG(receita_total) OVER (ORDER BY year, month), 0),
        2
    ) AS variacao_pct
FROM agg_vendas_mensais
ORDER BY year, month;
 
.print ''
.print '============================================================'
.print ' Exemplo 2 — Top 10 categorias por receita total (via agregada)'
.print '============================================================'
.print ''
 
SELECT
    product_category_name,
    SUM(total_pedidos)  AS pedidos_totais,
    SUM(total_itens)    AS itens_totais,
    ROUND(SUM(receita_total), 2) AS receita_acumulada,
    ROUND(AVG(ticket_medio), 2)  AS ticket_medio_geral
FROM agg_vendas_por_categoria
GROUP BY product_category_name
ORDER BY receita_acumulada DESC
LIMIT 10;
 
.print ''
.print '============================================================'
.print ' Exemplo 3 — Ranking de estados por receita total (via agregada)'
.print '============================================================'
.print ''
 
SELECT
    customer_state,
    SUM(total_pedidos)           AS pedidos_totais,
    SUM(total_clientes)          AS clientes_totais,
    ROUND(SUM(receita_total), 2) AS receita_acumulada,
    ROUND(AVG(ticket_medio), 2)  AS ticket_medio_geral
FROM agg_vendas_por_estado
GROUP BY customer_state
ORDER BY receita_acumulada DESC;