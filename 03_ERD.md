# 03. 의류 쇼핑몰 ERD 설계도

- 기준 문서: `01_요구사항.md`
- 대상 DB: Oracle 21c XE
- 표 개수: **27개** (5개 묶음)
- 이 파일은 ERDCloud에 옮겨 그릴 때 보는 **설계도**이다. 그림(Mermaid)과 표 정리가 함께 들어 있다.

## 읽는 법

| 기호 | 뜻 |
|---|---|
| **PK** | 기본키. 한 줄을 딱 하나로 구별하는 번호 |
| **FK** | 외래키. 다른 표의 PK를 적어 둔 칸(주소) |
| **UK** | 중복 금지(UNIQUE) |
| NULL 허용 = **선택** | 비어 있어도 되는 칸 |

Mermaid 관계선 기호

| 기호 | 뜻 |
|---|---|
| `\|\|--o{` | 1 : 0개 이상 (1:N) |
| `\|\|--\|{` | 1 : 1개 이상 |
| `\|o--o{` | 0 또는 1 : 0개 이상 (부모가 없을 수도 있음, FK 선택) |
| `\|\|--o\|` | 1 : 0 또는 1 (1:1) |

## 정한 것

- 상품 하나는 카테고리 **하나에만** 넣는다. (요구사항 4번, 상품 표에 category_no 칸 하나)
- 계산할 수 있는 값(나이, 할인율, 적립금 잔액, 주문 총 무게, 마지막 주문일)은 저장하지 않는다.
- 그 당시의 사실(주문 당시 가격, 실제로 낸 배송비, 약속한 배송 기간)은 저장한다.
- Y/N 값은 `CHAR(1)` + `CHECK (x IN ('Y','N'))`로 저장한다.

## 묶음 한눈에 보기

| 묶음 | 표 (논리 이름 / 물리 이름) | ERDCloud 색 (예시) |
|---|---|---|
| ① 회원 | 회원 MEMBER, 회원변경이력 MEMBER_HISTORY, 보호자동의 PARENT_CONSENT, 비회원주문정보 GUEST_ORDER | 파랑 |
| ② 상품 | 카테고리 CATEGORY, 브랜드 BRAND, 상품 PRODUCT, 상품사이즈 PRODUCT_SIZE, 사이즈치수 SIZE_MEASURE, 장바구니 CART, 비교함 COMPARE_BOX | 초록 |
| ③ 주문·배송 | 주문 ORDERS, 주문상세 ORDER_DETAIL, 배송 SHIPMENT, 배송권역 SHIPPING_ZONE, 배송지역 SHIPPING_AREA, 배송비변경이력 SHIP_FEE_HISTORY, 배송지연안내 SHIP_DELAY, 단체중량배송비 GROUP_WEIGHT_FEE | 주황 |
| ④ 취소·반품 | 반품교환신청 RETURN_REQUEST, 환불 REFUND, 재고부족대기 STOCK_WAIT, 알림발송기록 NOTIFICATION | 빨강 |
| ⑤ 혜택·리뷰 | 쿠폰 COUPON, 회원쿠폰 MEMBER_COUPON, 적립금내역 POINT_HISTORY, 리뷰 REVIEW | 보라 |

---

## 0. 전체 관계도 (표 이름만)

칸은 빼고 표와 관계선만 그린 큰 그림이다. 중심은 **주문(ORDERS)**과 **주문상세(ORDER_DETAIL)**이다.

