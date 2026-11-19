-- =====================================================================
-- 쇼핑몰 DB 스키마 (MySQL 8.0.16+, InnoDB, utf8mb4)
-- 금액은 모두 원 단위 정수(INT/BIGINT). 상태값은 VARCHAR 코드.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS shoppingmall
  DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE shoppingmall;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS external_price_history, external_price, price_source,
  review_image, review, refund, claim_item, claim, shipment, point_history,
  member_coupon, payment, order_item, orders, coupon, wishlist, cart_item,
  variant_option_value, product_variant, option_value, option_group,
  product_image, product, category, member_address, member;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- 1. 회원
-- ---------------------------------------------------------------------
CREATE TABLE member (
  id             BIGINT       NOT NULL AUTO_INCREMENT,
  email          VARCHAR(255) NOT NULL,
  password_hash  VARCHAR(255) NOT NULL,
  name           VARCHAR(50)  NOT NULL,
  phone          VARCHAR(20),
  grade          VARCHAR(20)  NOT NULL DEFAULT 'BASIC',   -- BASIC/SILVER/GOLD/VIP
  status         VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE',  -- ACTIVE/DORMANT/WITHDRAWN
  point_balance  INT          NOT NULL DEFAULT 0,         -- 캐시값. 원장은 point_history
  created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at     DATETIME,
  PRIMARY KEY (id),
  UNIQUE KEY uk_member_email (email),
  CONSTRAINT ck_member_point CHECK (point_balance >= 0)
) ENGINE=InnoDB;

