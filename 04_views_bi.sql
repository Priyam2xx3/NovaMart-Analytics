USE novamart_analytics;

-- ------------------------------------------------------------------------------
-- BI VIEW: Monthly Sales & Executive KPIs (Star Schema Fact Equivalent)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_monthly_sales AS
SELECT 
    YEAR(o.order_date) AS sales_year,
    MONTH(o.order_date) AS sales_month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.quantity) AS units_sold,
    SUM(oi.quantity * oi.unit_price) AS gross_revenue,
    SUM(oi.discount_amount) AS total_discounts,
    SUM(o.total_amount) AS net_revenue,
    SUM(oi.line_total - (p.unit_cost * oi.quantity)) AS gross_profit,
    fn_profit_margin(SUM(o.total_amount), SUM(p.unit_cost * oi.quantity)) AS margin_percentage,
    AVG(o.total_amount) AS average_order_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE o.order_status NOT IN ('Cancelled', 'Returned')
GROUP BY YEAR(o.order_date), MONTH(o.order_date);

-- ------------------------------------------------------------------------------
-- BI VIEW: Customer Lifetime Value (CLV)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_customer_lifetime_value AS
SELECT 
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.customer_segment,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(o.total_amount) AS total_spend,
    AVG(o.total_amount) AS average_order_value,
    MIN(o.order_date) AS first_order_date,
    MAX(o.order_date) AS last_order_date,
    DATEDIFF(MAX(o.order_date), MIN(o.order_date)) AS customer_lifetime_days,
    -- Simple Predictive CLV = AOV * Frequency
    (AVG(o.total_amount) * COUNT(DISTINCT o.order_id)) AS estimated_lifetime_value
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id AND o.order_status = 'Delivered'
GROUP BY c.customer_id, customer_name, c.customer_segment;

-- ------------------------------------------------------------------------------
-- BI VIEW: Product Performance & Profitability
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_product_performance AS
SELECT 
    p.product_id,
    p.product_name,
    c.category_name AS category,
    b.brand_name AS brand,
    SUM(oi.quantity) AS units_sold,
    SUM(oi.line_total) AS total_revenue,
    SUM(p.unit_cost * oi.quantity) AS total_cost,
    SUM(oi.line_total) - SUM(p.unit_cost * oi.quantity) AS gross_profit,
    fn_profit_margin(SUM(oi.line_total), SUM(p.unit_cost * oi.quantity)) AS margin_percentage,
    -- Calculate Return Rate via Correlated Subquery
    IFNULL((SELECT SUM(ri.quantity) FROM return_items ri 
            JOIN returns r ON ri.return_id = r.return_id 
            JOIN order_items oi2 ON ri.order_item_id = oi2.order_item_id 
            WHERE oi2.product_id = p.product_id), 0) / NULLIF(SUM(oi.quantity), 0) * 100 AS return_rate_pct
FROM products p
JOIN categories c ON p.category_id = c.category_id
JOIN brands b ON p.brand_id = b.brand_id
LEFT JOIN order_items oi ON p.product_id = oi.product_id
JOIN orders o ON oi.order_id = o.order_id AND o.order_status = 'Delivered'
GROUP BY p.product_id, p.product_name, c.category_name, b.brand_name;