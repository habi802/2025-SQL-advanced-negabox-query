DELIMITER $$

DROP PROCEDURE IF EXISTS insert_reservation;

CREATE PROCEDURE insert_reservation(
    IN input_schedule_id BIGINT, -- 1
    IN input_user_id BIGINT, -- 1 or NULL
    IN input_non_user_id BIGINT, -- 1 or NULL
    IN input_seat_id JSON, -- '[1, 2, 3]'
    IN input_reservation_person JSON -- '[{"age_type": "00201", "count": 2}]'
)
BEGIN
    -- 예매 좌석, 예매, 예매별 예매 좌석, 예매 인원 테이블 순으로 INSERT하는 프로시저
    DECLARE value_seat_count INT;
    DECLARE value_reservation_id BIGINT;
    DECLARE value_reservation_person_length INT;
    DECLARE value_reservation_person_count INT DEFAULT 0;
    DECLARE value_now_date_time DATETIME;
    DECLARE value_screen_running_date DATE;
    DECLARE value_screen_start_time DATETIME;
    DECLARE value_age_type VARCHAR(7);
    DECLARE value_count INT;
    DECLARE value_price INT;
    DECLARE value_total_price INT DEFAULT 0;
    DECLARE value_screen_price INT;
    DECLARE value_adjust_price INT DEFAULT 0;
    DECLARE value_index INT DEFAULT 0;
    DECLARE value_seat_id BIGINT;
    DECLARE value_reservation_seat_ids JSON;

    -- 트랜잭션 시작: 프로시저 실행 중 실패하면 프로시저 실행 전으로 롤백함
    START TRANSACTION;

    -- 회원 ID와 비회원 ID 중 하나만 입력되었는지 확인
    if (input_user_id IS NOT NULL AND input_non_user_id IS NOT NULL) OR
       (input_user_id IS NULL AND input_non_user_id IS NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '회원 ID와 비회원 ID 중 반드시 하나는 입력되어야 합니다.';
    END if;

    -- 예매 좌석 수와 인원 수가 맞는지 확인
    SET value_reservation_person_length = JSON_LENGTH(input_reservation_person);
    WHILE value_index < value_reservation_person_length DO
        SET value_reservation_person_count = value_reservation_person_count + JSON_UNQUOTE(JSON_EXTRACT(input_reservation_person, CONCAT('$[', value_index, '].count')));
        SET value_index = value_index + 1;
    END WHILE;

    SET value_seat_count = JSON_LENGTH(input_seat_id);
    if value_seat_count != value_reservation_person_count THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '예매 좌석 수와 인원 수가 맞지 않습니다.';
    END if;

    -- 현재 날짜가 상영일보다 늦거나 상영 시작 시간 20분 전에는 예매할 수 없음
    SET value_now_date_time = NOW();

    SELECT running_date, TIMESTAMP(running_date, start_time) INTO value_screen_running_date, value_screen_start_time
    FROM screen_schedule
    WHERE schedule_id = input_schedule_id;

    if DATE(value_now_date_time) > value_screen_running_date THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '이미 상영이 종료된 일정은 예매를 등록할 수 없습니다.';
    elseif value_now_date_time > value_screen_start_time - INTERVAL 20 MINUTE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '상영 시작 20분 전부터는 예매를 등록할 수 없습니다.';
    END if;

    -- 입력한 좌석 ID와 상영관 좌석 ID가 맞는지 확인
    SET value_index = 0;
    WHILE value_index < value_seat_count DO
        if NOT EXISTS(
            SELECT 1
            FROM screen_schedule ss
            JOIN seat se
              ON se.screen_id = ss.screen_id
            WHERE ss.schedule_id = input_schedule_id
              AND se.seat_id = JSON_EXTRACT(input_seat_id, CONCAT('$[', value_index, ']'))
        ) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '입력한 좌석 ID와 상영관 좌석 ID가 맞지 않습니다.';
        END if;
        SET value_index = value_index + 1;
    END WHILE;

    -- 1. 예매 좌석 테이블 INSERT
    SET value_index = 0;
    SET value_reservation_seat_ids = JSON_ARRAY();
    WHILE value_index < value_seat_count DO
        SET value_seat_id = JSON_UNQUOTE(JSON_EXTRACT(input_seat_id, CONCAT('$[', value_index, ']')));
        INSERT INTO reservation_seat
        SET schedule_id = input_schedule_id,
            seat_id = value_seat_id;
        SET value_reservation_seat_ids = JSON_ARRAY_APPEND(value_reservation_seat_ids, '$', LAST_INSERT_ID());
        SET value_index = value_index + 1;
    END WHILE;

    -- 2. 예매 테이블 INSERT
    INSERT INTO reservation
    SET schedule_id = input_schedule_id,
        user_id = input_user_id,
        non_user_id = input_non_user_id,
        price = 0;

    SET value_reservation_id = LAST_INSERT_ID();

    -- 3. 예매별 예매 좌석 테이블 INSERT
    SET value_index = 0;
    WHILE value_index < value_seat_count DO
        INSERT INTO reservation_seat_list
        SET reservation_id = value_reservation_id,
            reservation_seat_id = JSON_UNQUOTE(JSON_EXTRACT(value_reservation_seat_ids, CONCAT('$[', value_index, ']')));
        SET value_index = value_index + 1;
    END WHILE;

    -- 4. 예매 인원 테이블 INSERT
    -- 4.1. 상영관 분류, 상영 시간 분류에 따른 가격을 먼저 계산
    SELECT st.price INTO value_price
    FROM screen_schedule ss
    JOIN screen s
      ON s.screen_id = ss.screen_id
    JOIN screen_type st
      ON st.screen_type = s.screen_type
    WHERE ss.schedule_id = input_schedule_id;

    SELECT adjust_price INTO value_adjust_price
    FROM screen_schedule ss
    JOIN screen s
      ON s.screen_id = ss.screen_id
    JOIN screen_time st
      ON st.screen_time = ss.screen_time
    WHERE ss.schedule_id = input_schedule_id;

    SET value_price = value_price - value_adjust_price;
    SET value_screen_price = value_price;

    -- 4.2. 연령 분류, 인원 수에 따른 가격 계산
    SET value_index = 0;
    WHILE value_index < value_reservation_person_length DO
        SET value_age_type = JSON_UNQUOTE(JSON_EXTRACT(input_reservation_person, CONCAT('$[', value_index, '].age_type')));
        SET value_count = JSON_UNQUOTE(JSON_EXTRACT(input_reservation_person, CONCAT('$[', value_index, '].count')));

        SET value_price = value_screen_price;

        SELECT adjust_price INTO value_adjust_price
        FROM age_type
        WHERE age_type = value_age_type;

        SET value_price = value_price - value_adjust_price;
        SET value_price = value_price * value_count;

        INSERT INTO reservation_count
        SET reservation_id = value_reservation_id,
            age_type = value_age_type,
            count = value_count,
            price = value_price;
        SET value_index = value_index + 1;

        SET value_total_price = value_total_price + value_price;
    END WHILE;

    -- 5. 최종 합산 가격으로 예매 테이블 UPDATE
    UPDATE reservation
    SET price = value_total_price
    WHERE reservation_id = value_reservation_id;

    -- 6. 결제 테이블 INSERT
    INSERT INTO payment
    SET payment_type = 0,
        type_id = value_reservation_id,
        origin_amount = value_total_price,
        amount = value_total_price;

    COMMIT;
    -- ROLLBACK;
END$$

DELIMITER ;

-- 프로시저 호출 예시
CALL insert_reservation(
    2634128,
    1,
    NULL,
    '[68219, 68220, 68221]',
    '[{"age_type": "00201", "count": 2}, {"age_type": "00202", "count": 1}]'
);