```mermaid
erDiagram
    MEMBER ||--o{ MEMBER_HISTORY : "정보 변경"
    MEMBER ||--o{ PARENT_CONSENT : "보호자 동의"
    ORDERS |o--o{ PARENT_CONSENT : "결제 동의"
    MEMBER |o--o{ ORDERS : "주문"
    ORDERS ||--o| GUEST_ORDER : "비회원 정보"

    CATEGORY |o--o{ CATEGORY : "하위 분류"
    CATEGORY ||--o{ PRODUCT : "분류"
    BRAND ||--o{ PRODUCT : "판매"
    PRODUCT ||--|{ PRODUCT_SIZE : "사이즈"
    PRODUCT_SIZE ||--o{ SIZE_MEASURE : "실측 치수"
    MEMBER ||--o{ CART : "담기"
    PRODUCT_SIZE ||--o{ CART : "담긴 사이즈"
    MEMBER ||--o{ COMPARE_BOX : "비교"
    PRODUCT ||--o{ COMPARE_BOX : "비교 대상"

    ORDERS ||--|{ ORDER_DETAIL : "주문 상품"
    PRODUCT_SIZE ||--o{ ORDER_DETAIL : "주문된 사이즈"
    ORDERS ||--o{ SHIPMENT : "배송"
    SHIPMENT |o--o{ ORDER_DETAIL : "같은 택배"
    SHIPPING_ZONE ||--o{ SHIPPING_AREA : "포함 지역"
    SHIPPING_ZONE ||--o{ ORDERS : "배송 권역"
    SHIPPING_ZONE |o--o{ SHIP_FEE_HISTORY : "기본 배송비 변경"
    SHIPPING_AREA |o--o{ SHIP_FEE_HISTORY : "추가 배송비 변경"
    SHIPMENT ||--o{ SHIP_DELAY : "지연 안내"

    ORDER_DETAIL ||--o{ RETURN_REQUEST : "반품 교환 신청"
    PRODUCT_SIZE |o--o{ RETURN_REQUEST : "교환할 사이즈"
    ORDERS ||--o{ REFUND : "환불"
    RETURN_REQUEST |o--o{ REFUND : "반품 환불"
    ORDER_DETAIL ||--o{ STOCK_WAIT : "재고 부족"
    ORDERS |o--o{ NOTIFICATION : "문자 알림"

    COUPON ||--o{ MEMBER_COUPON : "발급"
    MEMBER ||--o{ MEMBER_COUPON : "보유"
    ORDERS |o--o| MEMBER_COUPON : "사용"
    MEMBER ||--o{ POINT_HISTORY : "적립금"
    ORDERS |o--o{ POINT_HISTORY : "주문 적립 사용"
    ORDER_DETAIL ||--o| REVIEW : "리뷰"
    MEMBER ||--o{ REVIEW : "작성"

    GROUP_WEIGHT_FEE {
        NUMBER fee_no PK "규칙 표 - 다른 표와 연결 없음"
    }
```

---

## ① 회원 묶음

```mermaid
erDiagram
    MEMBER ||--o{ MEMBER_HISTORY : "정보 변경"
    MEMBER ||--o{ PARENT_CONSENT : "보호자 동의"
    ORDERS |o--o{ PARENT_CONSENT : "결제 동의"
    MEMBER |o--o{ ORDERS : "주문"
    ORDERS ||--o| GUEST_ORDER : "비회원 정보"

    MEMBER {
        NUMBER member_no PK "회원번호"
        VARCHAR2 login_id UK "아이디"
        VARCHAR2 login_pw "비밀번호(암호화)"
        VARCHAR2 member_name "이름"
        DATE birth_date "생년월일"
        VARCHAR2 phone "전화번호"
        CHAR zipcode "우편번호"
        VARCHAR2 address "주소"
        CHAR member_type "P개인 U부대"
        VARCHAR2 manager_name "부대 담당자 이름(선택)"
        VARCHAR2 manager_phone "부대 담당자 연락처(선택)"
        VARCHAR2 status "정상 탈퇴"
        DATE join_date "가입일"
        DATE withdraw_date "탈퇴일(선택)"
    }
    MEMBER_HISTORY {
        NUMBER history_no PK "변경이력번호"
        NUMBER member_no FK "회원번호"
        VARCHAR2 item_name "변경 항목"
        VARCHAR2 old_value "이전 값"
        VARCHAR2 new_value "새 값"
        DATE changed_at "변경일"
    }
    PARENT_CONSENT {
        NUMBER consent_no PK "동의번호"
        NUMBER member_no FK "회원번호"
        NUMBER order_no FK "주문번호(결제 동의일 때만)"
        VARCHAR2 parent_name "보호자 이름"
        VARCHAR2 parent_phone "보호자 연락처"
        CHAR consent_type "J가입 P결제"
        DATE consent_date "동의일"
    }
    GUEST_ORDER {
        NUMBER order_no PK "주문번호(PK이면서 FK)"
        VARCHAR2 guest_name "주문자 이름"
        VARCHAR2 guest_phone "주문자 전화번호"
        VARCHAR2 order_pw "주문 비밀번호(암호화)"
        DATE verified_at "본인인증일"
    }
    ORDERS {
        NUMBER order_no PK "주문번호"
    }
```

