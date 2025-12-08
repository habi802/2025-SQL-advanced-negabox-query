-- 1. 지점을 선택하여(3개 정도) 상영 일정 조회하는 쿼리를 만듦
-- EXPLAIN
EXPLAIN ANALYZE
SELECT t.`name` AS 지점,
       s.`name` AS 상영관,
       IF(s_time_cc.`name` = '조조', '조조', '') AS 구분,
       m.title AS 영화,
	   ss.running_date AS 상영일,
	   ss.start_time AS 시작시간,
	   ss.end_time AS 종료시간
FROM screen_schedule ss
JOIN screen s ON s.screen_id = ss.screen_id
JOIN theater t ON t.theater_id = s.theater_id
JOIN common_code s_type_cc ON s_type_cc.code_id = ss.screen_type
JOIN common_code s_time_cc ON s_time_cc.code_id = ss.screen_time
JOIN movie m ON m.movie_id = ss.movie_id
WHERE t.theater_id IN (1, 2, 3)
  AND (
          ss.running_date > CURDATE()
          OR
          ss.running_date = CURDATE() AND ss.start_time >= CURTIME()
      )
  AND ss.is_delete = 0
ORDER BY s.theater_id, s.screen_id, ss.running_date, ss.start_time;

-- 2. WHERE 조건에 있는 컬럼으로 인덱스 만듦
ALTER TABLE screen_schedule
ADD INDEX IDX_screen_schedule (is_delete, running_date, start_time);

-- 3. theater와 연결되는 screen_id를 추가하여 인덱스를 다시 만듦
DROP INDEX IDX_screen_schedule ON screen_schedule;

ALTER TABLE screen_schedule
ADD INDEX IDX_screen_schedule (screen_id, is_delete, running_date, start_time);

-- 4. FORCE INDEX 사용
EXPLAIN
-- EXPLAIN ANALYZE
SELECT t.`name` AS 지점,
       s.`name` AS 상영관,
       IF(s_time_cc.`name` = '조조', '조조', '') AS 구분,
       m.title AS 영화,
	   ss.running_date AS 상영일,
	   ss.start_time AS 시작시간,
	   ss.end_time AS 종료시간
FROM screen_schedule ss FORCE INDEX (IDX_screen_schedule)
JOIN screen s ON s.screen_id = ss.screen_id
JOIN theater t ON t.theater_id = s.theater_id
JOIN common_code s_type_cc ON s_type_cc.code_id = ss.screen_type
JOIN common_code s_time_cc ON s_time_cc.code_id = ss.screen_time
JOIN movie m ON m.movie_id = ss.movie_id
WHERE t.theater_id IN (1, 2, 3)
  AND (
          ss.running_date > CURDATE()
          OR
          ss.running_date = CURDATE() AND ss.start_time >= CURTIME()
      )
  AND ss.is_delete = 0
ORDER BY s.theater_id, s.screen_id, ss.running_date, ss.start_time;

SHOW INDEX FROM screen_schedule;

