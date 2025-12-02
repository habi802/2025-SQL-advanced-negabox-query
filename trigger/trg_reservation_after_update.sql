DELIMITER $$

DROP TRIGGER IF EXISTS trg_reservation_after_update;

CREATE TRIGGER trg_reservation_after_update
    AFTER UPDATE ON reservation
    FOR EACH ROW
BEGIN
    -- 예매 상태가 '취소' 로 변경되었을 경우
    if OLD.status <> 2 AND NEW.status = 2 THEN
        -- 결제 데이터 상태도 '취소' 로 변경
        UPDATE payment
        SET status = 2
        WHERE type_id = OLD.reservation_id;

        -- 예매별 예매 좌석 데이터 삭제
        DELETE FROM reservation_seat_list
        WHERE reservation_id = OLD.reservation_id;
    END if;
END$$

DELIMITER ;