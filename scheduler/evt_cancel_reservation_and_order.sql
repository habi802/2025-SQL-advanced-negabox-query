DELIMITER $$

DROP EVENT IF EXISTS evt_cancel_reservation_and_order;

CREATE EVENT evt_cancel_reservation_and_order
ON SCHEDULE EVERY 1 MINUTE
DO BEGIN
    -- 결제 대기 상태이면서 생성된 지 5분이 지난 예매 데이터의 상태를 '취소' 로 변경
    UPDATE reservation
    SET status = 2
    WHERE status = 0
    AND created_at <= NOW() - INTERVAL 5 MINUTE;

    -- 결제 대기 상태이면서 생성된 지 30분이 지난 스토어 주문의 상태를 '취소' 로 변경
    UPDATE `order`
    SET status = 2
    WHERE status = 0
    AND created_at <= NOW() - INTERVAL 30 MINUTE;
END$$

DELIMITER ;