| 표 | 핵심 설명 |
|---|---|
| MEMBER | 주민등록번호는 저장하지 않는다(개인정보보호법). 나이는 birth_date로 계산. 적립금 잔액은 적립금내역의 합계로 계산하므로 저장하지 않는다. |
| PARENT_CONSENT | 가입 동의는 order_no가 비어 있고, 결제 동의는 order_no를 채운다. |
| GUEST_ORDER | 주문과 **1:1**. order_no가 PK이면서 동시에 ORDERS를 가리키는 FK이다. |

---

## ② 상품 묶음

```mermaid
erDiagram
    CATEGORY |o--o{ CATEGORY : "하위 분류"
    CATEGORY ||--o{ PRODUCT : "분류"
    BRAND ||--o{ PRODUCT : "판매"
    PRODUCT ||--|{ PRODUCT_SIZE : "사이즈"
    PRODUCT_SIZE ||--o{ SIZE_MEASURE : "실측 치수"
    MEMBER ||--o{ CART : "담기"
    PRODUCT_SIZE ||--o{ CART : "담긴 사이즈"
    MEMBER ||--o{ COMPARE_BOX : "비교"
    PRODUCT ||--o{ COMPARE_BOX : "비교 대상"

    CATEGORY {
        NUMBER category_no PK "카테고리번호"
        NUMBER parent_no FK "상위 카테고리(대분류는 비어 있음)"
        VARCHAR2 category_name "카테고리 이름"
        NUMBER sort_order "화면 표시 순서"
    }
    BRAND {
        NUMBER brand_no PK "브랜드번호"
        VARCHAR2 brand_name UK "브랜드명"
        NUMBER prep_days "출고 준비 기간(일)"
    }
    PRODUCT {
        NUMBER product_no PK "상품번호"
        NUMBER category_no FK "카테고리(가장 아래 단계)"
        NUMBER brand_no FK "브랜드"
        VARCHAR2 product_name "상품명"
        NUMBER list_price "정가"
        NUMBER sale_price "판매가"
        CLOB description "설명"
        VARCHAR2 image_url "이미지 주소"
        CHAR special_yn "특수품 여부 Y N"
        CHAR made_yn "제작품 여부 Y N"
        NUMBER weight_g "무게(그램)"
        DATE reg_date "등록일"
        VARCHAR2 sale_status "판매중 판매중지"
    }
    PRODUCT_SIZE {
        NUMBER size_no PK "사이즈번호"
        NUMBER product_no FK "상품번호"
        VARCHAR2 size_name "사이즈 이름(S M L 230)"
        NUMBER stock_qty "재고 수량"
    }
    SIZE_MEASURE {
        NUMBER measure_no PK "치수번호"
        NUMBER size_no FK "사이즈번호"
        VARCHAR2 measure_part "상의 하의(셋업일 때)"
        VARCHAR2 measure_name "치수 항목(총장 어깨너비)"
        NUMBER measure_value "값(cm 또는 mm)"
    }
    CART {
        NUMBER cart_no PK "장바구니번호"
        NUMBER member_no FK "회원번호"
        NUMBER size_no FK "사이즈번호"
        NUMBER quantity "수량"
        DATE added_at "담은 날"
    }
    COMPARE_BOX {
        NUMBER compare_no PK "비교함번호"
        NUMBER member_no FK "회원번호"
        NUMBER product_no FK "상품번호"
        DATE added_at "담은 날"
    }
    MEMBER {
        NUMBER member_no PK "회원번호"
    }
```

| 표 | 핵심 설명 |
|---|---|
| CATEGORY | **자기 참조**. parent_no가 같은 표의 category_no를 가리킨다. 대분류 > 중분류 > 소분류를 표 하나로 만든다. 단계(depth)는 `CONNECT BY`로 계산하므로 저장하지 않는다. |
| PRODUCT | 할인율은 정가와 판매가로 계산하므로 저장하지 않는다. |
| SIZE_MEASURE | 치수 항목을 칸이 아니라 **줄**로 저장한다. 상의는 4줄, 신발은 2줄처럼 필요한 항목만 저장할 수 있다(요구사항 5-1). |
| CART | 회원 N : 상품사이즈 M을 잇는 **연결 표**. (member_no, size_no)는 중복 금지. 같은 걸 또 담으면 수량만 늘린다. |
| COMPARE_BOX | 회원 N : 상품 M을 잇는 **연결 표**. (member_no, product_no)는 중복 금지. 이름이 COMPARE이면 헷갈리므로 COMPARE_BOX로 지었다. |

