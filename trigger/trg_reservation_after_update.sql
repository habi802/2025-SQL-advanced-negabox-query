DELIMITER $$

DROP TRIGGER IF EXISTS trg_reservation_after_update;

CREATE TRIGGER trg_reservation_after_update
    AFTER UPDATE ON reservation
    FOR EACH ROW
BEGIN
    DECLARE v_payment_method INT;
    DECLARE v_payment_code VARCHAR(7);

    if OLD.status <> 1 AND NEW.status = 1 THEN
        -- 예매 상태가 '완료' 로 변경되었을 경우
        -- 결제 상태를 '완료' 로 변경하는 프로시저 실행
        SET v_payment_method = FLOOR(RAND() * 3);
        if v_payment_method = 0 THEN
            SET v_payment_code = ELT(FLOOR(1 + RAND() * 12),
                '00501', '00502', '00503', '00504', '00505', '00506',
                '00507', '00508', '00509', '00510', '00511', '00512'
            );
        elseif v_payment_method = 1 THEN
            SET v_payment_code = ELT(FLOOR(1 + RAND() * 14),
                '01201', '01202', '01203', '01204', '01205', '01206', '01207',
                '01208', '01209', '01210', '01211', '01212', '01213', '01214'
            );
        elseif v_payment_method = 2 THEN
            SET v_payment_code = ELT(FLOOR(1 + RAND() * 3),
                '00901', '00902', '00903'
            );
        END if;

        CALL update_payment_complete(
             0,
             OLD.reservation_id,
             v_payment_method,
             v_payment_code,
             NULL
        );
    elseif OLD.status <> 2 AND NEW.status = 2 THEN
        -- 예매 상태가 '취소' 로 변경되었을 경우
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