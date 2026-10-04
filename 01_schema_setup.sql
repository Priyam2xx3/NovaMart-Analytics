-- ==============================================================================
-- Project: NovaMart Analytics Enterprise Database
-- RDBMS: MySQL 8.0+
-- Description: DDL for Tables, Constraints, and Schema Architecture (3NF)
-- ==============================================================================

DROP DATABASE IF EXISTS novamart_analytics;
CREATE DATABASE novamart_analytics;
USE novamart_analytics;

-- ------------------------------------------------------------------------------
-- 1. EMPLOYEE DOMAIN
-- ------------------------------------------------------------------------------
CREATE TABLE departments (
    department_id INT AUTO_INCREMENT PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL UNIQUE,
    department_description TEXT
);

CREATE TABLE employees (
    employee_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    phone VARCHAR(20),
    department_id INT NOT NULL,
    manager_id INT NULL,
    job_title VARCHAR(100),
    hire_date DATE NOT NULL,
    salary DECIMAL(10, 2),
    employment_status ENUM('Active', 'Terminated', 'On Leave') DEFAULT 'Active',
    FOREIGN KEY (department_id) REFERENCES departments(department_id) ON DELETE RESTRICT,
    FOREIGN KEY (manager_id) REFERENCES employees(employee_id) ON DELETE SET NULL
);

-- ------------------------------------------------------------------------------
-- 2. CUSTOMER DOMAIN
-- ------------------------------------------------------------------------------
CREATE TABLE customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    phone VARCHAR(20),
    date_of_birth DATE,
    gender ENUM('Male', 'Female', 'Other', 'Prefer Not to Say') DEFAULT 'Prefer Not to Say',
    registration_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    customer_status ENUM('Active', 'Inactive', 'Suspended') DEFAULT 'Active',
    customer_segment ENUM('New', 'Regular', 'Loyal', 'VIP', 'At Risk', 'Churned') DEFAULT 'New',
    acquisition_channel ENUM('Organic', 'Direct', 'Social Media', 'Paid Search', 'Affiliate', 'Email') DEFAULT 'Organic',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE customer_addresses (
    address_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    address_type ENUM('Billing', 'Shipping', 'Home', 'Work') DEFAULT 'Home',
    address_line1 VARCHAR(255) NOT NULL,
    address_line2 VARCHAR(255),
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    country VARCHAR(100) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,
    is_default BOOLEAN DEFAULT FALSE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------------------------
-- 3. PRODUCT DOMAIN
-- ------------------------------------------------------------------------------
CREATE TABLE categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    parent_category_id INT NULL,
    FOREIGN KEY (parent_category_id) REFERENCES categories(category_id) ON DELETE SET NULL
);

CREATE TABLE brands (
    brand_id INT AUTO_INCREMENT PRIMARY KEY,
    brand_name VARCHAR(100) NOT NULL UNIQUE,
    country VARCHAR(100),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    sku VARCHAR(50) NOT NULL UNIQUE,
    product_name VARCHAR(255) NOT NULL,
    category_id INT NOT NULL,
    brand_id INT NOT NULL,
    description TEXT,
    unit_cost DECIMAL(10, 2) NOT NULL CHECK (unit_cost >= 0),
    selling_price DECIMAL(10, 2) NOT NULL CHECK (selling_price >= 0),
    weight_kg DECIMAL(8, 2),
    product_status ENUM('Active', 'Discontinued', 'Out of Stock', 'Coming Soon') DEFAULT 'Active',
    launch_date DATE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE RESTRICT,
    FOREIGN KEY (brand_id) REFERENCES brands(brand_id) ON DELETE RESTRICT
);

