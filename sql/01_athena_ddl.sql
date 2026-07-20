-- ============================================================
-- Athena DDL: external tables over the S3 data lake
-- Run these in the Athena query editor after creating the
-- retail_analytics database (or let a Glue Crawler generate
-- these automatically instead — both approaches are valid).
-- Replace <your-bucket> with your own private bucket name.
-- ============================================================

CREATE DATABASE IF NOT EXISTS retail_analytics;

CREATE EXTERNAL TABLE IF NOT EXISTS retail_analytics.customers (
    customer_id   INT,
    first_name    STRING,
    last_name     STRING,
    email         STRING,
    city          STRING,
    country       STRING,
    signup_date   STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
LOCATION 's3://<your-bucket>/retail/customers/'
TBLPROPERTIES ('skip.header.line.count'='1');

CREATE EXTERNAL TABLE IF NOT EXISTS retail_analytics.products (
    product_id    INT,
    product_name  STRING,
    category      STRING,
    unit_price    DECIMAL(10,2)
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
LOCATION 's3://<your-bucket>/retail/products/'
TBLPROPERTIES ('skip.header.line.count'='1');

CREATE EXTERNAL TABLE IF NOT EXISTS retail_analytics.orders (
    order_id      INT,
    customer_id   INT,
    order_date    STRING,
    status        STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
LOCATION 's3://<your-bucket>/retail/orders/'
TBLPROPERTIES ('skip.header.line.count'='1');

CREATE EXTERNAL TABLE IF NOT EXISTS retail_analytics.order_items (
    order_item_id INT,
    order_id      INT,
    product_id    INT,
    quantity      INT,
    unit_price    DECIMAL(10,2)
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
LOCATION 's3://<your-bucket>/retail/order_items/'
TBLPROPERTIES ('skip.header.line.count'='1');
