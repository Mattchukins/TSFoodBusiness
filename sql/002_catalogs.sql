-- Apply after 001_initial.sql. Keep version 1 until all statements succeed.
CREATE TABLE IF NOT EXISTS tsfb_recipes (
 id VARCHAR(36) PRIMARY KEY, business_id VARCHAR(36) NOT NULL,
 name VARCHAR(80) NOT NULL, price_cents INT UNSIGNED NOT NULL,
 ingredients LONGTEXT NOT NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY (business_id) REFERENCES tsfb_businesses(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS tsfb_suppliers (
 id VARCHAR(36) PRIMARY KEY, business_id VARCHAR(36) NOT NULL,
 name VARCHAR(80) NOT NULL, item_name VARCHAR(80) NOT NULL,
 unit_price_cents INT UNSIGNED NOT NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY (business_id) REFERENCES tsfb_businesses(id) ON DELETE CASCADE
);
INSERT IGNORE INTO tsfb_schema (version) VALUES (2);
