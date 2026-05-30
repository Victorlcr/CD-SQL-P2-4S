# Dicionário de Dados — Olist E-Commerce

Referência completa das tabelas e colunas utilizadas no projeto de Data Warehouse.

## Volumetria dos Dados Brutos

| Arquivo | Registros | Tamanho |
|---------|----------:|--------:|
| olist_customers_dataset.csv | 99.441 | 8,6 MB |
| olist_orders_dataset.csv | 99.441 | 16,8 MB |
| olist_order_items_dataset.csv | 112.650 | 14,7 MB |
| olist_order_payments_dataset.csv | 103.886 | 5,5 MB |
| olist_order_reviews_dataset.csv | 104.164 | 13,8 MB |
| olist_products_dataset.csv | 32.951 | 2,3 MB |
| olist_sellers_dataset.csv | 3.095 | 171 KB |
| olist_geolocation_dataset.csv | 1.000.163 | 58,4 MB |
| product_category_name_translation.csv | 71 | 2,6 KB |

---

## 1. Dados Brutos (CSVs)

### 1.1 olist_customers_dataset.csv

Cadastro de clientes. Cada pedido possui um `customer_id` único; o `customer_unique_id` agrupa pedidos do mesmo comprador.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `customer_id` | VARCHAR | Identificador único do cliente por pedido |
| `customer_unique_id` | VARCHAR | Identificador único do comprador (agrupa pedidos) |
| `customer_zip_code_prefix` | VARCHAR(5) | CEP (5 primeiros dígitos) |
| `customer_city` | VARCHAR | Cidade do cliente |
| `customer_state` | VARCHAR(2) | UF do cliente |

---

### 1.2 olist_orders_dataset.csv

Pedidos realizados na plataforma. Cada linha representa um pedido.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `order_id` | VARCHAR | Identificador único do pedido |
| `customer_id` | VARCHAR | FK → customers |
| `order_status` | VARCHAR | Status do pedido (delivered, shipped, canceled, etc.) |
| `order_purchase_timestamp` | TIMESTAMP | Data/hora da compra |
| `order_approved_at` | TIMESTAMP | Data/hora da aprovação do pagamento |
| `order_delivered_carrier_date` | TIMESTAMP | Data/hora de entrega à transportadora |
| `order_delivered_customer_date` | TIMESTAMP | Data/hora de entrega ao cliente |
| `order_estimated_delivery_date` | TIMESTAMP | Data estimada de entrega |

---

### 1.3 olist_order_items_dataset.csv

Itens de cada pedido. Um pedido pode ter múltiplos itens.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `order_id` | VARCHAR | FK → orders |
| `order_item_id` | INTEGER | Sequencial do item dentro do pedido (1, 2, 3…) |
| `product_id` | VARCHAR | FK → products |
| `seller_id` | VARCHAR | FK → sellers |
| `shipping_limit_date` | TIMESTAMP | Data limite para o vendedor enviar |
| `price` | DOUBLE | Preço do item (R$) |
| `freight_value` | DOUBLE | Valor do frete do item (R$) |

---

### 1.4 olist_products_dataset.csv

Catálogo de produtos vendidos na plataforma.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `product_id` | VARCHAR | Identificador único do produto |
| `product_category_name` | VARCHAR | Categoria do produto (em português) |
| `product_name_lenght` | INTEGER | Comprimento do nome do produto (caracteres) |
| `product_description_lenght` | INTEGER | Comprimento da descrição (caracteres) |
| `product_photos_qty` | INTEGER | Quantidade de fotos publicadas |
| `product_weight_g` | DOUBLE | Peso do produto (gramas) |
| `product_length_cm` | DOUBLE | Comprimento do produto (cm) |
| `product_height_cm` | DOUBLE | Altura do produto (cm) |
| `product_width_cm` | DOUBLE | Largura do produto (cm) |

---

### 1.5 olist_sellers_dataset.csv

Vendedores cadastrados na plataforma.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `seller_id` | VARCHAR | Identificador único do vendedor |
| `seller_zip_code_prefix` | VARCHAR(5) | CEP do vendedor (5 dígitos) |
| `seller_city` | VARCHAR | Cidade do vendedor |
| `seller_state` | VARCHAR(2) | UF do vendedor |

---

### 1.6 olist_order_payments_dataset.csv

Informações de pagamento dos pedidos. Um pedido pode ter múltiplas formas de pagamento.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `order_id` | VARCHAR | FK → orders |
| `payment_sequential` | INTEGER | Sequencial do pagamento dentro do pedido |
| `payment_type` | VARCHAR | Tipo de pagamento (credit_card, boleto, voucher, debit_card) |
| `payment_installments` | INTEGER | Número de parcelas |
| `payment_value` | DOUBLE | Valor do pagamento (R$) |

---

### 1.7 olist_order_reviews_dataset.csv

Avaliações dos pedidos feitas pelos clientes.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `review_id` | VARCHAR | Identificador único da avaliação |
| `order_id` | VARCHAR | FK → orders |
| `review_score` | INTEGER | Nota de 1 a 5 |
| `review_comment_title` | VARCHAR | Título do comentário (pode ser nulo) |
| `review_comment_message` | VARCHAR | Texto do comentário (pode ser nulo) |
| `review_creation_date` | TIMESTAMP | Data de criação da avaliação |
| `review_answer_timestamp` | TIMESTAMP | Data/hora da resposta |

---

### 1.8 olist_geolocation_dataset.csv

