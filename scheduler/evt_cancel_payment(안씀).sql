DROP EVENT IF EXISTS evt_cancel_payment;

CREATE EVENT evt_cancel_payment
ON SCHEDULE EVERY 1 MINUTE
DO
    -- 결제 대기 상태이면서 생성된 지 5분이 지난 데이터의 결제 상태를 '취소' 로 변경
    UPDATE payment
    SET status = 2
    WHERE status = 0
    AND created_at <= NOW() - INTERVAL 5 MINUTE;