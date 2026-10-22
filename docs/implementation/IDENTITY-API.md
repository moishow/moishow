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
| POST /rounds/{id}/participations/{participationId}/approve | version(차수) | 종료 전 활성 원주최자, LATE_REQUESTED만·정원/블랙/소속 재검사. 종료 후 현 정산담당자 또는 현재 활성 원주최자+필수 사유, 취소차수/블랙/소속 재검사·과거 사실 정원이유 거부 안 함 |
| POST /rounds/{id}/participations/{participationId}/cancel | version(차수) | 본인만, 확정 이력/고지비 보존, 실제 금액은 금융 원장의 고지비/실확인 기준으로 연결 |

모임 쓰기는 모임version을 반환한다. 차수 추가는 새 차수version과 갱신된 부모eventVersion을 각각 반환한다. 다음 차수 생성에는eventVersion, 참가 요청에는version을 사용한다. 참가 쓰기는 차수version을 반환한다. 참가 응답의version은 참가 레코드 내부 버전이 아니라 잠근 차수version이다. 이벤트 생성 응답version은 새 이벤트version이므로 모임 후속 쓰기는 모임을 다시 조회한다.

정산 담당은 주최자와 별도로 저장한다. 일반 모임 관리자가 이벤트 정산 쓰기를 자동 얻지 않는다. 모임 탈퇴 후 담당 권한/과거 확정 참가의 자기 정산 접근을 유지하고 일반 모임 목록 접근은 제거한다. 영속 금융 원장과 연결되어 자기 요청·실확인·환불·계산 근거를 같은 관계로 제한한다. 미확정 대기/합류 요청만으로 금융 접근을 부여하지 않는다.

## 현재 구현과 외부 수락

프로필 수정·계정 삭제 업무가드·모임장 승계·해산/정산 인계·비용 재동의는 현재 API로 연결했다. OWNER 탈퇴는 실제 소유권 승계 완료 후 가능하다. 종료 후에도 본인 LATE_REQUESTED를 받아 현 정산담당자 또는 현재 활성 원주최자가 명시 사유와 실제 참석 사실을 확인해 승인할 수 있다. 신규 무관 사용자를 임의 추가하는 경로는 아니다. 기존 참가 중복 요청은409, 재시도는 같은key로 수행한다. 새 REJECTED 미확정 요청은 일반 금융 참석 정정으로 재승인/취소비 대상으로 바꿀 수 없다.

대기 자동 승격·취소 후 임의 재신청은 수행하지 않고 서버가 납부 미완료를 참여 취소하지 않는다. 운영 소셜/SMS 실제 자격·수신·실계좌 어댑터와 공급자/실기기 수락, 소셜 계정 자체 복구는 구현된 앱의 안내/오류 처리와 구분한다.

## 근거

[Spring SQL/JPA](https://docs.spring.io/spring-boot/reference/data/sql.html), [Spring JWT](https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/jwt.html), [Kakao token-info](https://developers.kakao.com/docs/ko/kakaologin/rest-api#req-access-token-info), [SOLAPI HMAC](https://solapi.com/developers/api/authentication-api-key), [PostgreSQL Testcontainers](https://java.testcontainers.org/modules/databases/postgres/).

## 앱16 소개·신청 결정 보완 계약

CLUB_CREATE의 name/joinMode는 필수이며 description(1000자), region/category(각100자), imageFileId는 선택이다. 선택 텍스트는 strip 후 검사한다. GET /clubs·/clubs/{id}는 이 필드와 activeMemberCount(실제 ACTIVE 가입자 수)를 반환한다. 소개는 기존과 같이 가입 전 활성 사용자도 열람하며 지역/분류는 자유 텍스트다. 공개/비공개 flag·GPS·지도 권한은 추가하지 않는다.

POST /clubs/{id}/metadata는 모임 version과 선택 description/region/category/imageFileId/clearImage를 받고 현재 OWNER/ADMIN만 갱신한다. null은 보존, 빈문자는 선택 텍스트 초기화, clearImage=true는 사진 연결 해제다. 새 대표사진은 요청자 소유 personal POST 이미지만 허용하며 정확한 club.imageFileId 연결만 소개 독자에게 재공개한다. 내부 게시물·증빙 파일 및 선택하지 않은 개인사진은 비공개 경계를 유지한다.

POST /clubs/{id}/join에 선택 memo(1000자)를 받는다. GET /clubs/{id}/join-requests는 현재 관리자가 읽는 신청 memo/강퇴이력/버전을 포함한다. 기존 POST /clubs/{id}/members/{userId}/reject는 version·필수 reason(1000자)을 받으며 PENDING만 REJECTED로 처리한다. ACTIVE 부원을 거절할 수 없다. GET /clubs/{id}/join-history는 현재 OWNER/ADMIN에게 해당 모임 전체, 나머지 사용자에게 본인 이력만 반환한다. 신청/승인/거절을 SUBMITTED/APPROVED/REJECTED로 각각 기록한다. 가입 재신청은 기존 join 규칙을 따르며 거절을 블랙리스트로 취급하지 않는다.

POST /rounds/{id}/participations에 선택 memo(1000자)를 받는다. POST /rounds/{id}/participations/{id}/reject는 version·reason을 받아 현재 활성 원주최자만 LATE_REQUESTED && everConfirmed=false를 REJECTED로 처리한다. 현재 정산 인수자 자격만으로 거절할 수 없으며 확정자/대기자를 선별 제외하지 않는다. 거절은 취소·노쇼·비용·금융/점수 이력을 만들지 않는다. 기존 차수+사용자 중복 신청409 규칙을 유지한다. GET /rounds/{id}/request-history는 현재 활성 원주최자에게 해당 차수 전체, 나머지 사용자에게 본인 이력만 반환한다.

두 history 응답은 id·userId·status·memo·reason·createdAt·createdBy와 nickname/departed(신청자), actorNickname/actorDeparted(이력 작성자)를 가진다. 현재/마지막 모임 닉네임과 서비스 닉네임 fallback을 재사용하며 PENDING/REJECTED 신청자가 명시한 모임 신청 닉네임도 우선한다. 과거 로그의 본문은 보존하고 조회 때 현재 관계로 이름을 표시한다. 사유/메모는 이 제한된 history 및 정확 가입관리자 pending 큐에서만 노출하고 일반 모임 소개·부원목록·정산 담당자 참여목록에는 포함하지 않는다. 모든 새 POST에 기존 Idempotency-Key·리소스 version 규칙을 적용한다. 실제 검증 결과는 REQUIREMENTS-AUDIT를 따른다.

탐색 GET /clubs/discover?q=&region=&category=&offset=0&limit=50은 현재 ACTIVE 모임 소개와 같은 필드/실제 activeMemberCount를 반환한다. q는 이름 부분 일치, region/category는 trim한 자유 텍스트의 대소문자 무시 정확 일치이며 각각 선택이다. 검색과 각 필터는 최대100자, 페이지 검증·정렬(name,id)은 기존 규칙이다. 공개/비공개 정책 결정을 대신하는 새 flag나 위치 권한을 만들지 않는다.