---

## ③ 주문·배송 묶음

```mermaid
erDiagram
    MEMBER |o--o{ ORDERS : "주문"
    SHIPPING_ZONE ||--o{ ORDERS : "배송 권역"
    ORDERS ||--|{ ORDER_DETAIL : "주문 상품"
    PRODUCT_SIZE ||--o{ ORDER_DETAIL : "주문된 사이즈"
    ORDERS ||--|{ SHIPMENT : "배송"
    SHIPMENT |o--o{ ORDER_DETAIL : "같은 택배"
    SHIPPING_ZONE ||--o{ SHIPPING_AREA : "포함 지역"
    SHIPPING_ZONE |o--o{ SHIP_FEE_HISTORY : "기본 배송비 변경"
    SHIPPING_AREA |o--o{ SHIP_FEE_HISTORY : "추가 배송비 변경"
    SHIPMENT ||--o{ SHIP_DELAY : "지연 안내"

    ORDERS {
        NUMBER order_no PK "주문번호"
        NUMBER member_no FK "회원번호(비회원이면 비어 있음)"
        CHAR order_type "M회원 G비회원"
        DATE order_date "주문일"
        VARCHAR2 receiver_name "받는 사람"
        VARCHAR2 receiver_phone "받는 사람 연락처"
        CHAR zipcode "배송지 우편번호"
        VARCHAR2 address "배송지 주소"
        NUMBER zone_no FK "배송 권역(그 당시)"
        CHAR ship_option "S분리 T함께(선택)"
        NUMBER discount_amount "쿠폰 할인액"
        NUMBER point_used "사용 적립금"
        NUMBER pay_amount "실제 결제 금액"
        VARCHAR2 status "주문 상태"
    }
    ORDER_DETAIL {
        NUMBER order_detail_no PK "주문상세번호"
        NUMBER order_no FK "주문번호"
        NUMBER size_no FK "사이즈번호"
        NUMBER shipment_no FK "배송번호(출고 전에는 비어 있음)"
        NUMBER quantity "수량"
        NUMBER order_price "주문 당시 가격"
        DATE ship_due_date "판매 업체 확인 출고 예정일(선택)"
        VARCHAR2 status "상품별 상태"
    }
    SHIPMENT {
        NUMBER shipment_no PK "배송번호"
        NUMBER order_no FK "주문번호"
        NUMBER base_ship_fee "실제로 받은 기본 배송비"
        NUMBER extra_ship_fee "실제로 받은 추가 배송비"
        NUMBER promised_days "안내한 최대 배송 기간"
        VARCHAR2 tracking_no "송장번호"
        VARCHAR2 ship_status "배송 상태"
        DATE shipped_date "출고일"
        DATE delivered_date "배송완료일"
    }
    SHIPPING_ZONE {
        NUMBER zone_no PK "권역번호"
        VARCHAR2 zone_name "권역 이름"
        NUMBER base_fee "기본 배송비"
        NUMBER min_days "최소 배송 기간"
        NUMBER max_days "최대 배송 기간"
        NUMBER special_max_days "특수품 배송 기간(군부대만)"
    }
    SHIPPING_AREA {
        NUMBER area_no PK "지역번호"
        VARCHAR2 area_name "지역 이름"
        CHAR zip_start "우편번호 시작"
        CHAR zip_end "우편번호 끝"
        NUMBER zone_no FK "소속 권역"
        NUMBER extra_fee "추가 배송비"
    }
    SHIP_FEE_HISTORY {
        NUMBER history_no PK "이력번호"
        CHAR fee_type "B기본 E추가"
        NUMBER zone_no FK "권역(B일 때만)"
        NUMBER area_no FK "지역(E일 때만)"
        NUMBER old_fee "이전 금액"
        NUMBER new_fee "새 금액"
        VARCHAR2 reason "변경 사유"
        DATE notice_date "공지일"
        DATE apply_date "적용일"
    }
    SHIP_DELAY {
        NUMBER delay_no PK "지연안내번호"
        NUMBER shipment_no FK "배송번호"
        VARCHAR2 reason "지연 사유"
        DATE new_due_date "새 배송 예정일"
        DATE notice_date "안내일"
        CHAR customer_choice "W기다림 C취소(선택)"
    }
    GROUP_WEIGHT_FEE {
        NUMBER fee_no PK "구간번호"
        NUMBER min_kg "최소 무게(초과)"
        NUMBER max_kg "최대 무게(이하)"
        NUMBER fee "배송비"
    }
    MEMBER {
        NUMBER member_no PK "회원번호"
    }
    PRODUCT_SIZE {
        NUMBER size_no PK "사이즈번호"
    }
```

