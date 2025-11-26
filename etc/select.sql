-- 테스트를 위해 온갖 잡다한 거 다 적어놓음
EXPLAIN
SELECT * FROM user;

DELETE FROM reservation WHERE reservation_id = 1550004;
DELETE FROM reservation_seat_list WHERE reservation_id = 1550004;
DELETE FROM reservation_count WHERE reservation_id = 1550004;
DELETE FROM reservation_seat WHERE reservation_seat_id = 1739478;

SHOW PROCEDURE STATUS;
SHOW PROCESSLIST;

KILL 60401;

SELECT schedule_id, start_time
FROM screen_schedule
WHERE running_date = '2025-11-27'
  AND start_time > '19:00:00'
ORDER BY start_time;


SELECT se.*
FROM screen_schedule ss
JOIN seat se
  ON se.screen_id = ss.screen_id
WHERE ss.schedule_id = 2134366;