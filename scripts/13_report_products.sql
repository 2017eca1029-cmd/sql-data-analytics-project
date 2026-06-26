/*
===============================================================================
Product Report
===============================================================================
Purpose:
    - Consolidates key product metrics and behaviors.

Metrics:
    - Product segmentation by revenue
    - Lifespan (months active)
    - Recency
    - Total orders
    - Total customers
    - Total sales
    - Total quantity
    - Weighted average selling price
    - Average Order Revenue (AOR)
    - Average Monthly Revenue
===============================================================================
*/

-- =============================================================================
-- Create Report: gold.report_products
-- =============================================================================
IF OBJECT_ID('gold.report_products', 'V') IS NOT NULL
    DROP VIEW gold.report_products;
GO

CREATE VIEW gold.report_products AS

-- ============================================================================
-- 1) Base Query
-- ============================================================================
WITH base_query AS (
    SELECT
        f.order_number,
        f.order_date,
        f.customer_key,
        f.sales_amount,
        f.quantity,
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.cost
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON f.product_key = p.product_key
    WHERE f.order_date IS NOT NULL
),

-- ============================================================================
-- 2) Product Aggregations
-- ============================================================================
product_aggregations AS (
    SELECT
        product_key,
        product_name,
        category,
        subcategory,
        cost,

        -- Lifespan (inclusive)
        DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) + 1 AS lifespan,

        MAX(order_date) AS last_sale_date,

        COUNT(DISTINCT order_number)  AS total_orders,
        COUNT(DISTINCT customer_key)  AS total_customers,

        SUM(sales_amount)             AS total_sales,
        SUM(quantity)                 AS total_quantity,

        -- Weighted Average Selling Price
        ROUND(
            SUM(sales_amount) 
            / NULLIF(SUM(quantity), 0),
        2) AS avg_selling_price

    FROM base_query
    GROUP BY
        product_key,
        product_name,
        category,
        subcategory,
        cost
)

-- ============================================================================
-- 3) Final Output
-- ============================================================================
SELECT 
    product_key,
    product_name,
    category,
    subcategory,
    cost,

    last_sale_date,

    -- Recency
    DATEDIFF(MONTH, last_sale_date, GETDATE()) 
        AS recency_in_months,

    -- Revenue Segmentation
    CASE
        WHEN total_sales > 50000 THEN 'High-Performer'
        WHEN total_sales >= 10000 THEN 'Mid-Range'
        ELSE 'Low-Performer'
    END AS product_segment,

    lifespan,
    total_orders,
    total_sales,
    total_quantity,
    total_customers,
    avg_selling_price,

    -- Average Order Revenue (AOR)
    ROUND(
        CAST(total_sales AS DECIMAL(18,2)) 
        / NULLIF(total_orders, 0),
    2) AS avg_order_revenue,

    -- Average Monthly Revenue
    ROUND(
        CAST(total_sales AS DECIMAL(18,2)) 
        / NULLIF(lifespan, 0),
    2) AS avg_monthly_revenue

FROM product_aggregations;
GO