| 표 | 핵심 설명 |
|---|---|
| ORDERS | 표 이름 `ORDER`는 오라클 예약어라 `ORDERS`로 지었다. 상품 합계는 주문상세로 계산하지만, **실제 결제 금액**은 그 당시의 사실이라 저장한다. |
| ORDER_DETAIL | 주문 N : 상품사이즈 M을 잇는 **연결 표**. 쇼핑몰 설계의 핵심. order_price는 나중에 가격이 바뀌어도 그대로 남는 주문 당시 가격이다. |
| SHIPMENT | 함께 배송이면 1건, 분리 배송이면 2건. 반품 기간 7일은 이 표의 delivered_date부터 센다. |
| SHIP_FEE_HISTORY | zone_no와 area_no 중 **하나만** 채운다(CHECK로 강제). |
| SHIP_DELAY | 분리 배송 중 한 택배만 늦어질 수 있으므로 주문이 아니라 **배송**을 가리킨다. |
| GROUP_WEIGHT_FEE | 부대 단체 주문 배송비 규칙 표. 다른 표를 가리키지 않는다. |

---

## ④ 취소·반품 묶음

```mermaid
erDiagram
    ORDER_DETAIL ||--o{ RETURN_REQUEST : "반품 교환 신청"
    PRODUCT_SIZE |o--o{ RETURN_REQUEST : "교환할 사이즈"
    ORDERS ||--o{ REFUND : "환불"
    RETURN_REQUEST |o--o{ REFUND : "반품 환불"
    ORDER_DETAIL ||--o{ STOCK_WAIT : "재고 부족"
    ORDERS |o--o{ NOTIFICATION : "문자 알림"

    RETURN_REQUEST {
        NUMBER request_no PK "신청번호"
        NUMBER order_detail_no FK "주문상세번호"
        CHAR request_type "R반품 E교환"
        VARCHAR2 reason_code "단순변심 사이즈 불량 오배송 설명다름"
        VARCHAR2 reason_detail "상세 내용"
        VARCHAR2 photo_url "사진"
        NUMBER exchange_size_no FK "교환할 사이즈(교환일 때만)"
        DATE request_date "신청일"
        VARCHAR2 status "신청 회수중 검수중 완료 거절"
        VARCHAR2 reject_reason "거절 사유(선택)"
        VARCHAR2 reject_photo_url "검수 사진(선택)"
        DATE done_date "처리 완료일"
    }
    REFUND {
        NUMBER refund_no PK "환불번호"
        NUMBER order_no FK "주문번호"
        NUMBER request_no FK "신청번호(반품일 때만)"
        NUMBER refund_amount "환불 금액"
        NUMBER deducted_ship_fee "차감한 배송비"
        NUMBER returned_point "돌려준 적립금"
        VARCHAR2 refund_method "환불 방법"
        DATE refund_date "환불일"
    }
    STOCK_WAIT {
        NUMBER wait_no PK "대기번호"
        NUMBER order_detail_no FK "주문상세번호"
        DATE notice_date "재고 부족 알림일"
        CHAR choice "W대기(답이 없으면 비어 있음)"
        VARCHAR2 choice_by "본인 또는 상담원"
        DATE choice_date "선택한 날"
        DATE wait_until "대기 기한(약속한 날짜)"
        VARCHAR2 result "입고배송 고객취소 기한만료취소"
    }
    NOTIFICATION {
        NUMBER noti_no PK "알림번호"
        VARCHAR2 phone "받는 번호(보낸 그 당시)"
        NUMBER order_no FK "관련 주문(선택)"
        VARCHAR2 noti_type "알림 종류"
        VARCHAR2 content "보낸 내용"
        DATE sent_at "보낸 날짜 시간"
        CHAR send_result "S성공 F실패"
    }
    ORDER_DETAIL {
        NUMBER order_detail_no PK "주문상세번호"
    }
    ORDERS {
        NUMBER order_no PK "주문번호"
    }
    PRODUCT_SIZE {
        NUMBER size_no PK "사이즈번호"
    }
```

