DELIMITER $$

DROP TRIGGER IF EXISTS trg_ticket_discount_after_delete;

CREATE TRIGGER trg_ticket_discount_after_delete
    AFTER DELETE ON ticket_discount
    FOR EACH ROW
BEGIN
    if OLD.benefit_code = '01101' THEN
        -- 포인트
        -- 해당 유저에 관한 포인트 사용 내역 데이터를 등록
        INSERT INTO point_log
        SET user_id = OLD.benefit_id,
            change_amount = OLD.applied_amount,
            balance_after = (SELECT point FROM user WHERE user_id = OLD.benefit_id) + OLD.applied_amount,
            status = 3,
            created_at = NOW();

        -- 이후 포인트 사용 내역 AFTER INSERT 트리거로 인해 유저의 보유 포인트가 UPDATE 됨
    elseif OLD.benefit_code = '01102' THEN
        -- 쿠폰
        -- 유저별 보유 쿠폰 상태를 '취소' 으로 변경
        UPDATE coupon_detail
        SET status = 0,
            use_at = NULL
        WHERE user_coupon_id = OLD.benefit_id;

        -- 이후 유저별 보유 쿠폰 AFTER UPDATE 트리거로 인해 포인트 사용 내역 테이블에 INSERT 됨
    elseif OLD.benefit_code = '01103' THEN
        -- 교환권
        -- 유저별 보유 교환권 상태를 '취소' 로 변경
        UPDATE user_voucher
        SET status = 0,
            use_at = NULL
        WHERE user_voucher_id = OLD.benefit_id;

        -- 이후 유저별 보유 교환권 AFTER UPDATE 트리거로 인해 교환권 사용 내역 테이블에 INSERT 됨
    END if;
END$$

DELIMITER ;