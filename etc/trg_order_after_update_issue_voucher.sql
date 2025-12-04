create definer = odd_adv_1@`%` trigger trg_order_after_update_issue_voucher
    after update
    on `order`
    for each row
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE v_expire_days INT;
    DECLARE v_expire_date DATETIME;
    DECLARE v_user_voucher_id BIGINT;

	IF NEW.status = 1 AND OLD.status <> 1 THEN

    SELECT valid_day INTO v_expire_days
    FROM store_item
    WHERE store_item_id = NEW.store_item_id;
    SET v_expire_date = DATE_ADD(NEW.created_at, INTERVAL v_expire_days DAY);
    WHILE i < NEW.quantity DO
        INSERT INTO user_voucher (
            user_id,
            store_item_id,
            issue_date,
            expire_date,
            status
        )
        VALUES (
            NEW.user_id,
            NEW.store_item_id,
            NEW.created_at,
            v_expire_date,
            0
        );

        SET v_user_voucher_id = LAST_INSERT_ID();
        INSERT INTO voucher_log (
            user_voucher_id,
            status
        )
        VALUES (
            v_user_voucher_id,
            0
        );

        SET i = i + 1;
    END WHILE;
    END IF;
END;

