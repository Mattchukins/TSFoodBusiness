-- Apply once to the same database as oxmysql, then start the resource.
-- DDL is not transactionally atomic in MySQL. Back up before upgrading.
CREATE TABLE IF NOT EXISTS tsfb_schema (version INT NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS tsfb_businesses (
 id VARCHAR(36) PRIMARY KEY, owner_id VARCHAR(80) NOT NULL, name VARCHAR(80) NOT NULL,
 type VARCHAR(24) NOT NULL, config LONGTEXT NOT NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS tsfb_audit (
 id BIGINT AUTO_INCREMENT PRIMARY KEY, action VARCHAR(48) NOT NULL, actor_id VARCHAR(80) NOT NULL,
 business_id VARCHAR(36), correlation_id VARCHAR(160) NOT NULL UNIQUE,
 details LONGTEXT NOT NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
INSERT IGNORE INTO tsfb_schema (version) VALUES (1);
