-- Durable operation journal for a future ox_inventory transactional extension.
-- This is intentionally NOT a substitute for an atomic ox_inventory item mutation.
-- Install separately with the resource stopped; backup the database first.
CREATE TABLE IF NOT EXISTS tsfb_ox_production_receipts (
 job_id VARCHAR(36) NOT NULL PRIMARY KEY,
 owner_id VARCHAR(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
 plan_key VARCHAR(1600) NOT NULL,
 plan_json LONGTEXT NOT NULL,
 state ENUM('intent','reserved','committed','released') NOT NULL,
 revision INT UNSIGNED NOT NULL DEFAULT 0,
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 KEY owner_state (owner_id, state)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS tsfb_ox_production_events (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 job_id VARCHAR(36) NOT NULL,
 revision INT UNSIGNED NOT NULL,
 event_type VARCHAR(24) NOT NULL,
 details LONGTEXT NOT NULL,
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE KEY job_revision (job_id, revision),
 FOREIGN KEY (job_id) REFERENCES tsfb_ox_production_receipts(job_id)
) ENGINE=InnoDB;
