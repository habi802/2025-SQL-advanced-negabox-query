DELIMITER $$

DROP TRIGGER IF EXISTS trg_order_after_update;

CREATE TRIGGER trg_order_after_update
    AFTER UPDATE ON `order`
    FOR EACH ROW
BEGIN
    -- 주문 상태가 '취소' 로 변경되었을 경우
    if OLD.status <> 2 AND NEW.status = 2 THEN
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