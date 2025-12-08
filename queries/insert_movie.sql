INSERT INTO movie
SET admin_id = 1,
    title = '아바타: 재와 불',
    release_date = '2025-12-17',
    running_time = 192,
    classification = '12세이상관람가',
    genre = 'SF, 액션, 어드벤처, 드라마, 로맨스, 공포(호러), 스릴러, 가족, 다큐멘터리, 범죄',
    plot = '인간들과의 전쟁으로 첫째 아들 \'네테이얌\'을 잃은 후, \'제이크\'와 \'네이티리\'는 재와 불을 이용해 세계를 멸망시키기로 한다.',
    type = '2D, 4D, DOLBY',
    director = '봉준호',
    actor = '샘 워싱턴, 조 샐다나, 시고니 위버, 송강호, 배두나';

INSERT INTO theater
SET region = '00805',
    admin_id = 2,
    name = '본리 어린이공원(우리집앞)♥',
    address = '대구광역시 달서구 본리동 충무로 293';

INSERT INTO screen
SET theater_id = 119,
    screen_type = '00104',
    name = '돌비관(사운드엄청빵빵함)';

INSERT INTO employee
SET theater_id = 119,
    admin_id = 2,
    name = '안기준',
    phone = '010-2222-3333',
    type = 0;

INSERT INTO screen_schedule
SET screen_id = 777,
    movie_id = 1003,
    employee_id = 1337,
    running_date = '2025-12-09',
    start_time = '15:30:00',
    end_time = '18:50:00';

INSERT INTO seat
SET screen_id = 777,
    row_label = 'B',
    col_no = '05';

-- 1887917
SELECT * FROM reservation WHERE schedule_id = 3097673;

CALL insert_reservation(
    3097673,
    163977,
    NULL,
    '[74346, 74347, 74348]',
    '[{"age_type": "00201", "count": 2}, {"age_type": "00202", "count": 1}]'
);


