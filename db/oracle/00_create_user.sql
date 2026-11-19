-- =====================================================================
-- 00. 쇼핑몰 전용 계정(SHOPMALL) 만들기
--     ※ 반드시 system 계정으로 실행합니다. (최초 1회)
--     이미 계정이 있으면 아무것도 지우지 않고 넘어갑니다.
-- =====================================================================
SET DEFINE OFF
SET SERVEROUTPUT ON

DECLARE
  v_cnt NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_cnt FROM dba_users WHERE username = 'SHOPMALL';
  IF v_cnt = 0 THEN
    EXECUTE IMMEDIATE 'CREATE USER shopmall IDENTIFIED BY shop1234 '
                   || 'DEFAULT TABLESPACE users QUOTA UNLIMITED ON users';
    DBMS_OUTPUT.PUT_LINE('SHOPMALL 계정을 만들었습니다.');
  ELSE
    DBMS_OUTPUT.PUT_LINE('SHOPMALL 계정이 이미 있습니다. 그대로 사용합니다.');
  END IF;
END;
/

-- CONNECT  : 접속 권한
-- RESOURCE : 테이블, 시퀀스, 트리거를 만들 수 있는 권한
-- CREATE VIEW : 뷰는 RESOURCE에 포함되지 않아서 따로 줍니다
GRANT CONNECT, RESOURCE, CREATE VIEW TO shopmall;

EXIT
