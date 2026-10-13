-- Atomic SQL-owned production stock engine.
-- This stock is NOT an ox_inventory player inventory. A future upstream
-- transfer boundary must reconcile deposits/withdrawals independently.
CREATE TABLE IF NOT EXISTS tsfb_ox_stock (
 owner_id VARCHAR(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
 item VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
 quantity BIGINT UNSIGNED NOT NULL DEFAULT 0,
 PRIMARY KEY (owner_id, item)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS tsfb_ox_escrow (
 job_id VARCHAR(36) NOT NULL,
 item VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
 quantity BIGINT UNSIGNED NOT NULL,
 PRIMARY KEY (job_id, item),
 FOREIGN KEY (job_id) REFERENCES tsfb_ox_production_receipts(job_id)
) ENGINE=InnoDB;

-- All receipt, escrow, stock and event changes MUST occur in one InnoDB
-- transaction; never call ox_inventory AddItem/RemoveItem inside it.
