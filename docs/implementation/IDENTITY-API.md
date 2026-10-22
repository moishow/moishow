# Identity API 계약 — 이슈12

Java25·Spring Boot4.1.1·Gradle9.8.2. `db` 프로필에서만 활성화. 사용자/역할은 opaque bearer 세션에서 결정한다. UUID를 인증 대신 사용하지 않는다. 소셜/SMS 공급자 자격 미설정503, 세션 오류401, 역할/관계 위반403, 검증400, 중복/버전409, 발송 간격429.

## 인증·가입

| 메서드·경로 (`/api/v1`) | 입력·결과 |
|---|---|
| POST /auth/challenges | 서버 challengeId·nonce, TTL5분, Google/Apple 로그인 전 발급 |
| POST /auth/social | provider GOOGLE/APPLE/KAKAO, token, challengeId(Google/Apple). 검증 후 token·scope·expiresAt·userId |
| POST /auth/sms | 제한 bearer, phone E.164 한국 휴대전화. challenge id·expiresAt만 응답 |
| POST /auth/sms/{id}/verify | 제한 bearer, code6자리. 본인 challenge/5분/최대5회, verified만 응답 |
| POST /auth/register | 제한 bearer, nickname·verificationId. 확인 전화번호 고유 검사, 활성 token 발급·기존 제한 세션 폐기 |
| POST /auth/logout | 현재 bearer 폐기 |
| GET /me | 활성 bearer, 본인 id·nickname·phone·version |

SMS 검증은 전화번호 문자열 제출과 별개다. 다른 소셜의 동일 번호 가입은409이며 연결/병합하지 않는다. 발송은 수신 번호와 가입 계정별60초 간격·계정별시간당5회 제한. 제한 세션15분·활성8시간, 해시만 저장한다. Google/Apple challenge는 단회 사용. 인증 발급·OTP 동작은 일회 자격 증명을 다루므로 아래 업무 Idempotency 응답 원장에 bearer/OTP를 저장하지 않는다. 재시도 때 로그인/상태를 다시 확인한다.

## 업무 쓰기 계약

모든 아래 POST는 UUID `Idempotency-Key` 헤더 필수. 동일 사용자·작업·key·본문 재시도는 같은 JSON 응답, 다른 본문은409. 성공 응답과 업무 변경은 같은 DB 트랜잭션에 저장된다. 오류는 원장에 성공으로 보관하지 않는다. 생성 외 쓰기는 최신 리소스 `version` 필수이며 충돌 시 조회 후 새 key로 재시도한다. JSON 인코딩 동일 DTO 값은 동일 본문으로 취급한다.