Coordenadas geográficas por CEP brasileiro.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `geolocation_zip_code_prefix` | VARCHAR(5) | CEP (5 dígitos) |
| `geolocation_lat` | DOUBLE | Latitude |
| `geolocation_lng` | DOUBLE | Longitude |
| `geolocation_city` | VARCHAR | Cidade |
| `geolocation_state` | VARCHAR(2) | UF |

---

### 1.9 product_category_name_translation.csv

Tradução dos nomes de categoria de português para inglês.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `product_category_name` | VARCHAR | Nome da categoria em português |
| `product_category_name_english` | VARCHAR | Nome da categoria em inglês |

---

## 2. Camada OLTP (Tabelas Normalizadas)

Tabelas criadas pelo script `01_oltp.sql` com deduplicação e tratamento de nulos.

| Tabela | Origem | Chave | Tratamento |
|--------|--------|-------|------------|
| `oltp_customers` | stg_customers | `customer_id` | Deduplica por `customer_id`; nulos preenchidos com defaults |
| `oltp_sellers` | stg_sellers | `seller_id` | Deduplica por `seller_id` |
| `oltp_products` | stg_products + stg_category_translation | `product_id` | Join com tradução; categoria default `sem_categoria` |
| `oltp_orders` | stg_orders | `order_id` | Deduplica por `order_id`; datas convertidas para TIMESTAMP |
| `oltp_order_items` | stg_order_items | `order_id, order_item_id` | Integridade referencial via EXISTS |

---

## 3. Modelo Dimensional (Data Warehouse)

Tabelas criadas pelo script `02_dw_model.sql`. Todas utilizam chaves substitutas (INTEGER auto-incrementado via SEQUENCE).

### 3.1 dim_date

Dimensão de calendário pré-populada (2016-01-01 a 2018-12-31).

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `date_key` | INTEGER (PK) | Chave substituta no formato YYYYMMDD |
| `full_date` | DATE | Data completa |
| `year` | INTEGER | Ano |
| `quarter` | INTEGER | Trimestre (1–4) |
| `month` | INTEGER | Mês (1–12) |
| `month_name` | VARCHAR | Nome do mês em inglês |
| `day` | INTEGER | Dia do mês |
| `day_of_week` | INTEGER | Dia da semana (0 = domingo) |
| `day_name` | VARCHAR | Nome do dia em inglês |
| `is_weekend` | BOOLEAN | Indica se é fim de semana |

---

### 3.2 dim_customer (SCD Type 2)

Dimensão de cliente com rastreamento de mudanças históricas.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `customer_key` | INTEGER (PK) | Chave substituta (auto-incremento) |
| `customer_id` | VARCHAR | Chave natural do cliente |
| `customer_unique_id` | VARCHAR | Identificador único do comprador |
| `customer_city` | VARCHAR | Cidade |
| `customer_state` | VARCHAR(2) | UF |
| `customer_zip_code_prefix` | VARCHAR(5) | CEP |
| `start_date` | DATE | Início da validade do registro |
| `end_date` | DATE | Fim da validade (NULL = registro ativo) |
| `is_current` | BOOLEAN | Indica se é o registro corrente |

---

### 3.3 dim_product

Dimensão de produto.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `product_key` | INTEGER (PK) | Chave substituta |
| `product_id` | VARCHAR | Chave natural do produto |
| `product_category_name` | VARCHAR | Categoria (traduzida para inglês) |
| `product_weight_g` | DOUBLE | Peso (gramas) |
| `product_length_cm` | DOUBLE | Comprimento (cm) |
| `product_height_cm` | DOUBLE | Altura (cm) |
| `product_width_cm` | DOUBLE | Largura (cm) |
| `product_photos_qty` | INTEGER | Quantidade de fotos |

---

### 3.4 dim_seller

Dimensão de vendedor.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `seller_key` | INTEGER (PK) | Chave substituta |
| `seller_id` | VARCHAR | Chave natural do vendedor |
| `seller_city` | VARCHAR | Cidade |
| `seller_state` | VARCHAR(2) | UF |
| `seller_zip_code_prefix` | VARCHAR(5) | CEP |

---

### 3.5 fact_sales

Tabela fato com granularidade no nível de item do pedido.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `sales_key` | INTEGER (PK) | Chave substituta |
| `date_key` | INTEGER (FK) | FK → dim_date |
| `customer_key` | INTEGER (FK) | FK → dim_customer |
| `product_key` | INTEGER (FK) | FK → dim_product |
| `seller_key` | INTEGER (FK) | FK → dim_seller |
| `order_id` | VARCHAR | Referência ao pedido original |
| `order_item_id` | INTEGER | Sequencial do item no pedido |
| `order_status` | VARCHAR | Status do pedido |
| `price` | DOUBLE | Preço do item (R$) |
| `freight_value` | DOUBLE | Valor do frete (R$) |
| `revenue` | DOUBLE | Receita total (price + freight_value) |

---

## 4. Relacionamentos

```
stg_customers ──→ oltp_customers ──→ dim_customer ──→ fact_sales
stg_orders    ──→ oltp_orders    ──────────────────→ fact_sales (order_id, order_status)
stg_order_items → oltp_order_items ────────────────→ fact_sales (price, freight, revenue)
stg_products  ──→ oltp_products  ──→ dim_product  ──→ fact_sales
stg_sellers   ──→ oltp_sellers   ──→ dim_seller   ──→ fact_sales
                                     dim_date     ──→ fact_sales
```
