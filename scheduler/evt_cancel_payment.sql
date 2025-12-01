DROP EVENT IF EXISTS evt_cancel_payment;

CREATE EVENT evt_cancel_payment
ON SCHEDULE EVERY 1 MINUTE
DO
    SELECT payment_id
    FROM payment
    WHERE status = 0
      AND created_at <= NOW() - INTERVAL 5 MINUTE;