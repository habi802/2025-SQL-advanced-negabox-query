DELIMITER $$

DROP TRIGGER IF EXISTS trg_reservation_seat_list_after_delete;

CREATE TRIGGER trg_reservation_seat_list_after_delete
    AFTER UPDATE ON reservation_seat_list
    FOR EACH ROW
BEGIN
    -- 삭제한 예매 ID를 가진 예매별 예매 좌석 데이터 삭제
    DELETE FROM reservation_seat
    WHERE reservation_seat_id = OLD.reservation_seat_id;

    -- 예매 좌석 데이터가 삭제되면
    -- 제약 조건(CASCADE)에 의해 하위 테이블인 좌석 단위 할인(ticket_discount) 데이터도 삭제됨
END$$

DELIMITER ;