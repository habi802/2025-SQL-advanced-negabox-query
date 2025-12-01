DELIMITER $$

DROP TRIGGER IF EXISTS trg_payment_after_update;

CREATE TRIGGER trg_payment_after_update
    AFTER UPDATE ON payment
    FOR EACH ROW
BEGIN
    -- 결제 상태로 '취소' 나 '환불' 로 변경되었다면
    if ((OLD.status <> 2 AND NEW.status = 2)
        OR (OLD.status <> 3 AND NEW.status = 3)) THEN
        -- 예매의 상태를 '취소' 로 변경
        UPDATE reservation
        SET status = 2
        WHERE reservation_id = OLD.type_id;

        -- 스토어 주문 내역의 상태를 '주문 취소' 로 변경
        UPDATE `order`
        SET status = 1
        WHERE order_id = OLD.type_id;
    END if;
END$$

DELIMITER ;