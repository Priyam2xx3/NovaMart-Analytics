USE novamart_analytics;

-- ------------------------------------------------------------------------------
-- FUNCTIONS
-- ------------------------------------------------------------------------------
DELIMITER //

CREATE FUNCTION fn_profit_margin(revenue DECIMAL(12,2), cost DECIMAL(12,2)) 
RETURNS DECIMAL(5,2)
DETERMINISTIC
BEGIN
    IF revenue = 0 THEN RETURN 0; END IF;
    RETURN ((revenue - cost) / revenue) * 100;
END //

-- ------------------------------------------------------------------------------
-- TRIGGERS: Inventory Management & Line Totals
-- ------------------------------------------------------------------------------
-- Calculate line_total automatically before inserting an order item
CREATE TRIGGER trg_before_insert_order_item
BEFORE INSERT ON order_items
FOR EACH ROW
BEGIN
    SET NEW.line_total = (NEW.quantity * NEW.unit_price) - NEW.discount_amount;
END //

-- Reserve inventory when a new order is placed
CREATE TRIGGER trg_after_insert_order_item
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
    UPDATE inventory 
    SET quantity_on_hand = quantity_on_hand - NEW.quantity,
        quantity_reserved = quantity_reserved + NEW.quantity
    WHERE product_id = NEW.product_id AND warehouse_id = (SELECT warehouse_id FROM orders WHERE order_id = NEW.order_id);
    
    -- Log transaction
    INSERT INTO inventory_transactions (product_id, warehouse_id, transaction_type, quantity, reference_type, reference_id)
    VALUES (NEW.product_id, (SELECT warehouse_id FROM orders WHERE order_id = NEW.order_id), 'Sale', -NEW.quantity, 'Order', NEW.order_id);
END //

-- Release reserved inventory when order ships
CREATE TRIGGER trg_after_update_order_shipped
AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    IF NEW.order_status = 'Shipped' AND OLD.order_status != 'Shipped' THEN
        -- Items have left the building, reduce reserved stock. (Quantity on hand was already reduced).
        UPDATE inventory i
        JOIN order_items oi ON i.product_id = oi.product_id
        SET i.quantity_reserved = i.quantity_reserved - oi.quantity
        WHERE oi.order_id = NEW.order_id AND i.warehouse_id = NEW.warehouse_id;
    END IF;
END //

DELIMITER ;