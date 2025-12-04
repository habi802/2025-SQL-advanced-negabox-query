DELIMITER $$

DROP FUNCTION IF EXISTS func_create_random_name;

CREATE FUNCTION func_create_random_name()
RETURNS VARCHAR(10)
BEGIN
    DECLARE last_name VARCHAR(5);
    DECLARE first1 VARCHAR(5);
    DECLARE first2 VARCHAR(5);

    SELECT ELT(FLOOR(1 + RAND() * 30),
        '김','이','박','최','정','강','조','윤','장','임',
        '오','한','신','서','권','황','안','송','전','홍',
        '유','고','문','양','손','배','백','허','유','남'
    ) INTO last_name;

    SELECT ELT(FLOOR(1 + RAND() * 20),
        '민','서','윤','지','현','우','진','수','영','훈',
        '아','리','해','유','태','나','도','정','희','솔'
    ) INTO first1;

    SELECT ELT(FLOOR(1 + RAND() * 20),
        '민','서','윤','지','현','우','진','수','영','훈',
        '아','리','해','유','태','나','도','정','희','솔'
    ) INTO first2;

    RETURN CONCAT(last_name, first1, first2);
END$$

DELIMITER ;