-- 주요 업무 흐름 예시 쿼리 (seed.sql 실행 후)
USE shoppingmall;

-- =====================================================================
-- 1) 장바구니 → 주문 생성 + 결제 완료 (하나의 트랜잭션)
--    회원1: 티셔츠 블랙L x2 (15,900) + 이어폰 블랙 x1 (99,000) = 130,800
--    쿠폰 WELCOME10 10% (최대 10,000) → 10,000 / 적립금 3,000 사용
--    결제금액 = 130,800 + 0 - 10,000 - 3,000 = 117,800
-- =====================================================================
START TRANSACTION;

-- 재고 차감: 영향받은 행이 0이면 재고 부족 → 애플리케이션에서 ROLLBACK
UPDATE product_variant SET stock_qty = stock_qty - 2 WHERE id = 2 AND stock_qty >= 2;
UPDATE product_variant SET stock_qty = stock_qty - 1 WHERE id = 5 AND stock_qty >= 1;

INSERT INTO orders (order_no, member_id, status, items_amount, shipping_fee, coupon_discount, point_used, pay_amount,
                    recipient, recipient_phone, zipcode, address1, address2)
SELECT '20261117-000001', 1, 'PAID', 130800, 0, 10000, 3000, 117800,
       recipient, phone, zipcode, address1, address2
FROM member_address WHERE member_id = 1 AND is_default;
SET @order_id = LAST_INSERT_ID();

-- 주문상품: 현재 가격/이름을 스냅샷으로 복사
INSERT INTO order_item (order_id, product_id, variant_id, product_name, option_text, unit_price, quantity, line_amount)
SELECT @order_id, p.id, v.id, p.name,
       (SELECT GROUP_CONCAT(ov.value ORDER BY og.sort_order SEPARATOR ' / ')
          FROM variant_option_value vov
          JOIN option_value ov ON ov.id = vov.option_value_id
          JOIN option_group og ON og.id = ov.option_group_id
         WHERE vov.variant_id = v.id),
       p.sale_price + v.extra_price, c.quantity, (p.sale_price + v.extra_price) * c.quantity
FROM cart_item c
JOIN product_variant v ON v.id = c.variant_id
JOIN product p ON p.id = v.product_id
WHERE c.member_id = 1;

-- 쿠폰 사용 (UNUSED 조건으로 중복 사용 방지)
UPDATE member_coupon SET status = 'USED', used_order_id = @order_id, used_at = NOW()
WHERE id = 1 AND member_id = 1 AND status = 'UNUSED';

-- 적립금 사용: 원장 기록 + 잔액 캐시 갱신 (잔액 부족 시 0행)
UPDATE member SET point_balance = point_balance - 3000 WHERE id = 1 AND point_balance >= 3000;
INSERT INTO point_history (member_id, amount, type, order_id, balance_after, description)
SELECT 1, -3000, 'USE', @order_id, point_balance, '주문 사용' FROM member WHERE id = 1;

INSERT INTO payment (order_id, method, pg_provider, pg_tid, amount, status, paid_at)
VALUES (@order_id, 'CARD', 'toss', 'tid_sample_0001', 117800, 'PAID', NOW());

DELETE FROM cart_item WHERE member_id = 1;

COMMIT;

-- =====================================================================
-- 2) 품목별 최저가 비교
-- =====================================================================
SELECT * FROM v_product_price_compare;

-- 상품 하나의 출처별 가격 (상세 페이지용)
SELECT s.name, e.price, e.shipping_fee, e.total_price, e.collected_at
FROM external_price e JOIN price_source s ON s.id = e.source_id
WHERE e.product_id = 2 ORDER BY e.total_price;

-- 수집 배치 UPSERT 예시
INSERT INTO external_price (product_id, source_id, external_url, price, shipping_fee, collected_at)
VALUES (2, 1, 'https://www.coupang.com/vp/products/0000', 98900, 0, NOW())
ON DUPLICATE KEY UPDATE price = VALUES(price), shipping_fee = VALUES(shipping_fee),
                        external_url = VALUES(external_url), collected_at = VALUES(collected_at);

-- =====================================================================
-- 3) 정합성 점검: 포인트 캐시 = 원장 합계 (결과가 비어 있어야 정상)
-- =====================================================================
SELECT m.id, m.point_balance, COALESCE(SUM(ph.amount), 0) AS ledger_sum
FROM member m LEFT JOIN point_history ph ON ph.member_id = m.id
GROUP BY m.id, m.point_balance
HAVING m.point_balance <> ledger_sum;

-- 상품 목록 + 평균 별점 + 옵션별 재고 합계
SELECT p.id, p.name, p.sale_price,
       (SELECT ROUND(AVG(r.rating), 1) FROM review r WHERE r.product_id = p.id AND r.deleted_at IS NULL) AS avg_rating,
       (SELECT SUM(v.stock_qty) FROM product_variant v WHERE v.product_id = p.id) AS total_stock
FROM product p WHERE p.status = 'ON_SALE' AND p.deleted_at IS NULL;
