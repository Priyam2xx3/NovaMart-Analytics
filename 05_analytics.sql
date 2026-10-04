USE novamart_analytics;

-- ------------------------------------------------------------------------------
-- 1. RFM ANALYSIS (Recency, Frequency, Monetary) segmentation via CTEs
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_customer_rfm AS
WITH rfm_calc AS (
    SELECT 
        customer_id,
        DATEDIFF(CURRENT_DATE, MAX(order_date)) AS recency,
        COUNT(order_id) AS frequency,
        SUM(total_amount) AS monetary,
        NTILE(4) OVER (ORDER BY DATEDIFF(CURRENT_DATE, MAX(order_date)) ASC) AS R_Score,
        NTILE(4) OVER (ORDER BY COUNT(order_id) DESC) AS F_Score,
        NTILE(4) OVER (ORDER BY SUM(total_amount) DESC) AS M_Score
    FROM orders
    WHERE order_status = 'Delivered'
    GROUP BY customer_id
)
SELECT 
    customer_id, recency, frequency, monetary,
    CONCAT(R_Score, F_Score, M_Score) AS RFM_Cell,
    CASE
        WHEN R_Score >= 3 AND F_Score >= 3 AND M_Score >= 3 THEN 'Champions'
        WHEN R_Score >= 2 AND F_Score >= 3 THEN 'Loyal Customers'
        WHEN R_Score >= 3 AND F_Score <= 2 THEN 'New Customers'
        WHEN R_Score <= 2 AND F_Score <= 2 THEN 'At Risk'
        ELSE 'Hibernating'
    END AS RFM_Segment
FROM rfm_calc;

-- ------------------------------------------------------------------------------
-- 2. COHORT ANALYSIS (Month-over-Month Retention Pivot)
-- ------------------------------------------------------------------------------
WITH first_purchase AS (
    SELECT 
        customer_id, 
        DATE_FORMAT(MIN(order_date), '%Y-%m-01') AS cohort_month
    FROM orders 
    GROUP BY customer_id
),
retention_data AS (
    SELECT 
        fp.cohort_month,
        PERIOD_DIFF(EXTRACT(YEAR_MONTH FROM o.order_date), EXTRACT(YEAR_MONTH FROM fp.cohort_month)) AS month_diff,
        COUNT(DISTINCT o.customer_id) AS active_customers
    FROM first_purchase fp
    JOIN orders o ON fp.customer_id = o.customer_id
    GROUP BY fp.cohort_month, month_diff
)
SELECT 
    cohort_month,
    MAX(CASE WHEN month_diff = 0 THEN active_customers END) AS "Month_0_Total_Size",
    MAX(CASE WHEN month_diff = 1 THEN active_customers END) AS "Month_1",
    MAX(CASE WHEN month_diff = 2 THEN active_customers END) AS "Month_2",
    MAX(CASE WHEN month_diff = 3 THEN active_customers END) AS "Month_3",
    MAX(CASE WHEN month_diff = 6 THEN active_customers END) AS "Month_6",
    MAX(CASE WHEN month_diff = 12 THEN active_customers END) AS "Month_12"
FROM retention_data
GROUP BY cohort_month
ORDER BY cohort_month;

-- ------------------------------------------------------------------------------
-- 3. PARETO 80/20 ANALYSIS (Products driving 80% of revenue)
-- ------------------------------------------------------------------------------
WITH ProductSales AS (
    SELECT 
        p.product_id, 
        p.product_name, 
        SUM(oi.line_total) AS product_revenue
    FROM products p
    JOIN order_items oi ON p.product_id = oi.product_id
    GROUP BY p.product_id, p.product_name
),
TotalRevenue AS (
    SELECT SUM(product_revenue) AS total_system_revenue FROM ProductSales
),
RunningTotals AS (
    SELECT 
        product_id,
        product_name,
        product_revenue,
        SUM(product_revenue) OVER (ORDER BY product_revenue DESC) AS running_revenue,
        (SUM(product_revenue) OVER (ORDER BY product_revenue DESC) / TotalRevenue.total_system_revenue) * 100 AS cumulative_pct
    FROM ProductSales
    CROSS JOIN TotalRevenue
)
SELECT 
    product_id, product_name, product_revenue, cumulative_pct,
    CASE 
        WHEN cumulative_pct <= 80 THEN 'A'
        WHEN cumulative_pct <= 95 THEN 'B'
        ELSE 'C' 
    END AS abc_class
FROM RunningTotals;

-- ------------------------------------------------------------------------------
-- 4. YEAR-OVER-YEAR & MONTH-OVER-MONTH GROWTH
-- ------------------------------------------------------------------------------
WITH MonthlyTotals AS (
    SELECT 
        YEAR(order_date) AS yr, 
        MONTH(order_date) AS mo, 
        SUM(total_amount) AS revenue
    FROM orders WHERE order_status = 'Delivered'
    GROUP BY YEAR(order_date), MONTH(order_date)
)
SELECT 
    yr, mo, revenue,
    LAG(revenue, 1) OVER (ORDER BY yr, mo) AS prev_month_revenue,
    LAG(revenue, 12) OVER (ORDER BY yr, mo) AS prev_year_month_revenue,
    ROUND(((revenue - LAG(revenue, 1) OVER (ORDER BY yr, mo)) / LAG(revenue, 1) OVER (ORDER BY yr, mo)) * 100, 2) AS mom_growth_pct,
    ROUND(((revenue - LAG(revenue, 12) OVER (ORDER BY yr, mo)) / LAG(revenue, 12) OVER (ORDER BY yr, mo)) * 100, 2) AS yoy_growth_pct
FROM MonthlyTotals;

-- ------------------------------------------------------------------------------
-- 5. ACID TRANSACTION DEMONSTRATION (Safe Order Placement)
-- ------------------------------------------------------------------------------
DELIMITER //

CREATE PROCEDURE sp_place_order(
    IN p_customer_id INT,
    IN p_product_id INT,
    IN p_quantity INT,
    IN p_payment_method VARCHAR(50)
)
BEGIN
    DECLARE v_order_id INT;
    DECLARE v_price DECIMAL(10,2);
    DECLARE v_total DECIMAL(12,2);
    
    -- Error handling to rollback if inventory fails or crashes occur
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'Transaction Failed: Rollback executed.' AS Status;
    END;

    START TRANSACTION;

    -- 1. Check Inventory
    IF (SELECT quantity_on_hand FROM inventory WHERE product_id = p_product_id AND warehouse_id = 1) < p_quantity THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient inventory';
    END IF;

    -- 2. Get Price
    SELECT selling_price INTO v_price FROM products WHERE product_id = p_product_id;
    SET v_total = v_price * p_quantity;

    -- 3. Create Order
    INSERT INTO orders (customer_id, order_status, warehouse_id, subtotal, total_amount)
    VALUES (p_customer_id, 'Confirmed', 1, v_total, v_total);
    SET v_order_id = LAST_INSERT_ID();

    -- 4. Create Order Item (Trigger automatically updates inventory table)
    INSERT INTO order_items (order_id, product_id, quantity, unit_price)
    VALUES (v_order_id, p_product_id, p_quantity, v_price);

    -- 5. Process Payment
    INSERT INTO payments (order_id, payment_method, amount, payment_status, transaction_reference)
    VALUES (v_order_id, p_payment_method, v_total, 'Successful', CONCAT('TXN-', UUID()));

    COMMIT;
    SELECT CONCAT('Success! Order ID: ', v_order_id) AS Status;
END //

DELIMITER ;