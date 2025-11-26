DELIMITER $$

-- 예매 좌석, 예매, 예매별 예매 좌석, 예매 인원 테이블 순으로 INSERT하는 프로시저
CREATE PROCEDURE insert_reservation(
    IN input_schedule_id BIGINT, -- 1
    IN input_user_id BIGINT, -- 1 or NULL
    IN input_non_user_id BIGINT, -- 1 or NULL
    IN input_seat_id JSON, -- '[1, 2, 3]'
    IN input_reservation_person JSON -- '[{"age_type": "00201", "count": 2}]'
)
BEGIN
    DECLARE value_seat_count INT;
    DECLARE value_reservation_id BIGINT;
    DECLARE value_reservation_person_count INT;
    DECLARE now_date_time DATETIME;
    DECLARE screen_running_date DATE;
    DECLARE screen_start_time TIME;
    DECLARE value_age_type VARCHAR(7);
    DECLARE value_count INT;
    DECLARE value_price INT;
    DECLARE value_screen_price INT;
    DECLARE value_adjust_price INT DEFAULT 0;
    DECLARE value_index INT DEFAULT 0;

    -- 트랜잭션 시작: 프로시저 실행 중 실패하면 프로시저 실행 전으로 롤백함
    START TRANSACTION;

    if (input_user_id IS NOT NULL AND input_non_user_id IS NOT NULL) OR
       (input_user_id IS NULL AND input_non_user_id IS NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '회원 ID와 비회원 ID 중 반드시 하나는 입력되어야 합니다.';
    END if;

    SET value_seat_count = JSON_LENGTH(input_seat_id);
    SET value_reservation_person_count = JSON_LENGTH(input_reservation_person);
    if value_seat_count != value_reservation_person_count THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '예매 좌석 수와 인원 수가 맞지 않습니다.';
    END if;

    SET now_date_time = NOW();

    SELECT running_date, TIMESTAMP(running_date, start_time) INTO screen_running_date, screen_start_time
    FROM screen_schedule
    WHERE schedule_id = input_schedule_id;

    if DATE(now_date_time) > screen_running_date THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '이미 상영이 종료된 일정은 예매를 등록할 수 없습니다.';
    elseif now_date_time > screen_start_time THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '상영 시작 20분 전부터는 예매를 등록할 수 없습니다.';
    END if;

    -- 1. 예매 좌석 테이블 INSERT
    WHILE value_index < value_seat_count DO
        INSERT INTO reservation_seat
        SET schedule_id = input_schedule_id,
            seat_id = JSON_UNQUOTE(JSON_EXTRACT(input_seat_id, CONCAT('$[', value_index, ']')));
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
            reservation_seat_id = JSON_UNQUOTE(JSON_EXTRACT(input_seat_id, CONCAT('$[', value_index, ']')));
        SET value_index = value_index + 1;
    END WHILE;

    -- 4. 예매 인원 테이블 INSERT
    -- 상영관 분류, 상영 시간 분류에 따른 가격을 먼저 계산
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

    SET value_index = 0;
    WHILE value_index < value_reservation_person_count DO
        SET value_age_type = JSON_UNQUOTE(JSON_EXTRACT(input_reservation_person, CONCAT('$[', value_index, '].age_type')));
        SET value_count = JSON_UNQUOTE(JSON_EXTRACT(input_reservation_person, CONCAT('$[', value_index, '].count')));

        -- 연령 분류, 인원 수에 따른 가격 계산
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
    END WHILE;
END$$

DELIMITER ;

-- 프로시저 호출 예시
CALL insert_reservation(
    1,
    1,
    NULL,
    '[1]',
    '[{"age_type": "00201", "count": 2}]'
);



