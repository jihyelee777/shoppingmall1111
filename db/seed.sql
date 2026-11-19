-- 샘플 데이터 (schema.sql 실행 후)
USE shoppingmall;

-- 회원 (비밀번호는 예시 해시값)
INSERT INTO member (id, email, password_hash, name, phone) VALUES
  (1, 'user1@example.com', '$2b$10$examplehashexamplehashexamplehashexample', '홍길동', '010-1111-2222'),
  (2, 'user2@example.com', '$2b$10$examplehashexamplehashexamplehashexample', '김철수', '010-3333-4444');

INSERT INTO member_address (member_id, alias, recipient, phone, zipcode, address1, address2, is_default) VALUES
  (1, '집', '홍길동', '010-1111-2222', '06236', '서울 강남구 테헤란로 123', '101동 1001호', TRUE);

-- 카테고리 (계층)
INSERT INTO category (id, parent_id, name, depth, sort_order) VALUES
  (1, NULL, '의류', 1, 1),
  (2, 1,    '상의', 2, 1),
  (3, NULL, '디지털', 1, 2),
  (4, 3,    '이어폰', 2, 1);

-- 상품
INSERT INTO product (id, category_id, name, brand, model_code, description, base_price, sale_price) VALUES
  (1, 2, '베이직 코튼 티셔츠', 'OURBRAND', NULL,      '면 100% 기본 티셔츠', 19900, 15900),
  (2, 4, '무선 블루투스 이어폰 X1', 'SoundCo', 'SC-X1', '노이즈캔슬링 지원', 129000, 99000);

INSERT INTO product_image (product_id, url, is_main, sort_order) VALUES
  (1, '/images/p1_main.jpg', TRUE, 0),
  (2, '/images/p2_main.jpg', TRUE, 0);

-- 옵션: 티셔츠 = 색상 x 사이즈, 이어폰 = 색상
INSERT INTO option_group (id, product_id, name, sort_order) VALUES
  (1, 1, '색상', 1), (2, 1, '사이즈', 2), (3, 2, '색상', 1);

INSERT INTO option_value (id, option_group_id, value, sort_order) VALUES
  (1, 1, '블랙', 1), (2, 1, '화이트', 2),
  (3, 2, 'M', 1),   (4, 2, 'L', 2),
  (5, 3, '블랙', 1), (6, 3, '화이트', 2);

-- SKU
INSERT INTO product_variant (id, product_id, sku_code, extra_price, stock_qty) VALUES
  (1, 1, 'TS-BK-M', 0,    50),
  (2, 1, 'TS-BK-L', 0,    30),
  (3, 1, 'TS-WH-M', 0,    40),
  (4, 1, 'TS-WH-L', 1000, 0),
  (5, 2, 'X1-BK',   0,    100),
  (6, 2, 'X1-WH',   3000, 20);

INSERT INTO variant_option_value (variant_id, option_value_id) VALUES
  (1,1),(1,3), (2,1),(2,4), (3,2),(3,3), (4,2),(4,4), (5,5), (6,6);

-- 장바구니 / 찜
INSERT INTO cart_item (member_id, variant_id, quantity) VALUES (1, 2, 2), (1, 5, 1);
INSERT INTO wishlist (member_id, product_id) VALUES (1, 2), (2, 1);

-- 쿠폰
INSERT INTO coupon (id, code, name, discount_type, discount_value, max_discount, min_order_amount, valid_from, valid_to) VALUES
  (1, 'WELCOME10', '신규가입 10% 할인', 'RATE', 10, 10000, 30000, '2026-01-01', '2026-12-31 23:59:59'),
  (2, NULL,        '5천원 할인',        'AMOUNT', 5000, NULL, 50000, '2026-01-01', '2026-12-31 23:59:59');

INSERT INTO member_coupon (id, member_id, coupon_id, expires_at) VALUES
  (1, 1, 1, '2026-12-31 23:59:59'),
  (2, 1, 2, '2026-12-31 23:59:59');

-- 적립금: 이벤트 적립 3,000
INSERT INTO point_history (member_id, amount, type, balance_after, expires_at, description) VALUES
  (1, 3000, 'EARN_EVENT', 3000, '2027-11-17', '가입 축하 적립금');
UPDATE member SET point_balance = 3000 WHERE id = 1;

-- 외부 가격 출처 및 수집 가격 (이어폰 X1)
INSERT INTO price_source (id, name, base_url) VALUES
  (1, '쿠팡', 'https://www.coupang.com'),
  (2, '네이버쇼핑', 'https://shopping.naver.com'),
  (3, '11번가', 'https://www.11st.co.kr');

INSERT INTO external_price (product_id, source_id, external_url, price, shipping_fee, collected_at) VALUES
  (2, 1, 'https://www.coupang.com/vp/products/0000', 101000, 0,    '2026-11-17 09:00:00'),
  (2, 2, 'https://shopping.naver.com/0000',          97500,  3000, '2026-11-17 09:00:00'),
  (2, 3, 'https://www.11st.co.kr/products/0000',     99900,  0,    '2026-11-17 09:00:00');

INSERT INTO external_price_history (product_id, source_id, price, shipping_fee, collected_at) VALUES
  (2, 1, 105000, 0,    '2026-11-16 09:00:00'),
  (2, 2, 98000,  3000, '2026-11-16 09:00:00'),
  (2, 3, 99900,  0,    '2026-11-16 09:00:00'),
  (2, 1, 101000, 0,    '2026-11-17 09:00:00'),
  (2, 2, 97500,  3000, '2026-11-17 09:00:00'),
  (2, 3, 99900,  0,    '2026-11-17 09:00:00');
