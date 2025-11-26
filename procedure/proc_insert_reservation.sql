DELIMITER $$

-- 예매 좌석, 예매, 예매별 예매 좌석, 예매 인원 테이블 순으로 INSERT하는 프로시저
CREATE PROCEDURE insert_reservation(
    IN input_schedule_id BIGINT -- 1
    IN input_user_id BIGINT, -- 1 or NULL
    IN input_non_user_id BIGINT, -- 1 or NULL
    IN input_seat_id JSON, -- [1, 2, 3]
    IN input_reservation_person JSON -- [{"age_type": "00201", "count": 2}]
)
BEGIN
    DECLARE value_seat_count INT;
    DECLARE value_index INT DEFAULT 0;

    -- 트랜잭션 시작: 프로시저 실행 중 실패하면 프로시저 실행 전으로 롤백함
    START TRANSACTION;

    -- 1. 예매 좌석 테이블 INSERT
    SET value_seat_count = JSON_LENGTH(input_seat_id);
    WHILE value_index < value_seat_count DO
        INSERT INTO reservation_seat
        SET schedule_id = input_schedule_id,
            seat_id = JSON_UNQUOTE(JSON_EXTRACT(input_seat_id, CONCAT('$[', value_index, ']')));
        SET value_index = value_index + 1;
    END WHILE;

    -- 2. 예매 테이블 INSERT

    -- 3. 예매별 예매 좌석 테이블 INSERT

    -- 4. 예매 인원 테이블 INSERT
END$$

DELIMITER ;



