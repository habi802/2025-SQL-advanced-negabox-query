-- 테스트를 위해 온갖 잡다한 거 다 적어놓음
SET GLOBAL event_scheduler = ON;

ALTER TABLE screen_schedule AUTO_INCREMENT = 3097673;

SET FOREIGN_KEY_CHECKS = 0;
SET FOREIGN_KEY_CHECKS = 1;

SELECT @@SESSION.FOREIGN_KEY_CHECKS;

INSERT INTO screen_schedule
        SET screen_id = 1,
            movie_id = 1,
            employee_id = 3,
            running_date = '2025-12-31',
            start_time = '15:00:00',
            end_time = '18:00:00';

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

UPDATE review r
SET r.like_count = (
    SELECT COUNT(1)
    FROM review_like rl
    WHERE rl.review_id = r.review_id
);

SELECT * FROM payment WHERE type_id = 1887918;

UPDATE store_item
SET start_date = '2025-12-05',
    is_active = 1
WHERE store_item_id = 21;

INSERT INTO `order`
SET user_id = 163977,
    store_item_id = 21,
    quantity = 12,
    unit_price = 18500.00,
    price = 18500.00;