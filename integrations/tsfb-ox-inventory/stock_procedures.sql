-- MySQL 8.0+ transactional stock engine (SQL-owned inventory only).
-- Requires stock_schema.sql and schema.sql. Does NOT mutate ox_inventory.
-- Call procedures with validated, immutable plans. All statements commit or
-- roll back together, including receipt and escrow changes.
DELIMITER $$

DROP PROCEDURE IF EXISTS tsfb_stock_reserve$$
CREATE PROCEDURE tsfb_stock_reserve(
 IN p_job VARCHAR(36), IN p_owner VARCHAR(80), IN p_key VARCHAR(1600),
 IN p_plan LONGTEXT
)
BEGIN
 DECLARE v_state VARCHAR(20);
 DECLARE v_owner VARCHAR(80);
 DECLARE v_key VARCHAR(1600);
 DECLARE v_item VARCHAR(64);
 DECLARE v_qty BIGINT;
 DECLARE v_done BOOLEAN DEFAULT FALSE;
 DECLARE v_changed BIGINT DEFAULT 0;
 DECLARE v_expected INT DEFAULT 0;
 DECLARE v_seen INT DEFAULT 0;
 DECLARE v_json_type VARCHAR(20);
 DECLARE c CURSOR FOR
  SELECT item, quantity FROM JSON_TABLE(p_plan, '$.ingredients[*]'
   COLUMNS(item VARCHAR(64) PATH '$.item', quantity BIGINT PATH '$.quantity')) AS i
  ORDER BY item;
 DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 IF p_job IS NULL OR p_owner IS NULL OR p_key IS NULL OR p_plan IS NULL OR
    JSON_VALID(p_plan) <> 1 THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='invalid_reservation';
 END IF;
 SET v_expected = JSON_LENGTH(p_plan, '$.ingredients');
 IF v_expected IS NULL OR v_expected NOT BETWEEN 1 AND 16 OR
    JSON_TYPE(JSON_EXTRACT(p_plan, '$.ingredients')) <> 'ARRAY' OR
    JSON_TYPE(JSON_EXTRACT(p_plan, '$.outputItem')) <> 'STRING' OR
    JSON_TYPE(JSON_EXTRACT(p_plan, '$.outputQuantity')) <> 'INTEGER' THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='invalid_reservation';
 END IF;
 START TRANSACTION;
 INSERT IGNORE INTO tsfb_ox_production_receipts
  (job_id,owner_id,plan_key,plan_json,state)
 VALUES(p_job,p_owner,p_key,p_plan,'intent');
 SET v_done=FALSE;
 SELECT state,owner_id,plan_key INTO v_state,v_owner,v_key
 FROM tsfb_ox_production_receipts WHERE job_id=p_job FOR UPDATE;
 IF v_owner IS NULL OR v_owner <> p_owner OR v_key IS NULL OR BINARY v_key <> BINARY p_key THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='reservation_conflict';
 END IF;
 IF v_state='intent' THEN
  SET v_done=FALSE;
  OPEN c;
  stock_loop: LOOP
   FETCH c INTO v_item,v_qty;
   IF v_done THEN LEAVE stock_loop; END IF;
   SET v_seen=v_seen+1;
   IF v_item IS NULL OR NOT (v_item REGEXP '^[a-zA-Z0-9_-]{2,64}$') OR
      v_qty IS NULL OR v_qty < 1 OR v_qty > 100000 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='invalid_ingredient';
   END IF;
   UPDATE tsfb_ox_stock SET quantity=quantity-v_qty
    WHERE owner_id=p_owner AND item=v_item AND quantity>=v_qty;
   IF ROW_COUNT() <> 1 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='insufficient_stock';
   END IF;
   INSERT INTO tsfb_ox_escrow(job_id,item,quantity)
    VALUES(p_job,v_item,v_qty);
  END LOOP;
  CLOSE c;
  IF v_seen <> v_expected THEN
   SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='invalid_ingredients';
  END IF;
  UPDATE tsfb_ox_production_receipts SET state='reserved',revision=revision+1
   WHERE job_id=p_job;
  INSERT INTO tsfb_ox_production_events(job_id,revision,event_type,details)
   VALUES(p_job,1,'reserved','{}');
 ELSEIF v_state <> 'reserved' AND v_state <> 'committed' AND v_state <> 'released' THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='invalid_receipt_state';
 END IF;
 COMMIT;
 SELECT state,job_id,owner_id,plan_key FROM tsfb_ox_production_receipts WHERE job_id=p_job;
