-- 1. 박스오피스 조회
EXPLAIN
-- EXPLAIN ANALYZE
SELECT DENSE_RANK() OVER (ORDER BY bo.reserve_count DESC) AS 순위,
       bo.title AS 영화,
       ROUND(bo.reserve_count / total_reserve * 100, 2) AS 예매율,
       bo.reserve_count AS 관객수
FROM (
    SELECT m.title, COUNT(rs.reservation_seat_id) AS reserve_count,
           (SELECT COUNT(1) FROM reservation_seat) AS total_reserve
    FROM movie m
    JOIN screen_schedule ss ON ss.movie_id = m.movie_id
    JOIN reservation_seat rs ON rs.schedule_id = ss.schedule_id
    WHERE m.is_delete = 0
    GROUP BY m.movie_id
) AS bo;

