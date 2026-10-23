# CODEF 계좌 인증 계약

2026-10-23. 근거: `origin/haechan:docs/external/codef.md`, 회원 시나리오의 계좌 등록·인증, 현재 `docs/product/POLICY.md`의 가입/계좌 분리. 공급자 선정은 CODEF로 이미 설계돼 있었다. 실제 계약·상품 승인·키·은행별 기관코드 설정과 운영 호출은 아직 확인하지 않았다.

## 요구사항 대조

| 기준 | 현재 구현의 차이 | 적용 |
|---|---|---|
| 해찬 문서: 예금주 확인+1원 코드 입력 | 동기 verifier와 단일 등록 POST만 존재 | 인증 요청/상태/코드 확인을 추가하고 확인된 증명을 최종 등록에 소비 |
| 현재 정책: 소셜+SMS 가입, 계좌 확인 별도 | 구 문서는 PASS CI 교차검증 전제 | 가입 변경 없이 계좌 단계에서만 YYMMDD 입력. 가입 실명/CI 일치라고 주장하지 않음 |
| 실제 송금·수령과 계좌 점유 확인 구분 | 인증 성공이 회비 송금 성공으로 오인될 가능성 | 인증은 계좌 등록만 허용. 금액 원장·실제 거래 확인·ACTOR_FALLBACK 범위는 그대로 |
| 개인 계좌/모임 적립금/담당자 인계의 기존 권한 | 공통 verifier에 context가 없음 | 증명을 actor+목적+정확 context+은행/번호/예금주에 묶고 기존 권한/버전/실입금 조건을 최종 쓰기에서 재검사 |

## API와 수명

- `GET /api/v1/bank-verifications/banks`: `{available,banks:[{id,name}]}`. 서버에 설정된 은행만 반환; `available`은 운영 CODEF와 필수 설정이 준비된 경우에만 true. 클라이언트가 기관코드를 보내지 않는다.
- `POST /api/v1/bank-verifications`: Idempotency-Key 필수. `{purpose, contextId?, bankId, accountNumber, holderName, identity}`. purpose는 PERSONAL(null context), RESERVE(clubId), RESERVE_HANDOVER(handoverId). identity는 개인 생년월일 YYMMDD 6자리이며 이 API의 일시 입력으로만 사용한다.
- 응답 `{id, status, expiresAt, bankName, accountMasked, attemptsRemaining}`. authCode/identity/원문 계좌/공급자 응답은 응답·로그·명령 응답 저널에 넣지 않는다. 진행 상태는 PENDING/HOLDER_CHECK/TRANSFER_DISPATCHED, 코드 입력 AWAITING_CODE, 확인 VERIFIED, 최종 소비 CONSUMED, 종료 FAILED/UNKNOWN/EXPIRED/LOCKED다. 외부 호출 거절·실패는 durable 상태의200응답으로 구분하고 시작 전 설정/입력/권한 오류는 통상4xx/503이다.
- `GET /api/v1/bank-verifications/{id}`는 본인에게만 상태 반환. `GET /api/v1/bank-verifications?purpose=...&contextId=...`는 본인의 해당 목적 최근 미소비 인증 목록(plain array of masked views)으로 앱 재진입을 지원한다.
- `POST /api/v1/bank-verifications/{id}/confirm`: Idempotency-Key 필수, `{code}`. 4자리 숫자를 상수 시간 비교한다. 잘못된 코드도 시도 횟수와 멱등 응답을 커밋한 뒤 HTTP400으로 반환한다. 같은 키 재시도는 시도를 추가 차감하지 않는다.
- 최종 개인계좌/적립금/인계 기존 POST에 `verificationId`를 추가한다. 운영 verifier는 유효한 VERIFIED 증명을 기존 등록 트랜잭션 안에서 1회 소비한다. 기존 확인 계좌는 최종 등록 성공 전까지 보존한다. 충돌/실패 시 증명 소비도 롤백한다. 테스트 전용 verifier 대역은 운영 승인 경로가 아니다.

기술 기본값: 인증 유효10분, 코드 최대5회, 사용자 요청 간격120초, 동일 은행계좌 일5회(Asia/Seoul 달력일, 사용자 간 공유)(공식 제한보다 서비스가 넓게 허용하지 않음). 정상적인 페이지 재조회는 전송을 재실행하지 않는다. 이 값들은 사용자 정책 확정값이 아니라 남용·재시도 제어 기본값으로 결정 원장에 기록한다. 코드 확인 뒤에도 최초 만료시각을 연장하지 않는다.

## 외부 호출의 경계

