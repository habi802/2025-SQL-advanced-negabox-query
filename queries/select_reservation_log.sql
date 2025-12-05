-- 1. 예매내역(오늘), 지난예매(6개월), 예매취소(7일)
-- EXPLAIN
EXPLAIN ANALYZE
SELECT m.title AS 영화,
       r.created_at AS 예매시간,
       ss.running_date AS 상영일,
       ss.start_time AS 시작시간,
       t.`name` AS 지점,
       s.`name` AS 상영관,
       r.price AS 가격,
       CASE r.status
           WHEN 1 THEN IF(TIMESTAMP(ss.running_date, ss.start_time) >= NOW(), '지난예매', '영화예매')
           WHEN 2 THEN '예매취소'
       END AS 상태
FROM reservation r
JOIN screen_schedule ss
  ON ss.schedule_id = r.schedule_id
JOIN movie m
  ON m.movie_id = ss.movie_id
JOIN screen s
  ON s.screen_id = ss.screen_id
JOIN theater t
  ON t.theater_id = s.theater_id
WHERE r.user_id = 49999
  AND r.created_at >= CURDATE()
  AND r.created_at < CURDATE() + INTERVAL 1 DAY;

SELECT m.title AS 영화,
       r.created_at AS 예매시간,
       ss.running_date AS 상영일,
       ss.start_time AS 시작시간,
       t.`name` AS 지점,
       s.`name` AS 상영관,
       r.price AS 가격,
       IF(TIMESTAMP(ss.running_date, ss.start_time) <= NOW(), '지난예매', '영화예매') AS 상태
FROM reservation r
JOIN screen_schedule ss
  ON ss.schedule_id = r.schedule_id
JOIN movie m
  ON m.movie_id = ss.movie_id
JOIN screen s
  ON s.screen_id = ss.screen_id
JOIN theater t
  ON t.theater_id = s.theater_id
WHERE r.user_id = 49999
  AND r.status = 1
  AND r.created_at >= NOW() - INTERVAL 6 MONTH;

SELECT m.title AS 영화,
       r.created_at AS 예매시간,
       ss.running_date AS 상영일,
       ss.start_time AS 시작시간,
       t.`name` AS 지점,
       s.`name` AS 상영관,
       r.price AS 가격,
       '예매취소' AS 상태
FROM reservation r
JOIN screen_schedule ss
  ON ss.schedule_id = r.schedule_id
JOIN movie m
  ON m.movie_id = ss.movie_id
JOIN screen s
  ON s.screen_id = ss.screen_id
JOIN theater t
  ON t.theater_id = s.theater_id
WHERE r.user_id = 49999
  AND r.status = 2
  AND r.created_at >= NOW() - INTERVAL 7 DAY;