| 경로 | 입력 | 권한·동작 |
|---|---|---|
| POST /clubs | name·joinMode IMMEDIATE/APPROVAL | 활성 계정, 소유자 멤버 생성 |
| GET /clubs | 없음 | 본인 활성 가입 모임 |
| GET /clubs/{id} | 없음 | 이름·가입 방식·version·본인 관계 미리보기 |
| GET /clubs/{id}/members | 없음 | 해당 활성 부원, 닉네임/역할만 |
| GET /clubs/{id}/join-requests | 없음 | 해당 OWNER/ADMIN만 대기 가입 userId·nickname·status·최신 모임version 조회 |
| POST /clubs/{id}/join | nickname·version·선택 inviteToken | 블랙 차단→강퇴 이력 승인→정상 초대/즉시 가입→기타 승인 대기 |
| POST /clubs/{id}/members/{userId}/approve | version | 해당 모임 OWNER/ADMIN, PENDING만 활성화 |
| POST /clubs/{id}/members/{userId}/expel | version | OWNER/ADMIN, ADMIN 대상은OWNER만, OWNER 보호 |
| POST /clubs/{id}/members/{userId}/blacklist | version·enabled | 해당 관리 권한, 비부원도 차단 가능, 다른 모임 불변 |
| POST /clubs/{id}/members/{userId}/role | version·role ADMIN/MEMBER | OWNER만, ACTIVE 대상, OWNER 보호 |
| POST /clubs/{id}/invites | version | 해당 OWNER/ADMIN,7일 토큰, 초대 테이블에는 해시 보관(업무 재시도 원장은 동일 토큰 응답 보관) |
| POST /clubs/{id}/leave | version | 본인 가입/대기 종료, OWNER는 승계 필요로 거부 |
| POST /clubs/{id}/events | title·kind REGULAR/LIGHTNING·publicEvent·startsAt·endsAt·version(모임) | REGULAR=OWNER/ADMIN, LIGHTNING=부원, 공개는LIGHTNING만 |
| GET /events/{id} | 없음 | 부원·공개·기확정 참가·해당 정산 담당에게 메타데이터/차수 조건 |
| GET /events/{id}/access | 없음 | viewSettlement/manageSettlement/manageEvent 관계 판정 |
| GET /events/{id}/participations | 없음 | 해당 주최자/정산 담당만 참가/대기/합류 요청 id·상태·닉네임·차수version 조회, 개인정보 제외 |
| GET /rounds/{id}/participation | 없음 | 본인 참가 상태·id·차수version 재조회, 다른 사용자는404 |
| POST /events/{id}/rounds | capacity1~10000·closesAt·cancellationFee(생략0)·version(이벤트) | 활성 부원인 해당 주최자 |
| POST /rounds/{id}/participations | version(차수) | 마감 전 정원 내CONFIRMED/초과WAITLISTED, 마감 후LATE_REQUESTED |
| POST /rounds/{id}/participations/{participationId}/approve | version(차수) | 해당 주최자, LATE_REQUESTED만·정원/블랙/소속 재검사 |
| POST /rounds/{id}/participations/{participationId}/cancel | version(차수) | 본인만, 확정 이력/고지비 보존, 실제 금액 청구는13에서 연결 |

모임 쓰기는 모임version을 반환한다. 차수 추가는 새 차수version과 갱신된 부모eventVersion을 각각 반환한다. 다음 차수 생성에는eventVersion, 참가 요청에는version을 사용한다. 참가 쓰기는 차수version을 반환한다. 참가 응답의version은 참가 레코드 내부 버전이 아니라 잠근 차수version이다. 이벤트 생성 응답version은 새 이벤트version이므로 모임 후속 쓰기는 모임을 다시 조회한다.

정산 담당은 주최자와 별도로 저장한다. 일반 모임 관리자가 이벤트 정산 쓰기를 자동 얻지 않는다. 모임 탈퇴 후 담당 권한/과거 확정 참가의 자기 정산 접근을 유지하고 일반 모임 목록 접근은 제거한다. 아직 금액 원장/실제 정산 데이터가 없으며 이 판정은13의 접근 경계로 사용한다. 미확정 대기/합류 요청만으로 금융 접근을 부여하지 않는다.

## 명시적 후속 범위

운영 소셜/SMS 키 및 실제 사용자 수신 검증, 프로필 수정·계정 삭제/복구·모임 소유권 승계·해산/정산 인계 UI/API, 비용 변경 재동의·대기 자동 승격·취소 후 재신청 정책은 별도다. OWNER 탈퇴는 승계 미구현 동안 거부한다. 차수 종료 후 새 합류 거부, 기존 참가 중복 요청은409; 재시도는같은key로 수행한다. 서버가 임의로 대기자를 확정시키거나 납부 미완료를 참여 취소하지 않는다.

## 근거

[Spring SQL/JPA](https://docs.spring.io/spring-boot/reference/data/sql.html), [Spring JWT](https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/jwt.html), [Kakao token-info](https://developers.kakao.com/docs/ko/kakaologin/rest-api#req-access-token-info), [SOLAPI HMAC](https://solapi.com/developers/api/authentication-api-key), [PostgreSQL Testcontainers](https://java.testcontainers.org/modules/databases/postgres/).
