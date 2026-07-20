-- ============================================================
-- Athena analytical SQL showcase
-- Engine: Trino/Presto SQL via Amazon Athena (serverless, pay-per-query)
-- Each query below targets a specific analytical SQL skill.
-- ============================================================


-- 1. RUNNING TOTAL + MOVING AVERAGE (window functions)
-- Monthly revenue, cumulative revenue, and a 3-month moving average.
WITH monthly_revenue AS (
    SELECT
        date_trunc('month', CAST(o.order_date AS DATE)) AS month,
        SUM(oi.quantity * oi.unit_price)                 AS revenue
    FROM retail_analytics.orders o
    JOIN retail_analytics.order_items oi ON oi.order_id = o.order_id
    WHERE o.status = 'completed'
    GROUP BY 1
)
SELECT
    month,
    revenue,
    SUM(revenue) OVER (ORDER BY month) AS cumulative_revenue,
    AVG(revenue) OVER (
        ORDER BY month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS moving_avg_3mo
FROM monthly_revenue
ORDER BY month;


-- 2. RFM CUSTOMER SEGMENTATION (CTEs + NTILE window function)
-- Recency, Frequency, Monetary scoring -- a real-world marketing analytics pattern.
WITH order_facts AS (
    SELECT
        o.customer_id,
        MAX(CAST(o.order_date AS DATE))    AS last_order_date,
        COUNT(DISTINCT o.order_id)         AS order_count,
        SUM(oi.quantity * oi.unit_price)   AS total_spent
    FROM retail_analytics.orders o
    JOIN retail_analytics.order_items oi ON oi.order_id = o.order_id
    WHERE o.status = 'completed'
    GROUP BY o.customer_id
),
scored AS (
    SELECT
        customer_id,
        date_diff('day', last_order_date, DATE '2025-12-31') AS recency_days,
        order_count,
        total_spent,
        NTILE(5) OVER (ORDER BY date_diff('day', last_order_date, DATE '2025-12-31') DESC) AS recency_score,
        NTILE(5) OVER (ORDER BY order_count ASC)  AS frequency_score,
        NTILE(5) OVER (ORDER BY total_spent ASC)  AS monetary_score
    FROM order_facts
)
SELECT
    customer_id,
    recency_score,
    frequency_score,
    monetary_score,
    (recency_score + frequency_score + monetary_score) AS rfm_total,
    CASE
        WHEN (recency_score + frequency_score + monetary_score) >= 13 THEN 'champion'
        WHEN (recency_score + frequency_score + monetary_score) >= 9  THEN 'loyal'
        WHEN (recency_score + frequency_score + monetary_score) >= 6  THEN 'at_risk'
        ELSE 'lost'
    END AS segment
FROM scored
ORDER BY rfm_total DESC;


-- 3. MONTHLY COHORT RETENTION (self-join + window functions)
-- For each signup cohort, what % of customers ordered again in each
-- subsequent month? Classic retention analysis.
WITH first_order AS (
    SELECT customer_id, MIN(CAST(order_date AS DATE)) AS first_order_date
    FROM retail_analytics.orders
    WHERE status = 'completed'
    GROUP BY customer_id
),
cohort_activity AS (
    SELECT
        f.customer_id,
        date_trunc('month', f.first_order_date) AS cohort_month,
        date_diff(
            'month',
            date_trunc('month', f.first_order_date),
            date_trunc('month', CAST(o.order_date AS DATE))
        ) AS month_number
    FROM first_order f
    JOIN retail_analytics.orders o
        ON o.customer_id = f.customer_id AND o.status = 'completed'
),
cohort_size AS (
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS cohort_customers
    FROM cohort_activity
    WHERE month_number = 0
    GROUP BY cohort_month
)
SELECT
    ca.cohort_month,
    ca.month_number,
    COUNT(DISTINCT ca.customer_id)                              AS active_customers,
    cs.cohort_customers,
    ROUND(100.0 * COUNT(DISTINCT ca.customer_id) / cs.cohort_customers, 1) AS retention_pct
FROM cohort_activity ca
JOIN cohort_size cs ON cs.cohort_month = ca.cohort_month
GROUP BY ca.cohort_month, ca.month_number, cs.cohort_customers
ORDER BY ca.cohort_month, ca.month_number;


-- 4. TOP PRODUCT PER CATEGORY (RANK window function)
WITH product_sales AS (
    SELECT
        p.category,
        p.product_name,
        SUM(oi.quantity * oi.unit_price) AS revenue
    FROM retail_analytics.order_items oi
    JOIN retail_analytics.products p ON p.product_id = oi.product_id
    JOIN retail_analytics.orders o   ON o.order_id = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY p.category, p.product_name
)
SELECT category, product_name, revenue, rank
FROM (
    SELECT
        category,
        product_name,
        revenue,
        RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS rank
    FROM product_sales
)
WHERE rank <= 3
ORDER BY category, rank;


-- 5. REPEAT VS ONE-TIME CUSTOMERS (conditional aggregation)
SELECT
    CASE WHEN order_count = 1 THEN 'one_time' ELSE 'repeat' END AS customer_type,
    COUNT(*)                                   AS num_customers,
    ROUND(AVG(total_spent), 2)                 AS avg_lifetime_value
FROM (
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id)        AS order_count,
        SUM(oi.quantity * oi.unit_price)  AS total_spent
    FROM retail_analytics.orders o
    JOIN retail_analytics.order_items oi ON oi.order_id = o.order_id
    WHERE o.status = 'completed'
    GROUP BY o.customer_id
)
GROUP BY CASE WHEN order_count = 1 THEN 'one_time' ELSE 'repeat' END;
