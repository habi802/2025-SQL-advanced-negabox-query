DELIMITER $$

DROP TRIGGER IF EXISTS trg_payment_after_update;

CREATE TRIGGER trg_payment_after_update
    AFTER UPDATE ON payment
    FOR EACH ROW
BEGIN

end $$