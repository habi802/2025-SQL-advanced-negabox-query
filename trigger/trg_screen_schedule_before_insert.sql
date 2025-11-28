DELIMITER $$

DROP TRIGGER IF EXISTS trg_screen_schedule_before_insert;

CREATE TRIGGER trg_screen_schedule_before_insert
    BEFORE INSERT ON screen_schedule
    FOR EACH ROW
BEGIN
    -- 상영 일정 등록 전에 입력한 값에 대한 검증을 하고, 필요한 컬럼 값을 얻는 트리거
    /*
    상영 일정 등록 시 입력 받는 컬럼
    상영관 ID - screen_id = 1
    영화 ID - movie_id = 1
    직원(매니저) ID - employee_id = 3
    상영일 - running_date = '2025-11-01'
    상영 시작 시간 - start_time = '15:00:00'
    상영 종료 시간 - end_time = '18:00:00'
    */
	DECLARE new_screen_type VARCHAR(7);
	DECLARE new_screen_time VARCHAR(7);

	-- 입력한 상영관 id가 존재하는지 확인
	if NOT EXISTS (SELECT 1 FROM screen WHERE screen_id = NEW.screen_id AND is_delete = 0) THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '등록되지 않은 상영관입니다.';
	END if;

	-- 입력한 영화 id가 존재하는지 확인
	if NOT EXISTS (SELECT 1 FROM movie WHERE movie_id = NEW.movie_id AND is_delete = 0) THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '등록되지 않은 영화입니다.';
	END if;

	-- 입력한 직원(매니저) id가 존재하는지 확인
	if NOT EXISTS (SELECT 1 FROM employee WHERE employee_id = NEW.employee_id AND is_active = 0) THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '등록되지 않은 직원입니다.';
	elseif NOT EXISTS (SELECT 1 FROM employee WHERE employee_id = NEW.employee_id AND type = 1) THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '상영 일정 등록은 매니저만 가능합니다.';
	END if;

	-- 상영 시작 시간이 종료 시간보다 늦는지 확인
	if NEW.start_time >= NEW.end_time THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '상영 시작 시간이 종료 시간보다 늦습니다.';
	END if;

	-- 같은 상영관, 상영일에 상영 시간이 겹치는 상영 일정이 있는지 확인
	if EXISTS (
		SELECT 1
		FROM screen_schedule
		WHERE screen_id = NEW.screen_id
		  AND running_date = NEW.running_date
		  AND NEW.start_time < end_time
		  AND NEW.end_time > start_time
	) THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '입력한 상영 시간에 겹치는 상영 일정이 존재합니다.';
	END if;

	-- 상영관 분류 코드를 입력하기 위해 입력한 상영관 id로 조회
	SELECT screen_type INTO new_screen_type
	FROM screen
	WHERE screen_id = NEW.screen_id;

	-- 상영 시간 분류 코드를 입력하기 위해 입력한 상영 시작 시간으로 조회
	SELECT screen_time INTO new_screen_time
	FROM screen_time
	WHERE (NEW.start_time >= start_time AND NEW.start_time < end_time)
	   OR (start_time > end_time AND (NEW.start_time >= start_time OR NEW.start_time < end_time));

	SET NEW.screen_type = new_screen_type;
	SET NEW.screen_time = new_screen_time;
END$$

DELIMITER ;