-- ------------------------------------------------------------------------------
-- 4. SUPPLIER DOMAIN
-- ------------------------------------------------------------------------------
CREATE TABLE suppliers (
    supplier_id INT AUTO_INCREMENT PRIMARY KEY,
    supplier_name VARCHAR(150) NOT NULL,
    contact_person VARCHAR(100),
    email VARCHAR(150) UNIQUE,
    phone VARCHAR(20),
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100),
    supplier_rating DECIMAL(3, 2) CHECK (supplier_rating BETWEEN 0 AND 5),
    payment_terms VARCHAR(50),
    status ENUM('Active', 'Inactive') DEFAULT 'Active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE product_suppliers (
    product_id INT,
    supplier_id INT,
    supplier_product_code VARCHAR(100),
    purchase_price DECIMAL(10, 2) NOT NULL CHECK (purchase_price >= 0),
    lead_time_days INT,
    minimum_order_quantity INT DEFAULT 1,
    is_primary_supplier BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (product_id, supplier_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------------------------
-- 5. WAREHOUSE & INVENTORY DOMAIN
-- ------------------------------------------------------------------------------
CREATE TABLE warehouses (
    warehouse_id INT AUTO_INCREMENT PRIMARY KEY,
    warehouse_name VARCHAR(100) NOT NULL,
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100),
    capacity_units INT,
    manager_employee_id INT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (manager_employee_id) REFERENCES employees(employee_id) ON DELETE SET NULL
);

CREATE TABLE inventory (
    inventory_id INT AUTO_INCREMENT PRIMARY KEY,
    warehouse_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity_on_hand INT NOT NULL DEFAULT 0 CHECK (quantity_on_hand >= 0),
    quantity_reserved INT NOT NULL DEFAULT 0 CHECK (quantity_reserved >= 0),
    reorder_level INT NOT NULL DEFAULT 10,
    last_restocked_at DATETIME,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_warehouse_product (warehouse_id, product_id),
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
);

CREATE TABLE inventory_transactions (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    warehouse_id INT NOT NULL,
    transaction_type ENUM('Purchase', 'Sale', 'Return', 'Adjustment', 'Transfer', 'Damage', 'Restock') NOT NULL,
    quantity INT NOT NULL,
    reference_type VARCHAR(50), -- e.g., 'Order', 'RMA'
    reference_id INT,
    transaction_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    employee_id INT NULL,
    notes TEXT,
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id),
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
);

-- ------------------------------------------------------------------------------
-- 6. SALES DOMAIN
-- ------------------------------------------------------------------------------
CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    employee_id INT NULL,
    order_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    order_status ENUM('Pending', 'Confirmed', 'Processing', 'Shipped', 'Delivered', 'Cancelled', 'Returned', 'Partially Returned') DEFAULT 'Pending',
    billing_address_id INT,
    shipping_address_id INT,
    warehouse_id INT,
    subtotal DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    discount_amount DECIMAL(10, 2) DEFAULT 0.00,
    tax_amount DECIMAL(10, 2) DEFAULT 0.00,
    shipping_fee DECIMAL(10, 2) DEFAULT 0.00,
    total_amount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE RESTRICT,
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE SET NULL,
    FOREIGN KEY (billing_address_id) REFERENCES customer_addresses(address_id) ON DELETE SET NULL,
    FOREIGN KEY (shipping_address_id) REFERENCES customer_addresses(address_id) ON DELETE SET NULL,
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id) ON DELETE RESTRICT
);

CREATE TABLE order_items (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10, 2) NOT NULL CHECK (unit_price >= 0),
    discount_amount DECIMAL(10, 2) DEFAULT 0.00,
    tax_amount DECIMAL(10, 2) DEFAULT 0.00,
    line_total DECIMAL(12, 2) NOT NULL, -- Calculated: (quantity * unit_price) - discount
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE RESTRICT
);

-- ------------------------------------------------------------------------------
-- 7. PAYMENT & SHIPPING DOMAIN
-- ------------------------------------------------------------------------------
CREATE TABLE payments (
    payment_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    payment_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    payment_method ENUM('Credit Card', 'Debit Card', 'UPI', 'Net Banking', 'PayPal', 'Wallet', 'Cash on Delivery') NOT NULL,
    transaction_reference VARCHAR(100) UNIQUE,
    amount DECIMAL(12, 2) NOT NULL,
    payment_status ENUM('Pending', 'Successful', 'Failed', 'Refunded', 'Partially Refunded') DEFAULT 'Pending',
    currency VARCHAR(3) DEFAULT 'USD',
    processed_at DATETIME,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE RESTRICT
);

