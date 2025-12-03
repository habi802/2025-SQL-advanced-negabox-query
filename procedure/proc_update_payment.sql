DELIMITER $$

DROP PROCEDURE IF EXISTS update_payment;

CREATE PROCEDURE update_payment(
    IN input_payment_type INT, -- 0, 1 중 하나
    IN input_type_id BIGINT, -- 1
    IN input_payment_method INT, -- 0, 1, 2 중 하나
    IN input_payment_code VARCHAR(7), -- '00501' ~ '00512' 또는 '01201' ~ '01214' 또는 '00901' ~ '00903'
    IN input_ticket_discount JSON -- '[{"reservation_seat_id": 1, "benefit_code": "01101", "benefit_id": 1}]'
)
BEGIN
    DECLARE value_user_id BIGINT;
    DECLARE value_non_user_id BIGINT;
    DECLARE value_price DECIMAL(10, 2);
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

    if input_payment_type = 0 THEN
        -- 1. '완료' 된 데이터가 예매일 경우

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
            SET card_company_code = input_payment_code,
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