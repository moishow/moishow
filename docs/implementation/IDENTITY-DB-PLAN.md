# 계정·모임·참가와 DB 구현 계획 — 이슈12

이 문서는 PR20 당시 계획·실행 이력이다. 이후 모임장 승계·종료 후 실제 참석 정정/본인 합류 요청·정산 인계와 V11 거절/소개 계약이 추가됐다. 현재 요구/권한은 POLICY·IDENTITY-API·STATE-MODEL·REQUIREMENTS-AUDIT를 우선하며 아래 당시 미구현/거부 범위를 현재 기능으로 오해하지 않는다.

정본: POLICY P02/P07/P09/P10, STATE-MODEL. 사용자 PR19 머지 및 다음 이슈 구현 지시. PR19를 develop71251b3에 머지했고 issue/12-identity에서 기존 폴더를 유지해 직접 실행한다. Java25/Boot4.1.1/Gradle9.8.2 유지.

## 설계

PostgreSQL/Flyway/JPA. 공급자+subject 고유, 실제 검증 전화번호 고유. 소셜 실검증→제한 세션→SMS OTP 확인→등록→활성 세션. bearer는256비트 무작위이며 해시만 저장한다. Google/Apple 서명·issuer·audience·서버 nonce, Kakao token-info 앱ID 검증. 공급자 키 없으면503, 테스트 대역은 테스트 전용이다.

모임 OWNER/ADMIN/MEMBER와 이벤트 담당 권한 분리. 즉시/승인 가입·실제 초대 토큰·강퇴 이력 승인 우선·블랙 최우선. 정모는 OWNER/ADMIN, 번개는 부원, 공개는 번개만. 차수 정원 내 확정/초과 대기, 마감 후 요청·주최 승인. 탈퇴/강퇴해도 과거 확정 참가와 담당 기록은 보존한다.

모임/차수 행 잠금과 FK/unique로 경쟁을 보호한다. 쓰기는 사용자/경로별 Idempotency-Key와 본문 해시, 갱신 version 검사로 재시도 중복과 오래된 변경을 막는다. 본인·부원·공개·과거 확정 참가·담당 관계를 서버에서 조회한다. 기본/dev는 오프라인 계산 경계 유지, db 프로필에서 영속 API 활성화. 실제 PostgreSQL Testcontainers 필수, 로컬 Compose 제공.

## 작업 순서

- [x] PostgreSQL HTTP 통합/동시성/제약 테스트 작성 후 RED 확인.
- [x] Flyway 스키마/JPA/DB 프로필/서비스 세션/소셜·SMS 어댑터 구현.
- [x] 모임/초대/강퇴·블랙/이벤트/차수/참가/열람 권한 구현.
- [x] 기존32개 포함 전체 테스트·실행 JAR·화면 검사 GREEN.
- [x] 실행·API 문서/CI/이슈/옵시디언 갱신, 독립 검토와 develop PR.

## 결정·한계

미결인 대기 자동 승격은 수행하지 않는다. 종료 후 새 합류 거부, 소유자는 승계 없이 탈퇴 불가. 제한 세션15분/활성8시간, OTP5분·5회·재전송60초, 초대7일은 초기 보안 설정이다. 금액 원장/요청·정정/정산 상태는13에서 구현한다. 공급자 계약/키와 실제 문자 발송은 별도이며 테스트를 실인증 연결로 말하지 않는다.

검토 초점: 세션 위조/만료/제한, IDOR/타 모임 권한, 블랙·강퇴 초대 우회, 동시 정원, 재시도 충돌/롤백, 탈퇴 후 자기 정산 접근, FK·unique·버전과 외부 서비스 실패.

## 실행·검토 결과

Java25 Gradle `--no-daemon build` 성공: 기존32개+PostgreSQL HTTP17개+provider 미설정 거부1개=50개, 실패/생략0. Docker PostgreSQL17에서 Flyway V1·Hibernate validate, 고유/FK 제약·동시 정원·동일key 동시 재시도 검증. 화면 인수51개/118페이지/585참조 실패0.

독립 코드 검토 P2 세 건: 부모 이벤트 버전 누락, 관리자 가입 대기 목록 누락, 주최자 합류 요청/본인 상태 재조회 누락. 추가로 계정별 SMS 발송 제한을 보강했다. 재현 테스트4개가 먼저 실패했고 수정 후 전체50개 통과. 차수 생성 eventVersion 명시, admin-only join-requests, 담당-only participations, self-only participation API를 추가했다.

소유자 승계/API 부재 시 탈퇴 거부, 종료 후 신규 합류 거부, 대기 자동 승격 없음은 위 명시한 범위 결정이다. 실제 공급자 credentials/수신 검증과 금액별 세부 접근은 후속이다. 검토에서 별도 확정 IDOR·정원 초과·탈퇴 후 책임 소실은 발견되지 않았다. 후속13은 이 API 권한과 원장을 연결하며 완료된 실송금을 가장하지 않는다.