END$$

DROP PROCEDURE IF EXISTS tsfb_stock_commit$$
CREATE PROCEDURE tsfb_stock_commit(
 IN p_job VARCHAR(36), IN p_owner VARCHAR(80), IN p_key VARCHAR(1600)
)
BEGIN
 DECLARE v_state VARCHAR(20);
 DECLARE v_owner VARCHAR(80);
 DECLARE v_key VARCHAR(1600);
 DECLARE v_plan LONGTEXT;
 DECLARE v_item VARCHAR(64);
 DECLARE v_qty BIGINT;
 DECLARE v_rev INT;
 DECLARE v_json_type VARCHAR(20);
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 START TRANSACTION;
 SELECT state,owner_id,plan_key,plan_json,revision
 INTO v_state,v_owner,v_key,v_plan,v_rev
 FROM tsfb_ox_production_receipts WHERE job_id=p_job FOR UPDATE;
 IF v_owner IS NULL OR v_owner <> p_owner OR v_key IS NULL OR BINARY v_key <> BINARY p_key THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='reservation_conflict';
 END IF;
 IF v_state='reserved' THEN
  SET v_json_type=JSON_TYPE(JSON_EXTRACT(v_plan,'$.outputQuantity'));
  IF v_json_type IS NULL OR v_json_type <> 'INTEGER' THEN
   SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='invalid_output';
  END IF;
  SET v_item=JSON_UNQUOTE(JSON_EXTRACT(v_plan,'$.outputItem'));
  SET v_qty=CAST(JSON_UNQUOTE(JSON_EXTRACT(v_plan,'$.outputQuantity')) AS UNSIGNED);
  IF v_item IS NULL OR NOT (v_item REGEXP '^[a-zA-Z0-9_-]{2,64}$') OR
     v_qty IS NULL OR v_qty NOT BETWEEN 1 AND 100000 THEN
   SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='invalid_output';
  END IF;
  INSERT INTO tsfb_ox_stock(owner_id,item,quantity)
   VALUES(p_owner,v_item,v_qty)
   ON DUPLICATE KEY UPDATE quantity=quantity+VALUES(quantity);
  DELETE FROM tsfb_ox_escrow WHERE job_id=p_job;
  UPDATE tsfb_ox_production_receipts SET state='committed',revision=revision+1
   WHERE job_id=p_job;
  INSERT INTO tsfb_ox_production_events(job_id,revision,event_type,details)
   VALUES(p_job,v_rev+1,'committed','{}');
 ELSEIF v_state <> 'committed' THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='invalid_commit_state';
 END IF;
 COMMIT;
 SELECT state,job_id,owner_id,plan_key FROM tsfb_ox_production_receipts WHERE job_id=p_job;
END$$

DROP PROCEDURE IF EXISTS tsfb_stock_release$$
CREATE PROCEDURE tsfb_stock_release(
 IN p_job VARCHAR(36), IN p_owner VARCHAR(80), IN p_key VARCHAR(1600)
)
BEGIN
 DECLARE v_state VARCHAR(20);
 DECLARE v_owner VARCHAR(80);
 DECLARE v_key VARCHAR(1600);
 DECLARE v_rev INT;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 START TRANSACTION;
 SELECT state,owner_id,plan_key,revision INTO v_state,v_owner,v_key,v_rev
 FROM tsfb_ox_production_receipts WHERE job_id=p_job FOR UPDATE;
 IF v_owner <> p_owner OR BINARY v_key <> BINARY p_key THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='reservation_conflict';
 END IF;
 IF v_state='reserved' THEN
  INSERT INTO tsfb_ox_stock(owner_id,item,quantity)
   SELECT p_owner,item,quantity FROM tsfb_ox_escrow WHERE job_id=p_job
   ON DUPLICATE KEY UPDATE quantity=quantity+VALUES(quantity);
  DELETE FROM tsfb_ox_escrow WHERE job_id=p_job;
  UPDATE tsfb_ox_production_receipts SET state='released',revision=revision+1
   WHERE job_id=p_job;
  INSERT INTO tsfb_ox_production_events(job_id,revision,event_type,details)
   VALUES(p_job,v_rev+1,'released','{}');
 ELSEIF v_state <> 'released' THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='invalid_release_state';
 END IF;
 COMMIT;
 SELECT state,job_id,owner_id,plan_key FROM tsfb_ox_production_receipts WHERE job_id=p_job;
END$$
DELIMITER ;