CREATE TABLE shipping_providers (
    provider_id INT AUTO_INCREMENT PRIMARY KEY,
    provider_name VARCHAR(100) NOT NULL UNIQUE,
    contact_number VARCHAR(20),
    service_rating DECIMAL(3, 2) CHECK (service_rating BETWEEN 0 AND 5),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE shipments (
    shipment_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    provider_id INT NOT NULL,
    tracking_number VARCHAR(100) UNIQUE,
    shipping_method VARCHAR(50),
    shipped_date DATETIME,
    estimated_delivery_date DATETIME,
    actual_delivery_date DATETIME,
    shipping_status ENUM('Preparing', 'Shipped', 'In Transit', 'Out for Delivery', 'Delivered', 'Delayed', 'Lost', 'Returned') DEFAULT 'Preparing',
    shipping_cost DECIMAL(10, 2),
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (provider_id) REFERENCES shipping_providers(provider_id) ON DELETE RESTRICT
);

-- ------------------------------------------------------------------------------
-- 8. RETURNS DOMAIN
-- ------------------------------------------------------------------------------
CREATE TABLE returns (
    return_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    customer_id INT NOT NULL,
    return_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    return_reason VARCHAR(255),
    return_status ENUM('Requested', 'Approved', 'Rejected', 'Received', 'Refunded') DEFAULT 'Requested',
    refund_amount DECIMAL(10, 2) DEFAULT 0.00,
    processed_by INT NULL,
    processed_at DATETIME,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE RESTRICT,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE RESTRICT,
    FOREIGN KEY (processed_by) REFERENCES employees(employee_id) ON DELETE SET NULL
);

CREATE TABLE return_items (
    return_item_id INT AUTO_INCREMENT PRIMARY KEY,
    return_id INT NOT NULL,
    order_item_id INT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    condition_state ENUM('New', 'Opened', 'Damaged', 'Defective') NOT NULL,
    refund_amount DECIMAL(10, 2) DEFAULT 0.00,
    FOREIGN KEY (return_id) REFERENCES returns(return_id) ON DELETE CASCADE,
    FOREIGN KEY (order_item_id) REFERENCES order_items(order_item_id) ON DELETE RESTRICT
);

-- ------------------------------------------------------------------------------
-- 9. REVIEWS & MARKETING DOMAIN
-- ------------------------------------------------------------------------------
CREATE TABLE product_reviews (
    review_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    customer_id INT NOT NULL,
    order_id INT NOT NULL,
    rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    review_title VARCHAR(255),
    review_text TEXT,
    review_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    review_status ENUM('Pending', 'Approved', 'Rejected') DEFAULT 'Approved',
    UNIQUE KEY uk_review_order_product (order_id, product_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
);

CREATE TABLE marketing_campaigns (
    campaign_id INT AUTO_INCREMENT PRIMARY KEY,
    campaign_name VARCHAR(150) NOT NULL UNIQUE,
    campaign_type ENUM('Email', 'Social Media', 'Search', 'Display', 'Affiliate', 'Influencer') NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    budget DECIMAL(12, 2) NOT NULL,
    target_audience VARCHAR(255),
    campaign_status ENUM('Planned', 'Active', 'Completed', 'Cancelled') DEFAULT 'Planned'
);

CREATE TABLE customer_campaigns (
    customer_id INT NOT NULL,
    campaign_id INT NOT NULL,
    interaction_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    interaction_type ENUM('Impression', 'Click', 'Signup', 'Purchase', 'Conversion') NOT NULL,
    conversion_flag BOOLEAN DEFAULT FALSE,
    acquisition_cost DECIMAL(8, 2) DEFAULT 0.00,
    PRIMARY KEY (customer_id, campaign_id, interaction_type, interaction_date),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE,
    FOREIGN KEY (campaign_id) REFERENCES marketing_campaigns(campaign_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------------------------
-- 10. INDEXING STRATEGY
-- ------------------------------------------------------------------------------
-- Optimized indexes to speed up analytical grouping and joins.
CREATE INDEX idx_customers_segment ON customers(customer_segment);
CREATE INDEX idx_customers_registration ON customers(registration_date);

CREATE INDEX idx_orders_customer ON orders(customer_id, order_date);
CREATE INDEX idx_orders_status ON orders(order_status);
CREATE INDEX idx_orders_date ON orders(order_date);

CREATE INDEX idx_orderitems_order ON order_items(order_id);
CREATE INDEX idx_orderitems_product ON order_items(product_id);

CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_sku ON products(sku);

CREATE INDEX idx_payments_order ON payments(order_id, payment_status);
CREATE INDEX idx_shipments_order ON shipments(order_id);

CREATE INDEX idx_inventory_warehouse_product ON inventory(warehouse_id, product_id);