인증 생성/멱등 receipt를 먼저 커밋한다. 별도 짧은 트랜잭션으로 한 실행만 HOLDER_CHECK를 선점하고, 예금주 확인 후 TRANSFER_DISPATCHED를 **1원 호출 전에 커밋**한다. 외부 HTTP 동안 DB lock/트랜잭션을 유지하지 않는다. 공급자 호출 예외·timeout/응답 유실은 FAILED 또는 UNKNOWN으로 남기고 자동 재전송하지 않는다. 같은 POST 키 재시도는 기존 id만 조회하며 이미 선점한 실행을 재개하지 않는다. 진행 상태가 오래 남으면 결과 미확인 안내와 수동 확인 대상으로 처리한다. UNKNOWN도 인증 완료/등록 가능으로 보지 않는다.

은행 목록은 서버 설정 JSON `CODEF_BANKS_JSON=[{"id":"...","name":"...","holderOrganization":"...","transferOrganization":"..."}]`. 은행별 두 상품 코드가 공식 기관표/계약에서 확인되기 전에는 빈 배열로 둔다. 자동 0-padding/예시 코드의 전체 은행 매핑 추정은 금지한다.

CODEF_MODE 기본 DISABLED, 허용 DISABLED/DEMO/PRODUCTION. DEMO의 랜덤 데이터로 실제 계좌를 인증하지 않으므로 사용자 인증 시작은 PRODUCTION에서만 허용한다. CODEF_CLIENT_ID/CODEF_CLIENT_SECRET/BANK_DATA_KEY_BASE64는 서버 비밀 설정. gateway는 공식 OAuth/development/api 호스트만 사용하며 테스트는 주입한 HTTP transport 대역을 사용한다.

OAuth Basic/form, `expires_in` 범위 내 토큰 재사용, 제품 POST는 공식 Java SDK와 같은 전체 JSON URL encoding, 응답은 전체 URL encoded일 때만 한 번 decode한다. 이미 raw JSON인 응답의 `+`를 손상시키지 않는다. HTTP200만으로 성공 처리하지 않고 CF-00000 및 name/authCode 필수값을 확인한다. `inPrintType="0"` 명시. 30초 timeout, 전송 자동 재시도 없음. 반환 예금주와 입력 이름은 trim 후 정확 일치만 허용하며 임의 바이트 잘라내기/유사 매칭은 하지 않는다. CODEF 거래 추적 ID는 은행 입출금 reference로 사용하지 않는다.

## 보관·검증

계좌번호/예금주 AES-GCM 암호화, 코드·계좌 rate-limit fingerprint는 transferOrganization+정규화 계좌번호의 BANK_DATA_KEY 기반 HMAC이며 같은 계좌의 사용자 간 동시 요청을 DB에서 직렬화한다. identity는 DB에 저장하지 않는다. 운영 로그에 provider body/사용자 입력/비밀키를 출력하지 않는다. 서버 계좌 read/정확 송금 맥락의 기존 마스킹·권한을 유지한다.

검증은 gateway protocol 대역, 실제 PostgreSQL/Flyway/HTTP 권한·멱등·재시도·일회소비·거래 롤백, Flutter 단계/오류/재진입으로 구분한다. 실 CODEF/1원 송금·실기기 인증·공급자 계약 승인을 대역 성공으로 대신하지 않는다.

공식 근거: [예금주명 인증](https://developer.codef.io/products/bank/common/etc/accountHolderAuth), [1원 이체](https://developer.codef.io/products/bank/common/etc/accountTransferAuthentication), [REST 가이드](https://developer.codef.io/common-guide/rest-api), [공식 Java connector](https://github.com/codef-io/easycodef-java/blob/master/src/main/java/io/codef/api/EasyCodefConnector.java).


앱 begin/confirm은 identity/code가 포함되므로 기존 영속 commandjournal에 보관하지 않는다. dialog 메모리의 불변 body/key로만 동일요청을 재시도하며 닫힘·세션변경 시 폐기한다. 서버 Commands에도 원문DTO 대신 분리된 domain의 BANK_DATA_KEY 기반 HMAC fingerprint를 전달하여 저엔트로피 코드/DOB raw SHA 저장을 피한다. 시작 receipt의 action이 실제 신규 실행됐을 때만 dispatch하며 기존 receipt 재조회로 외부호출을 재개하지 않는다. VERIFIED 미소비 증명을 앱 재진입해 사용할 때는 은행·원계좌번호·예금주를 다시 입력하고 서버가 exactbinding을 검사한다. 마스킹 조회에서 원문을 복원하거나 자동 새1원 인증을 보내지 않는다.
