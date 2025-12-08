DELIMITER $$

DROP PROCEDURE IF EXISTS update_payment_complete;

CREATE PROCEDURE update_payment_complete(
    IN input_payment_type INT, -- 0, 1 중 하나
    IN input_type_id BIGINT, -- 1
    IN input_payment_method INT, -- 0, 1, 2 중 하나
    IN input_payment_code VARCHAR(7), -- '00501' ~ '00512' 또는 '01201' ~ '01214' 또는 '00901' ~ '00903'
    IN input_ticket_discount JSON -- '[{"benefit_code": "01101" ~ "01103" 중 하나, "benefit_id": 1}]'
)
BEGIN
    DECLARE value_index INT DEFAULT 0;
    DECLARE value_payment_id BIGINT;
    DECLARE value_ticket_discount_count INT;
    DECLARE value_reservation_seat_count INT;
    DECLARE value_adult_total_count INT;
    DECLARE value_teen_total_count INT;
    DECLARE value_elder_total_count INT;
    DECLARE value_adult_count INT DEFAULT 0;
    DECLARE value_teen_count INT DEFAULT 0;
    DECLARE value_elder_count INT DEFAULT 0;
    DECLARE value_benefit_code VARCHAR(7);
    DECLARE value_benefit_id BIGINT;
    DECLARE value_reservation_count_price DECIMAL(10, 2);
    DECLARE value_reservation_seat_id BIGINT;
    DECLARE value_user_id BIGINT;
    DECLARE value_non_user_id BIGINT;
    DECLARE value_price DECIMAL(10, 2);
    DECLARE value_discount_total DECIMAL(10, 2) DEFAULT 0;
    DECLARE value_policy_id BIGINT;
    DECLARE value_policy_discount_amount DECIMAL(10, 2);
    DECLARE value_policy_discount_percent DECIMAL(10, 2);
    DECLARE value_policy_min_price DECIMAL(10, 2);
    DECLARE value_policy_max_benefit_amount DECIMAL(10, 2);
    DECLARE value_user_point DECIMAL(10, 2);
    DECLARE value_store_item_id BIGINT;
    DECLARE value_store_payment_type INT;

    -- 입력한 결제 수단과 결제 수단 관련 코드가 맞는지 확인
    -- 예매에 대해 결제하는 경우,
    -- 0(카드 결제)이면, '00501' ~ '00512' 중 하나
    -- 1(계좌 이체)이면, '01201' ~ '01214' 중 하나
    -- 2(휴대폰 결제)면, '00901' ~ '00903' 중 하나여야 됨
    -- 스토어 주문 내역에 대해 결제하는 경우,
    -- 상품의 주문 방식이 현금일 경우 0(카드 결제)만 가능
    -- 상품의 주문 방식이 포인트일 경우 결제 수단 없어도 됨
    if input_payment_method = 0 THEN
        if input_payment_code < '00501' OR input_payment_code > '00512' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '잘못된 입력입니다. - 카드사 코드';
        END if;
    else
        if input_payment_type <> 1 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '스토어 상품은 카드 결제로만 구매 가능합니다.';
        END if;

        if input_payment_method = 1 THEN
            if input_payment_code < '01201' OR input_payment_code > '01214' THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '잘못된 입력입니다. - 은행 코드';
            END if;
        elseif input_payment_method = 2 THEN
            if input_payment_code < '00901' OR input_payment_code > '00903' THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '잘못된 입력입니다. - 통신사 코드';
            END if;
        else
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '잘못된 입력입니다. - 결제 수단';
        END if;
    END if;

    -- 결제 ID 조회
    SELECT payment_id INTO value_payment_id
    FROM payment
    WHERE type_id = input_type_id;

    if input_payment_type = 0 THEN
        -- 1. '완료' 된 데이터가 예매일 경우
        -- 1.1. 입력한 예매의 ID로 필요한 데이터를 조회하여 NULL인지 확인
        SELECT user_id, non_user_id INTO value_user_id, value_non_user_id
        FROM reservation
        WHERE reservation_id = input_type_id;

        if value_user_id IS NULL AND value_non_user_id IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '등록되지 않은 예매 ID를 입력하였습니다.';
        END if;

        -- 1.2. 회원의 예매인 경우 좌석 단위로 적용되는 할인 금액 합산
        if value_user_id IS NOT NULL THEN
            -- 1.2.1. 입력한 예매 ID의 예매 좌석 수와 연령대별 예매 인원 수를 조회
            SELECT COUNT(1) INTO value_reservation_seat_count
            FROM reservation_seat_list
            WHERE reservation_id = input_type_id;

            SELECT SUM(count) INTO value_adult_total_count
            FROM reservation_count
            WHERE reservation_id = input_type_id
              AND age_type = '00201';

            SELECT SUM(count) INTO value_teen_total_count
            FROM reservation_count
            WHERE reservation_id = input_type_id
              AND age_type = '00202';

            SELECT SUM(count) INTO value_elder_total_count
            FROM reservation_count
            WHERE reservation_id = input_type_id
              AND age_type = '00203';

            -- 1.2.2. 입력한 좌석 단위 할인의 수를 계산
            SET value_ticket_discount_count = JSON_LENGTH(input_ticket_discount);

            if value_ticket_discount_count = 1
               AND JSON_EXTRACT(input_ticket_discount, '$[0].benefit_code') = '01101' THEN
                -- 1.2.2.1. 좌석 단위 할인의 수단이 포인트인 경우
                -- 포인트로 할인을 받는 경우, 반드시 티켓 가격의 100%를 사용해야 함
                -- 입력한 할인 혜택 ID(회원 ID)를 가진 회원이 있는지 확인
                SET value_benefit_code = '01101';
                SET value_benefit_id = JSON_UNQUOTE(JSON_EXTRACT(input_ticket_discount, CONCAT('$[0].benefit_id')));

                if NOT EXISTS (SELECT 1 FROM user WHERE user_id = value_benefit_id) THEN
                     SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '입력한 회원 ID가 존재하지 않습니다.';
                END if;
            else
                -- 1.2.2.2. 좌석 단위 할인의 수단이 포인트가 아닌 경우
                -- 입력한 좌석 단위 할인의 수와 연령대별 인원 수가 맞는지 확인
                if value_ticket_discount_count = value_adult_total_count + value_teen_total_count + value_elder_total_count THEN
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '입력한 좌석 단위 할인 수와 예매 인원 수가 맞지 않습니다.';
                END if;
            END if;

            -- 1.2.3. 예매 인원 수만큼 좌석 단위 할인 테이블에 INSERT
            WHILE value_index < value_reservation_seat_count DO
                -- 1.2.3.1. 예매 좌석 ID를 순서대로 하나씩 조회
                SELECT reservation_seat_id INTO value_reservation_seat_id
                FROM reservation_seat_list
                WHERE reservation_id = input_type_id
                ORDER BY reservation_seat_id
                LIMIT 1 OFFSET value_index;

                -- 1.2.3.2. 연령대별 인원 수가 총 인원 수에 맞을 때까지 합산
                if value_adult_count < value_adult_total_count THEN
                    SELECT price INTO value_reservation_count_price
                    FROM reservation_count
                    WHERE reservation_id = input_type_id
                      AND age_type = '00201';

                    -- 한 연령대 분류의 인원 수가 2명 이상이라면, 가격 / 인원 수를 해야 그 연령대 분류의 1명의 가격이 나옴
                    if value_adult_total_count > 1 THEN
                        SET value_reservation_count_price = value_reservation_count_price / value_adult_total_count;
                    END if;

                    SET value_adult_count = value_adult_count + 1;
                elseif value_teen_count < value_teen_total_count THEN
                    SELECT price INTO value_reservation_count_price
                    FROM reservation_count
                    WHERE reservation_id = input_type_id
                      AND age_type = '00202';

                    if value_teen_total_count > 1 THEN
                        SET value_reservation_count_price = value_reservation_count_price / value_teen_total_count;
                    END if;

                    SET value_teen_count = value_teen_count + 1;
                elseif value_elder_count < value_elder_total_count THEN
                    SELECT price INTO value_reservation_count_price
                    FROM reservation_count
                    WHERE reservation_id = input_type_id
                      AND age_type = '00203';

                    if value_elder_total_count > 1 THEN
                        SET value_reservation_count_price = value_reservation_count_price / value_elder_total_count;
                    END if;

                    SET value_elder_count = value_elder_count + 1;
                END if;

                -- 1.2.3.3. 입력한 할인 혜택 ID(쿠폰 또는 교환권 ID)를 가진 쿠폰 또는 교환권이 있는지 확인
                if value_ticket_discount_count > 1
                   OR (value_ticket_discount_count = 1 AND JSON_EXTRACT(input_ticket_discount, '$[0].benefit_code') <> '01101') THEN
                    SET value_benefit_code = JSON_UNQUOTE(JSON_EXTRACT(input_ticket_discount, CONCAT('$[', value_index, '].benefit_code')));
                    SET value_benefit_id = JSON_UNQUOTE(JSON_EXTRACT(input_ticket_discount, CONCAT('$[', value_index, '].benefit_id')));

                    if value_benefit_code = '00202' THEN
                        if NOT EXISTS (SELECT 1 FROM coupon_detail WHERE user_coupon_id = value_benefit_id) THEN
                            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '입력한 쿠폰 ID가 존재하지 않습니다.';
                        END if;
                    elseif value_benefit_code = '00203' THEN
                        if NOT EXISTS (SELECT 1 FROM user_voucher WHERE user_voucher_id = value_benefit_id) THEN
                            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '입력한 교환권 ID가 존재하지 않습니다.';
                        END if;
                    END if;
                END if;

                -- 1.2.3.4. 좌석 단위 할인 테이블에 INSERT
                INSERT INTO ticket_discount
                SET reservation_seat_id = value_reservation_seat_id,
                    benefit_code = value_benefit_code,
                    benefit_id = value_benefit_id,
                    applied_amount = value_reservation_count_price;

                -- 1.2.3.5. 결제 테이블에 UPDATE될 총 할인 합계에 할인 적용된 금액을 더함
                SET value_discount_total = value_discount_total + value_reservation_count_price;

                SET value_index = value_index + 1;
            END WHILE;
        END if;

        if input_payment_method = 0 THEN
            -- 1.1.1. 카드 결제인 경우
            -- 1.1.1.1. 할인 정책 테이블 조회하여 적용되는 할인이 있는지 확인
            SELECT policy_id, discount_amount, discount_percent, min_price, max_benefit_amount
              INTO value_policy_id, value_policy_discount_amount, value_policy_discount_percent,
                   value_policy_min_price, value_policy_max_benefit_amount
            FROM discount_policy
            WHERE partner_id = input_payment_code;

            -- 1.1.1.2. 할인 정책이 있을 경우
            if value_policy_id IS NOT NULL THEN
                -- 1.1.1.2.1. 결제할 금액이 할인 적용 가능 최소 금액 이하인지 확인
                if value_price - value_discount_total <= value_policy_min_price THEN
                    -- 1.1.1.2.2. 할인 적용된 금액이 최대 할인 금액이 넘지 않게 할인 금액 또는 할인율 적용
                    if value_policy_discount_amount IS NOT NULL THEN
                        SET value_discount_total = value_discount_total + value_policy_discount_amount;
                    elseif value_policy_discount_percent IS NOT NULL THEN
                        if (value_price - value_discount_total) * (value_policy_discount_percent / 100) <= value_policy_max_benefit_amount THEN
                            SET value_discount_total = value_discount_total + ((value_price - value_discount_total) * (value_policy_discount_percent / 100));
                        else
                            SET value_discount_total = value_discount_total + value_policy_max_benefit_amount;
                        END if;
                    END if;
                END if;
            END if;

            -- 1.1.1.3. 결제 수단(카드) 테이블에 INSERT
            INSERT INTO payment_card
            SET payment_id = value_payment_id,
                card_company_code = input_payment_code,
                card_number = LPAD(FLOOR(RAND() * 10000), 4, '0'),
                installment_months = IF(value_price - value_discount_total >= 50000, FLOOR(RAND() * 11) + 2, 0), -- 가격이 5만원 이상이면 2~12 중 랜덤, 아니면 0으로 입력
                card_approval_number = LPAD(FLOOR(RAND() * 10000), 6, '0');
        elseif input_payment_method = 1 THEN
            -- 1.1.2. 계좌 이체인 경우 결제 수단(계좌 이체) 테이블에 INSERT
            INSERT INTO payment_bank_transfer
            SET payment_id = value_payment_id,
                bank_code = input_payment_code,
                account_number = CONCAT(LPAD(FLOOR(RAND() * 1000000), 6, '0'), '-', LPAD(FLOOR(RAND() * 100), 2, '0'), '-',  LPAD(FLOOR(RAND() * 1000000), 6, '0')),
                account_holder_name = func_create_random_name();
        elseif input_payment_method = 2 THEN
            -- 1.1.2. 계좌 이체인 경우 결제 수단(휴대폰 결제) 테이블에 INSERT
            INSERT INTO payment_mobile
            SET payment_id = value_payment_id,
                carrier_code = input_payment_code,
                phone_number = CONCAT('010-', LPAD(FLOOR(RAND() * 10000), 4, '0'), '-', LPAD(FLOOR(RAND() * 10000), 4, '0')),
                approval_code = LPAD(FLOOR(RAND() * 10000000000), 10, '0');
        END if;

        -- 결제 테이블의 결제 금액, 할인 금액, 상태를 '완료'로 UPDATE
        UPDATE payment
        SET origin_amount = value_price,
            discount_total = value_discount_total,
            amount = value_price - value_discount_total,
            status = 1
        WHERE type_id = input_type_id;
    elseif input_payment_type = 1 THEN
        -- 2. '완료' 된 데이터가 스토어 주문 내역일 경우
        -- 2.1. 입력한 스토어 주문 내역의 ID로 필요한 데이터를 조회하여 NULL인지 확인
        SELECT store_item_id, user_id, price INTO value_store_item_id, value_user_id, value_price
        FROM `order`
        WHERE order_id = input_type_id;

        if value_store_item_id IS NULL OR value_user_id IS NULL OR value_price IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '등록되지 않은 상품 ID를 입력하였습니다.';
        END if;

        -- 2.2. 주문한 상품의 결제 방식이 '현금' 인지 '포인트' 인지 확인
        SELECT payment_type INTO value_store_payment_type
        FROM store_item
        WHERE store_item_id = value_store_item_id;

        if value_store_payment_type = 0 THEN
            -- 2.2.1. 주문한 상품의 결제 방식이 '현금' 일 경우
            -- 2.2.1.1. 결제 테이블의 결제 금액, 상태를 '완료' 로 UPDATE
            UPDATE payment
            SET payment_method = input_payment_method,
                origin_amount = value_price,
                amount = value_price,
                status = 1
            WHERE type_id = input_type_id;

            -- 2.2.1.2. 결제 수단 - 카드 테이블에 INSERT(스토어 상품은 카드 결제로만 구매 가능)
            INSERT INTO payment_card
            SET payment_id = value_payment_id,
                card_company_code = input_payment_code,
                card_number = LPAD(FLOOR(RAND() * 10000), 4, '0'),
                installment_months = IF(value_price >= 50000, FLOOR(RAND() * 11) + 2, 0), -- 가격이 5만원 이상이면 2~12 중 랜덤, 아니면 0으로 입력
                card_approval_number = LPAD(FLOOR(RAND() * 10000), 6, '0');
        elseif value_store_payment_type = 1 THEN
            -- 2.2.2. 주문한 상품의 결제 방식이 '포인트' 일 경우
            -- 2.2.2.1. 상품을 주문한 회원의 보유 포인트를 조회
            SELECT point INTO value_user_point
            FROM user
            WHERE user_id = value_user_id;

            if value_user_point < value_price THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '회원의 보유 포인트가 부족합니다.';
            END if;

            -- 2.2.2.2. 포인트 사용 내역 테이블에 INSERT
            INSERT INTO point_log
            SET user_id = value_user_id,
                change_amount = -value_price,
                balance_after = value_user_point - value_price,
                status = 1;

            -- 이후 포인트 사용 내역 AFTER INSERT 트리거로 인해 유저의 보유 포인트가 UPDATE 됨

            -- 2.2.2.3. 결제 테이블의 결제 금액, 상태를 '완료'로 UPDATE
            UPDATE payment
            SET origin_amount = value_price,
                amount = value_price,
                status = 1
            WHERE type_id = input_type_id;
        END if;
    END if;
END$$

DELIMITER ;

-- 프로시저 호출 예시(예매)
CALL update_payment_complete(
     1,
     1,
     0,
     '01201',
     '[{"benefit_code": "01101", "benefit_id": 1}]'
);

-- 프로시저 호출 예시(스토어)
CALL update_payment_complete(
     1,
     17827,
     0,
     ELT(FLOOR(1 + RAND() * 12),
        '00501', '00502', '00503', '00504', '00505', '00506',
        '00507', '00508', '00509', '00510', '00511', '00512'
     ),
     NULL
);