| 표 | 핵심 설명 |
|---|---|
| RETURN_REQUEST | 주문 전체가 아니라 **주문상세(상품 1개)** 단위로 신청한다(16-4). 교환이면 exchange_size_no로 바꿀 사이즈를 가리킨다. |
| REFUND | 취소, 재고부족취소, 반품 모두 환불이 생기므로 주문을 가리킨다. 반품으로 인한 환불일 때만 request_no를 채운다. |
| STOCK_WAIT | order_no는 넣지 않는다. 주문상세를 따라가면 알 수 있기 때문이다. |
| NOTIFICATION | 재고 부족, 배송 지연, 웰컴백 쿠폰 문자를 한 표에 모은다. 번호를 바꾼 회원이 있어도 그때 보낸 번호가 남는다. |

---

## ⑤ 혜택·리뷰 묶음

```mermaid
erDiagram
    COUPON ||--o{ MEMBER_COUPON : "발급"
    MEMBER ||--o{ MEMBER_COUPON : "보유"
    ORDERS |o--o| MEMBER_COUPON : "사용"
    MEMBER ||--o{ POINT_HISTORY : "적립금"
    ORDERS |o--o{ POINT_HISTORY : "주문 적립 사용"
    ORDER_DETAIL ||--o| REVIEW : "리뷰"
    MEMBER ||--o{ REVIEW : "작성"

    COUPON {
        NUMBER coupon_no PK "쿠폰번호"
        VARCHAR2 coupon_name "쿠폰 이름"
        VARCHAR2 coupon_type "신규가입 웰컴백"
        NUMBER discount_amount "할인 금액"
        NUMBER min_order_amount "최소 주문 금액"
        NUMBER valid_days "유효 기간(일)"
        NUMBER trigger_days "기준 일수(웰컴백 60일)"
    }
    MEMBER_COUPON {
        NUMBER mc_no PK "회원쿠폰번호"
        NUMBER member_no FK "회원번호"
        NUMBER coupon_no FK "쿠폰번호"
        DATE issue_date "발급일"
        DATE expire_date "만료일"
        DATE used_date "사용일(선택)"
        NUMBER used_order_no FK "사용한 주문(선택, UK)"
    }
    POINT_HISTORY {
        NUMBER point_no PK "적립금내역번호"
        NUMBER member_no FK "회원번호"
        NUMBER order_no FK "관련 주문(선택)"
        CHAR point_type "A적립 U사용 R회수 B반환"
        NUMBER amount "금액"
        DATE created_at "발생일"
    }
    REVIEW {
        NUMBER review_no PK "리뷰번호"
        NUMBER order_detail_no FK "주문상세번호(UK)"
        NUMBER member_no FK "작성한 회원"
        NUMBER rating "별점 1~5"
        VARCHAR2 content "내용"
        DATE created_at "작성일"
    }
    MEMBER {
        NUMBER member_no PK "회원번호"
    }
    ORDERS {
        NUMBER order_no PK "주문번호"
    }
    ORDER_DETAIL {
        NUMBER order_detail_no PK "주문상세번호"
    }
```

| 표 | 핵심 설명 |
|---|---|
| COUPON | 60일 같은 바뀔 수 있는 규칙 값을 trigger_days에 저장한다(10-10). |
| MEMBER_COUPON | 쿠폰 N : 회원 M을 잇는 **연결 표**. used_order_no에 UNIQUE를 붙여 **주문 1건에 쿠폰 1장**만 쓰게 한다(10-1). expire_date는 발급 당시 유효 기간으로 정해진 약속이므로 저장한다. |
| POINT_HISTORY | 회원의 적립금 잔액 = 이 표의 합계(적립 + 반환 − 사용 − 회수). |
| REVIEW | 상품이 아니라 **주문상세**를 가리킨다. 산 상품에만, 한 번만(UNIQUE) 쓸 수 있다. |

---

## 아직 정하지 않은 것

- 재고 부족 답변 기한 **2일**, 대기 최대 **30일**, 배송비 변경 사전 공지 **7일** 같은 규칙 값을 어느 표에 저장할지 정해야 한다.
- 단체 주문의 "50kg 초과는 10kg마다 3,000원 추가" 규칙을 GROUP_WEIGHT_FEE 표에 어떻게 넣을지 정해야 한다.
- 고객센터 상담원 정보를 표로 관리할지 정해야 한다. (지금은 STOCK_WAIT.choice_by에 글자로 저장한다.)
