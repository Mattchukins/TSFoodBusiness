-- TSFoodBusiness install / additive upgrade to schema 5.
-- Stop the resource and back up the selected oxmysql database before import.
-- Existing rows are preserved. CREATE IF NOT EXISTS does not repair incompatible
-- columns, engines or indexes; the runtime metadata gate still checks those.
-- Execute with stop-on-error enabled; MySQL DDL is not transactionally atomic.
CREATE TABLE IF NOT EXISTS tsfb_schema (version INT NOT NULL PRIMARY KEY) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS tsfb_businesses (
 id VARCHAR(36) PRIMARY KEY, owner_id VARCHAR(80) NOT NULL, name VARCHAR(80) NOT NULL,
 type VARCHAR(24) NOT NULL, config LONGTEXT NOT NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS tsfb_audit (
 id BIGINT AUTO_INCREMENT PRIMARY KEY, action VARCHAR(48) NOT NULL, actor_id VARCHAR(80) NOT NULL,
 business_id VARCHAR(36), correlation_id VARCHAR(160) NOT NULL UNIQUE,
 details LONGTEXT NOT NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS tsfb_recipes (
 id VARCHAR(36) PRIMARY KEY, business_id VARCHAR(36) NOT NULL,
 name VARCHAR(80) NOT NULL, price_cents INT UNSIGNED NOT NULL,
 ingredients LONGTEXT NOT NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY (business_id) REFERENCES tsfb_businesses(id) ON DELETE CASCADE
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS tsfb_suppliers (
 id VARCHAR(36) PRIMARY KEY, business_id VARCHAR(36) NOT NULL,
 name VARCHAR(80) NOT NULL, item_name VARCHAR(80) NOT NULL,
 unit_price_cents INT UNSIGNED NOT NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY (business_id) REFERENCES tsfb_businesses(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS tsfb_operations (
 business_id VARCHAR(36) NOT NULL PRIMARY KEY,
 opens_minute SMALLINT UNSIGNED NOT NULL,
 closes_minute SMALLINT UNSIGNED NOT NULL,
 seat_capacity SMALLINT UNSIGNED NOT NULL DEFAULT 0,
 queue_capacity SMALLINT UNSIGNED NOT NULL DEFAULT 0,
 updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 FOREIGN KEY (business_id) REFERENCES tsfb_businesses(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS tsfb_stations (
 id VARCHAR(36) NOT NULL PRIMARY KEY,
 business_id VARCHAR(36) NOT NULL,
 name VARCHAR(80) NOT NULL,
 type VARCHAR(24) NOT NULL,
 x DOUBLE NOT NULL, y DOUBLE NOT NULL, z DOUBLE NOT NULL,
 heading DOUBLE NOT NULL, routing_bucket INT UNSIGNED NOT NULL,
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY (business_id) REFERENCES tsfb_businesses(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS tsfb_production_profiles (
 recipe_id VARCHAR(36) PRIMARY KEY,
 station_type VARCHAR(32) NOT NULL,
 output_item VARCHAR(64) NOT NULL,
 output_quantity INT UNSIGNED NOT NULL,
 duration_seconds INT UNSIGNED NOT NULL,
 updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 FOREIGN KEY (recipe_id) REFERENCES tsfb_recipes(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Record all supported versions only after every table statement succeeds.
INSERT IGNORE INTO tsfb_schema (version) VALUES (1), (2), (3), (4), (5);
