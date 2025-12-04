DELIMITER $$

DROP TRIGGER IF EXISTS trg_order_after_update;

CREATE TRIGGER trg_order_after_update
    AFTER UPDATE ON `order`
    FOR EACH ROW
BEGIN
    DECLARE v_index INT DEFAULT 0;
    DECLARE v_expire_days INT;
    DECLARE v_expire_date DATETIME;
    DECLARE v_user_voucher_id BIGINT;

    if OLD.status <> 1 AND NEW.status = 1 THEN
        -- 주문 상태가 '완료' 로 변경되었을 경우
        -- 결제 상태를 '완료' 로 변경하는 프로시저 실행
        CALL update_payment_complete(
             1,
             OLD.order_id,
             0,
             ELT(FLOOR(1 + RAND() * 12),
                '00501', '00502', '00503', '00504', '00505', '00506',
                '00507', '00508', '00509', '00510', '00511', '00512'
             ),
             NULL
        );

        -- 유저별 보유 교환권 테이블에 INSERT
        SELECT valid_day INTO v_expire_days
        FROM store_item
        WHERE store_item_id = OLD.store_item_id;

        SET v_expire_date = DATE_ADD(NEW.created_at, INTERVAL v_expire_days DAY);

        WHILE v_index < NEW.quantity DO
            INSERT INTO user_voucher
            SET user_id = OLD.user_id,
                store_item_id = OLD.store_item_id,
                issue_date = OLD.created_at,
                expire_date = v_expire_date,
                status = 0;

            SET v_user_voucher_id = LAST_INSERT_ID();

            INSERT INTO voucher_log
            SET user_voucher_id = v_user_voucher_id,
                status = 0;

            SET v_index = v_index + 1;
        END WHILE;
    elseif OLD.status <> 2 AND NEW.status = 2 THEN
        -- 주문 상태가 '취소' 로 변경되었을 경우
        -- 결제 데이터 상태도 '취소' 로 변경
        UPDATE payment
        SET status = 2
        WHERE type_id = OLD.order_id;

        -- 유저별 보유 교환권 상태를 '취소' 로 변경
        UPDATE user_voucher
        SET status = 3
        WHERE order_id = OLD.order_id;
    END if;
END$$

DELIMITER ;