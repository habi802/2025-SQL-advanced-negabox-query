DROP EVENT IF EXISTS evt_cancel_payment;

CREATE EVENT evt_cancel_payment
ON SCHEDULE EVERY 1 MINUTE
DO
    UPDATE payment
    SET status = 2
    WHERE status = 0
    AND created_at <= NOW() - INTERVAL 5 MINUTE;