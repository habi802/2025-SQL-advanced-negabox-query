-- 테스트를 위해 온갖 잡다한 거 다 적어놓음
EXPLAIN
SELECT * FROM user;

DELETE FROM reservation WHERE reservation_id = 221182;
DELETE FROM reservation_seat_list WHERE reservation_id = 1550004;
DELETE FROM reservation_count WHERE reservation_id = 1550004;
DELETE FROM reservation_seat WHERE schedule_id = 2634128;

SHOW PROCEDURE STATUS;
SHOW PROCESSLIST;

KILL 60;
KILL 61;
KILL 62;
KILL 63;
KILL 64;
KILL 65;
KILL 79;
KILL 81;
KILL 82;
KILL 69;

SELECT schedule_id, start_time
FROM screen_schedule
WHERE running_date = '2025-11-27'
  AND start_time > '20:00:00'
ORDER BY start_time;


SELECT se.*
FROM screen_schedule ss
JOIN seat se
  ON se.screen_id = ss.screen_id
WHERE ss.schedule_id = 2634128;