CREATE TABLE member_address (
  id          BIGINT       NOT NULL AUTO_INCREMENT,
  member_id   BIGINT       NOT NULL,
  alias       VARCHAR(30),                 -- 집, 회사
  recipient   VARCHAR(50)  NOT NULL,
  phone       VARCHAR(20)  NOT NULL,
  zipcode     VARCHAR(10)  NOT NULL,
  address1    VARCHAR(255) NOT NULL,
  address2    VARCHAR(255),
  is_default  BOOLEAN      NOT NULL DEFAULT FALSE,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_address_member (member_id),
  CONSTRAINT fk_address_member FOREIGN KEY (member_id) REFERENCES member (id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 2. 상품 / 옵션
-- ---------------------------------------------------------------------
CREATE TABLE category (
  id          BIGINT      NOT NULL AUTO_INCREMENT,
  parent_id   BIGINT,
  name        VARCHAR(50) NOT NULL,
  depth       TINYINT     NOT NULL DEFAULT 1,
  sort_order  INT         NOT NULL DEFAULT 0,
  created_at  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_category_parent (parent_id),
  CONSTRAINT fk_category_parent FOREIGN KEY (parent_id) REFERENCES category (id)
) ENGINE=InnoDB;

CREATE TABLE product (
  id           BIGINT       NOT NULL AUTO_INCREMENT,
  category_id  BIGINT       NOT NULL,
  name         VARCHAR(200) NOT NULL,
  brand        VARCHAR(100),
  model_code   VARCHAR(100),                -- 외부 가격비교 매칭 키 (모델명/바코드)
  description  TEXT,
  base_price   INT          NOT NULL,       -- 정상가
  sale_price   INT          NOT NULL,       -- 판매가 (할인 적용)
  status       VARCHAR(20)  NOT NULL DEFAULT 'ON_SALE',  -- ON_SALE/SOLD_OUT/HIDDEN
  created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at   DATETIME,
  PRIMARY KEY (id),
  KEY idx_product_category_status (category_id, status),
  KEY idx_product_model_code (model_code),
  CONSTRAINT fk_product_category FOREIGN KEY (category_id) REFERENCES category (id),
  CONSTRAINT ck_product_price CHECK (base_price >= 0 AND sale_price >= 0)
) ENGINE=InnoDB;

CREATE TABLE product_image (
  id          BIGINT       NOT NULL AUTO_INCREMENT,
  product_id  BIGINT       NOT NULL,
  url         VARCHAR(500) NOT NULL,
  is_main     BOOLEAN      NOT NULL DEFAULT FALSE,
  sort_order  INT          NOT NULL DEFAULT 0,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_image_product (product_id),
  CONSTRAINT fk_image_product FOREIGN KEY (product_id) REFERENCES product (id)
) ENGINE=InnoDB;

CREATE TABLE option_group (
  id          BIGINT      NOT NULL AUTO_INCREMENT,
  product_id  BIGINT      NOT NULL,
  name        VARCHAR(50) NOT NULL,         -- 색상, 사이즈
  sort_order  INT         NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_option_group_product (product_id),
  CONSTRAINT fk_option_group_product FOREIGN KEY (product_id) REFERENCES product (id)
) ENGINE=InnoDB;

CREATE TABLE option_value (
  id               BIGINT      NOT NULL AUTO_INCREMENT,
  option_group_id  BIGINT      NOT NULL,
  value            VARCHAR(50) NOT NULL,    -- 블랙, L
  sort_order       INT         NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_option_value (option_group_id, value),
  CONSTRAINT fk_option_value_group FOREIGN KEY (option_group_id) REFERENCES option_group (id)
) ENGINE=InnoDB;

-- 실제 판매/재고 단위 (SKU). 최종가 = product.sale_price + extra_price
CREATE TABLE product_variant (
  id           BIGINT      NOT NULL AUTO_INCREMENT,
  product_id   BIGINT      NOT NULL,
  sku_code     VARCHAR(50) NOT NULL,
  extra_price  INT         NOT NULL DEFAULT 0,
  stock_qty    INT         NOT NULL DEFAULT 0,
  status       VARCHAR(20) NOT NULL DEFAULT 'ON_SALE',  -- ON_SALE/SOLD_OUT/HIDDEN
  created_at   DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_variant_sku (sku_code),
  KEY idx_variant_product (product_id),
  CONSTRAINT fk_variant_product FOREIGN KEY (product_id) REFERENCES product (id),
  CONSTRAINT ck_variant_stock CHECK (stock_qty >= 0)
) ENGINE=InnoDB;

-- SKU가 어떤 옵션값 조합인지 (예: SKU#1 = 블랙 + L)
CREATE TABLE variant_option_value (
  variant_id       BIGINT NOT NULL,
  option_value_id  BIGINT NOT NULL,
  PRIMARY KEY (variant_id, option_value_id),
  CONSTRAINT fk_vov_variant FOREIGN KEY (variant_id) REFERENCES product_variant (id),
  CONSTRAINT fk_vov_value   FOREIGN KEY (option_value_id) REFERENCES option_value (id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 3. 장바구니 / 찜
-- ---------------------------------------------------------------------
CREATE TABLE cart_item (
  id          BIGINT   NOT NULL AUTO_INCREMENT,
  member_id   BIGINT   NOT NULL,
  variant_id  BIGINT   NOT NULL,
  quantity    INT      NOT NULL DEFAULT 1,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_cart_member_variant (member_id, variant_id),
  CONSTRAINT fk_cart_member  FOREIGN KEY (member_id)  REFERENCES member (id),
  CONSTRAINT fk_cart_variant FOREIGN KEY (variant_id) REFERENCES product_variant (id),
  CONSTRAINT ck_cart_qty CHECK (quantity > 0)
) ENGINE=InnoDB;

CREATE TABLE wishlist (
  member_id   BIGINT   NOT NULL,
  product_id  BIGINT   NOT NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (member_id, product_id),
  KEY idx_wishlist_product (product_id),
  CONSTRAINT fk_wishlist_member  FOREIGN KEY (member_id)  REFERENCES member (id),
  CONSTRAINT fk_wishlist_product FOREIGN KEY (product_id) REFERENCES product (id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4. 쿠폰 (주문보다 먼저 생성)
-- ---------------------------------------------------------------------
CREATE TABLE coupon (
  id                BIGINT       NOT NULL AUTO_INCREMENT,
  code              VARCHAR(50),                 -- 코드 입력형 쿠폰일 때
  name              VARCHAR(100) NOT NULL,
  discount_type     VARCHAR(10)  NOT NULL,       -- AMOUNT(정액)/RATE(정률)
  discount_value    INT          NOT NULL,       -- 원 또는 %
  max_discount      INT,                         -- 정률 최대 할인액
  min_order_amount  INT          NOT NULL DEFAULT 0,
  target_type       VARCHAR(20)  NOT NULL DEFAULT 'ALL',  -- ALL/CATEGORY/PRODUCT
  target_id         BIGINT,                      -- category.id 또는 product.id
  valid_from        DATETIME     NOT NULL,
  valid_to          DATETIME     NOT NULL,
  issue_limit       INT,                         -- 총 발급 한도 (NULL=무제한)
  issued_count      INT          NOT NULL DEFAULT 0,
  created_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_coupon_code (code),
  CONSTRAINT ck_coupon_rate CHECK (discount_type <> 'RATE' OR discount_value BETWEEN 1 AND 100)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 5. 주문 / 결제
-- ---------------------------------------------------------------------
CREATE TABLE orders (
  id                  BIGINT       NOT NULL AUTO_INCREMENT,
  order_no            VARCHAR(30)  NOT NULL,     -- 외부 노출용 주문번호 (예: 20261117-000001)
  member_id           BIGINT       NOT NULL,
  status              VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    -- PENDING/PAID/PREPARING/SHIPPED/DELIVERED/CONFIRMED/CANCELLED
  items_amount        INT          NOT NULL,     -- 상품 합계
  shipping_fee        INT          NOT NULL DEFAULT 0,
  coupon_discount     INT          NOT NULL DEFAULT 0,
  point_used          INT          NOT NULL DEFAULT 0,
  pay_amount          INT          NOT NULL,     -- 최종 결제금액
  -- 배송지 스냅샷
  recipient           VARCHAR(50)  NOT NULL,
  recipient_phone     VARCHAR(20)  NOT NULL,
  zipcode             VARCHAR(10)  NOT NULL,
  address1            VARCHAR(255) NOT NULL,
  address2            VARCHAR(255),
  delivery_memo       VARCHAR(255),
  ordered_at          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  confirmed_at        DATETIME,                  -- 구매확정 (적립금 지급 시점)
  created_at          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_orders_no (order_no),
  KEY idx_orders_member_created (member_id, created_at),
  KEY idx_orders_status (status),
  CONSTRAINT fk_orders_member FOREIGN KEY (member_id) REFERENCES member (id),
  CONSTRAINT ck_orders_amount CHECK (
    pay_amount = items_amount + shipping_fee - coupon_discount - point_used
    AND pay_amount >= 0)
) ENGINE=InnoDB;

CREATE TABLE order_item (
  id            BIGINT       NOT NULL AUTO_INCREMENT,
  order_id      BIGINT       NOT NULL,
  product_id    BIGINT       NOT NULL,
  variant_id    BIGINT       NOT NULL,
  product_name  VARCHAR(200) NOT NULL,   -- 스냅샷
  option_text   VARCHAR(200),            -- 스냅샷 (예: "블랙 / L")
  unit_price    INT          NOT NULL,   -- 스냅샷 (sale_price + extra_price)
  quantity      INT          NOT NULL,
  line_amount   INT          NOT NULL,   -- unit_price * quantity
  status        VARCHAR(20)  NOT NULL DEFAULT 'ORDERED',
    -- ORDERED/CANCELLED/EXCHANGE_REQUESTED/EXCHANGED/RETURN_REQUESTED/RETURNED
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_order_item_order (order_id),
  KEY idx_order_item_variant (variant_id),
  CONSTRAINT fk_order_item_order   FOREIGN KEY (order_id)   REFERENCES orders (id),
  CONSTRAINT fk_order_item_product FOREIGN KEY (product_id) REFERENCES product (id),
  CONSTRAINT fk_order_item_variant FOREIGN KEY (variant_id) REFERENCES product_variant (id),
  CONSTRAINT ck_order_item CHECK (quantity > 0 AND line_amount = unit_price * quantity)
) ENGINE=InnoDB;

CREATE TABLE payment (
  id           BIGINT       NOT NULL AUTO_INCREMENT,
  order_id     BIGINT       NOT NULL,
  method       VARCHAR(20)  NOT NULL,   -- CARD/BANK_TRANSFER/VIRTUAL_ACCOUNT/KAKAOPAY/NAVERPAY/TOSSPAY
  pg_provider  VARCHAR(30),             -- toss, inicis, kcp ...
  pg_tid       VARCHAR(100),            -- PG 거래 ID
  amount       INT          NOT NULL,
  status       VARCHAR(20)  NOT NULL DEFAULT 'READY',  -- READY/PAID/FAILED/CANCELLED/PARTIAL_CANCELLED
  paid_at      DATETIME,
  raw_response JSON,                    -- PG 응답 원문 (분쟁 대비)
  created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_payment_pg_tid (pg_provider, pg_tid),
  KEY idx_payment_order (order_id),
  CONSTRAINT fk_payment_order FOREIGN KEY (order_id) REFERENCES orders (id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 6. 회원 쿠폰 / 적립금
-- ---------------------------------------------------------------------
CREATE TABLE member_coupon (
  id             BIGINT      NOT NULL AUTO_INCREMENT,
  member_id      BIGINT      NOT NULL,
  coupon_id      BIGINT      NOT NULL,
  status         VARCHAR(20) NOT NULL DEFAULT 'UNUSED',  -- UNUSED/USED/EXPIRED
  used_order_id  BIGINT,
  used_at        DATETIME,
  expires_at     DATETIME    NOT NULL,
  created_at     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_member_coupon_member_status (member_id, status),
  CONSTRAINT fk_mc_member FOREIGN KEY (member_id)     REFERENCES member (id),
  CONSTRAINT fk_mc_coupon FOREIGN KEY (coupon_id)     REFERENCES coupon (id),
  CONSTRAINT fk_mc_order  FOREIGN KEY (used_order_id) REFERENCES orders (id)
) ENGINE=InnoDB;

-- 적립금 원장. member.point_balance = SUM(amount)
CREATE TABLE point_history (
  id             BIGINT       NOT NULL AUTO_INCREMENT,
  member_id      BIGINT       NOT NULL,
  amount         INT          NOT NULL,   -- +적립 / -사용·소멸
  type           VARCHAR(20)  NOT NULL,   -- EARN_ORDER/EARN_REVIEW/EARN_EVENT/USE/USE_CANCEL/EXPIRE/EARN_CANCEL
  order_id       BIGINT,
  review_id      BIGINT,
  balance_after  INT          NOT NULL,
  expires_at     DATETIME,                -- 적립 건만
  description    VARCHAR(200),
  created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_point_member_created (member_id, created_at),
  CONSTRAINT fk_point_member FOREIGN KEY (member_id) REFERENCES member (id),
  CONSTRAINT fk_point_order  FOREIGN KEY (order_id)  REFERENCES orders (id),
  CONSTRAINT ck_point_amount CHECK (amount <> 0 AND balance_after >= 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 7. 배송 / 교환·반품
-- ---------------------------------------------------------------------
CREATE TABLE shipment (
  id            BIGINT      NOT NULL AUTO_INCREMENT,
  order_id      BIGINT      NOT NULL,
  claim_id      BIGINT,                   -- 교환 재발송이면 해당 클레임
  courier       VARCHAR(30) NOT NULL,     -- CJ, HANJIN, LOTTE, POST ...
  tracking_no   VARCHAR(50),
  status        VARCHAR(20) NOT NULL DEFAULT 'READY',  -- READY/SHIPPED/IN_TRANSIT/DELIVERED
  shipped_at    DATETIME,
  delivered_at  DATETIME,
  created_at    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_shipment_order (order_id),
  KEY idx_shipment_tracking (courier, tracking_no),
  CONSTRAINT fk_shipment_order FOREIGN KEY (order_id) REFERENCES orders (id)
) ENGINE=InnoDB;

CREATE TABLE claim (
  id                   BIGINT       NOT NULL AUTO_INCREMENT,
  order_id             BIGINT       NOT NULL,
  member_id            BIGINT       NOT NULL,
  type                 VARCHAR(20)  NOT NULL,   -- CANCEL/EXCHANGE/RETURN
  reason_code          VARCHAR(30)  NOT NULL,   -- CHANGE_OF_MIND/DEFECT/WRONG_DELIVERY/SIZE ...
  reason_detail        VARCHAR(500),
  status               VARCHAR(20)  NOT NULL DEFAULT 'REQUESTED',
    -- REQUESTED/APPROVED/COLLECTING/COLLECTED/COMPLETED/REJECTED
  fee_payer            VARCHAR(10)  NOT NULL DEFAULT 'BUYER',  -- BUYER/SELLER
  return_shipping_fee  INT          NOT NULL DEFAULT 0,
  pickup_courier       VARCHAR(30),
  pickup_tracking_no   VARCHAR(50),
  requested_at         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_at         DATETIME,
  created_at           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_claim_order (order_id),
  KEY idx_claim_status (status),
  CONSTRAINT fk_claim_order  FOREIGN KEY (order_id)  REFERENCES orders (id),
  CONSTRAINT fk_claim_member FOREIGN KEY (member_id) REFERENCES member (id)
) ENGINE=InnoDB;

ALTER TABLE shipment
  ADD CONSTRAINT fk_shipment_claim FOREIGN KEY (claim_id) REFERENCES claim (id);

CREATE TABLE claim_item (
  id                   BIGINT NOT NULL AUTO_INCREMENT,
  claim_id             BIGINT NOT NULL,
  order_item_id        BIGINT NOT NULL,
  quantity             INT    NOT NULL,
  exchange_variant_id  BIGINT,             -- 교환 시 새로 받을 SKU
  PRIMARY KEY (id),
  KEY idx_claim_item_claim (claim_id),
  KEY idx_claim_item_order_item (order_item_id),
  CONSTRAINT fk_ci_claim      FOREIGN KEY (claim_id)            REFERENCES claim (id),
  CONSTRAINT fk_ci_order_item FOREIGN KEY (order_item_id)       REFERENCES order_item (id),
  CONSTRAINT fk_ci_variant    FOREIGN KEY (exchange_variant_id) REFERENCES product_variant (id),
  CONSTRAINT ck_ci_qty CHECK (quantity > 0)
) ENGINE=InnoDB;

CREATE TABLE refund (
  id               BIGINT      NOT NULL AUTO_INCREMENT,
  payment_id       BIGINT      NOT NULL,
  claim_id         BIGINT,
  amount           INT         NOT NULL,   -- PG 환불액
  point_refunded   INT         NOT NULL DEFAULT 0,  -- 적립금 복구액
  status           VARCHAR(20) NOT NULL DEFAULT 'REQUESTED',  -- REQUESTED/COMPLETED/FAILED
  pg_cancel_tid    VARCHAR(100),
  refunded_at      DATETIME,
  created_at       DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_refund_payment (payment_id),
  CONSTRAINT fk_refund_payment FOREIGN KEY (payment_id) REFERENCES payment (id),
  CONSTRAINT fk_refund_claim   FOREIGN KEY (claim_id)   REFERENCES claim (id),
  CONSTRAINT ck_refund_amount CHECK (amount >= 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 8. 리뷰
-- ---------------------------------------------------------------------
CREATE TABLE review (
  id             BIGINT      NOT NULL AUTO_INCREMENT,
  member_id      BIGINT      NOT NULL,
  product_id     BIGINT      NOT NULL,
  order_item_id  BIGINT      NOT NULL,   -- 구매한 사람만, 주문상품당 1개
  rating         TINYINT     NOT NULL,
  content        TEXT        NOT NULL,
  status         VARCHAR(20) NOT NULL DEFAULT 'VISIBLE',  -- VISIBLE/HIDDEN/BLINDED
  created_at     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at     DATETIME,
  PRIMARY KEY (id),
  UNIQUE KEY uk_review_order_item (order_item_id),
  KEY idx_review_product_created (product_id, created_at),
  CONSTRAINT fk_review_member     FOREIGN KEY (member_id)     REFERENCES member (id),
  CONSTRAINT fk_review_product    FOREIGN KEY (product_id)    REFERENCES product (id),
  CONSTRAINT fk_review_order_item FOREIGN KEY (order_item_id) REFERENCES order_item (id),
  CONSTRAINT ck_review_rating CHECK (rating BETWEEN 1 AND 5)
) ENGINE=InnoDB;

ALTER TABLE point_history
  ADD CONSTRAINT fk_point_review FOREIGN KEY (review_id) REFERENCES review (id);

CREATE TABLE review_image (
  id          BIGINT       NOT NULL AUTO_INCREMENT,
  review_id   BIGINT       NOT NULL,
  url         VARCHAR(500) NOT NULL,
  sort_order  INT          NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_review_image_review (review_id),
  CONSTRAINT fk_review_image_review FOREIGN KEY (review_id) REFERENCES review (id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 9. 최저가 비교 (외부 쇼핑몰 가격 수집)
-- ---------------------------------------------------------------------
CREATE TABLE price_source (
  id          BIGINT       NOT NULL AUTO_INCREMENT,
  name        VARCHAR(50)  NOT NULL,     -- 쿠팡, 네이버쇼핑, 11번가 ...
  base_url    VARCHAR(255),
  is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_price_source_name (name)
) ENGINE=InnoDB;

-- 출처별 최신 가격 1건 (배치가 UPSERT)
CREATE TABLE external_price (
  id            BIGINT       NOT NULL AUTO_INCREMENT,
  product_id    BIGINT       NOT NULL,
  source_id     BIGINT       NOT NULL,
  external_url  VARCHAR(500),
  price         INT          NOT NULL,
  shipping_fee  INT          NOT NULL DEFAULT 0,
  total_price   INT AS (price + shipping_fee) STORED,  -- 배송비 포함 실구매가
  in_stock      BOOLEAN      NOT NULL DEFAULT TRUE,
  collected_at  DATETIME     NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_external_price (product_id, source_id),
  KEY idx_external_price_total (product_id, total_price),
  CONSTRAINT fk_ep_product FOREIGN KEY (product_id) REFERENCES product (id),
  CONSTRAINT fk_ep_source  FOREIGN KEY (source_id)  REFERENCES price_source (id)
) ENGINE=InnoDB;

-- 가격 추이 (그래프/알림용)
CREATE TABLE external_price_history (
  id            BIGINT   NOT NULL AUTO_INCREMENT,
  product_id    BIGINT   NOT NULL,
  source_id     BIGINT   NOT NULL,
  price         INT      NOT NULL,
  shipping_fee  INT      NOT NULL DEFAULT 0,
  collected_at  DATETIME NOT NULL,
  PRIMARY KEY (id),
  KEY idx_eph_product_collected (product_id, collected_at),
  CONSTRAINT fk_eph_product FOREIGN KEY (product_id) REFERENCES product (id),
  CONSTRAINT fk_eph_source  FOREIGN KEY (source_id)  REFERENCES price_source (id)
) ENGINE=InnoDB;

-- 품목별 최저가 비교 뷰: 우리 판매가 vs 외부 최저가
CREATE OR REPLACE VIEW v_product_price_compare AS
SELECT
  p.id                                   AS product_id,
  p.name                                 AS product_name,
  p.sale_price                           AS our_price,
  lp.min_total_price                     AS market_min_price,
  (SELECT s.name FROM external_price e JOIN price_source s ON s.id = e.source_id
    WHERE e.product_id = p.id AND e.in_stock AND s.is_active
    ORDER BY e.total_price, e.collected_at DESC LIMIT 1) AS market_min_source,
  p.sale_price - lp.min_total_price      AS diff,       -- 음수면 우리가 더 쌈
  (p.sale_price <= lp.min_total_price)   AS is_lowest
FROM product p
JOIN (
  SELECT e.product_id, MIN(e.total_price) AS min_total_price
  FROM external_price e JOIN price_source s ON s.id = e.source_id
  WHERE e.in_stock AND s.is_active
  GROUP BY e.product_id
) lp ON lp.product_id = p.id
WHERE p.deleted_at IS NULL;
