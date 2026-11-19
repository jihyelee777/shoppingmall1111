# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트
학원 과제: 의류 쇼핑몰 DB 설계. 대상은 **Oracle 21c XE**이고 SQL은 **SQL Developer**로 실행한다.
설계 순서: ① 요구사항 → ② 엔티티 → ③ 속성/PK → ④ 관계/FK → ⑤ ERD → ⑥ 정규화 + Oracle SQL.

## 진행 상황
- 새 대화를 시작하면 `00_진행기록.md`를 먼저 읽는다. 지금까지 한 단계, 결정, 다음 할 일이 적혀 있다.
- ①~④ 완료. 표 설계(칸, PK, FK, 관계)는 `03_ERD.md`에 있다(27개 표). 다음은 ⑤ ERDCloud로 ERD 그리기.
- 지난 대화 원문은 `대화기록_*.md`에 있다. 필요할 때만 찾아 읽는다.

## 기준 문서
- `01_요구사항.md`가 설계의 기준이다. 요구사항 번호(예: 16-2-1)를 그대로 참조한다.
- `db/`의 `schema.sql`, `seed.sql`, `examples.sql`, `README.md`는 **이전 MySQL 버전**(범용 쇼핑몰, 26개 표)이다. 오라클 문법과 `01_요구사항.md`에 맞게 바꿔서 이어 쓴다. 두 문서가 다르면 `01_요구사항.md`를 따른다.
- `db/README.md`의 docker/MySQL 실행 방법은 사용하지 않는다.
- 결과물 파일 이름: `02_테이블명세서.md`, `03_ERD.md`(Mermaid), `04_create_tables.sql`, `05_sample_data.sql`

## Oracle 환경
- 앱 계정: `SHOPMALL` / `shop1234`. `db/oracle/00_create_user.sql`을 **system 계정으로** 한 번 실행해서 만든다.
- 이 PC의 PATH에는 `sqlplus`가 없다. SQL은 사용자가 SQL Developer에서 실행한다(스크립트 실행 F5).
- SQL 파일은 UTF-8로 저장한다(한글 깨짐 방지).

## Oracle 작성 규칙 (MySQL에서 바꿀 때 특히 주의)
- 예약어는 표/칼럼 이름으로 쓰지 않는다: `ORDER`→`ORDERS`, `SIZE`→`size_name`, `DATE`, `COMMENT`, `USER`, `LEVEL`
- 자료형: `VARCHAR2`, `NUMBER`, `DATE`, `CLOB`. 한글은 1글자 3바이트이므로 크기를 넉넉히 잡는다.
- 21c의 표 칼럼에는 `BOOLEAN`을 쓸 수 없다 → `CHAR(1) CHECK (x IN ('Y','N'))`
- PK 번호는 `SEQUENCE` + `.NEXTVAL`로 만든다(수업에서 배운 방식). PK 칼럼 이름은 `member_no`, `order_no`처럼 `_no`로 짓는다.
- MySQL 문법 금지: `AUTO_INCREMENT`, `ENGINE=`, `LIMIT`(→ `FETCH FIRST n ROWS ONLY`), `DATETIME`/`TINYINT`/`TEXT`, 백틱, `ON UPDATE CURRENT_TIMESTAMP`, `IF EXISTS`
- 오라클은 빈 문자열 `''`을 NULL로 처리한다. `CHECK` 안에서는 `SYSDATE`를 쓸 수 없다.
- PL/SQL 블록은 `/`로 끝낸다. 계층 조회(카테고리)는 `CONNECT BY` 또는 재귀 WITH를 쓴다.

## 이미 정한 설계 결정 (뒤집지 말 것)
- 주민등록번호는 저장하지 않고 `birth_date`만 저장한다. 나이는 `MONTHS_BETWEEN`으로 계산한다.
- 나이 구분: 만14세 미만 / 14~18세 / 19세 이상. 만14세 미만은 가입할 때와 결제할 때마다 보호자 동의(`PARENT_CONSENT`)를 받는다.
- 반품·교환 기간은 법정 최소 7일이다(더 줄이면 무효). 4일 이내 접수는 혜택으로만 처리한다.
- 탈퇴는 소프트 삭제(status)로 처리한다. 계산할 수 있는 값(나이, 할인율, 마지막 주문일)은 저장하지 않는다. 그 당시의 사실(주문 당시 가격, 실제로 낸 배송비)은 저장한다.
- 바뀔 수 있는 규칙 값(쿠폰 금액, 60일 등)은 SQL에 직접 쓰지 않고 표에 저장한다.
