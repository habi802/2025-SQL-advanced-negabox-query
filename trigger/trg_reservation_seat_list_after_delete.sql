DELIMITER $$

DROP TRIGGER IF EXISTS trg_reservation_seat_list_after_delete;

CREATE TRIGGER trg_reservation_seat_list_after_delete
    AFTER UPDATE ON reservation_seat_list
    FOR EACH ROW
BEGIN
    DELETE FROM reservation_seat
    WHERE reservation_seat_id = OLD.reservation_seat_id;
END$$

DELIMITER ;