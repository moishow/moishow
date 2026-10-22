# Spring Boot 기반과 Java 정산 코어 실행 계획

> 이슈 #18 · develop → issue/18-spring-bootstrap · 사용자 Spring Boot 진행 지시. 이번 채팅에서 직접 실행.

## 목표와 범위

전체 정책을 정본으로 유지하며 Java 서버의 빌드·보안 경계·금액 계산·HTTP 계약을 검증한다. 기존 JS PR을 삭제/병합하지 않고 동등 예제를 Java 테스트로 옮긴다.

## 구조와 인터페이스

- `apps/api/build.gradle`: Boot4.1.1/Java25, webmvc·validation·security·actuator. DB 없는 기초 실행.
- `.../settlement/SettlementCalculator.java`: 입력/출력 record와 순수 계산. splitEven, splitProportionally, calculateCancellation, settleRound, settleEvent.
- `.../settlement/SettlementPreviewController.java`: dev 전용 POST `/api/v1/settlements/preview`, 원화 숫자 강타입 계약, 잘못된 입력은400.
- `.../config/SecurityConfiguration.java`: 기본 deny, health 공개, dev의 계산 전용 경로만 허용. 임의 사용자/DB 권한을 가장하지 않음.
- `.../settlement/*Test.java`: 정책·금액 보존·실확인·중복·HTTP 보안 테스트.
- `.github/workflows/checks.yml`: Java25 wrapper test + 기존 화면 인수 체크.

## 실행 단계

- [x] 공식 Initializr 프로젝트 생성과 정식 버전 확인.
- [x] 기존 정책의 숫자·0명·부분입금·비례환불·중복/안전범위 테스트를 먼저 쓰고 실패 확인.
- [x] Java 순수 코어 구현 후 테스트 통과.
- [x] dev HTTP 정상/오류·기본 프로필 차단 테스트 실패 확인 후 구현.
- [x] wrapper test/bootJar, 로컬 HTTP 실행, CI와 코드 검토.
- [x] 스택/이슈/로드맵/옵시디언 갱신, push, develop 대상 PR.

## 인수 예제

1차 지출100,000−확인 취소비20,000을4명 분담하면20,000씩, 2차40,000/4=10,000. 각40,000원 납부자는 순차액10,000 환불. 이미10,000 환불했으면 재환불0. 동일비율3명에게10,000 초과비 환불은3,333×3+적립1. 참석0명·지출100,000/수령비60,000은 주최 부담40,000.

## 한계

실계좌·DB·인증 공급자·푸시·STOMP·Quartz가 실제 연결된 것은 아니다. dev 계산 API는 무상태 숫자 검증용이다. 비밀값/개인정보 입력을 요구하지 않는다. 인수 예제 이외 경계도 테스트로 고정하고 판정되지 않은 운영 정책을 새 기본값으로 숨기지 않는다.

## 검증 결과

최초 Java21/Maven 기반 검증에서 `mvnw verify` 성공: 도메인24·dev HTTP6·기본 프로필 보안1·컨텍스트1, 총32개 실패0. 실제 로컬 health/5,000원 환불 응답 확인. 개별 사용자 합계 외 이벤트 전체 입금·환불·부담·추가청구·환불예정 합계의 상한 회귀4개는 수정 전 실패·수정 후 통과했다. 독립 코드 검토의 합계 범위 지적을 반영했다. `node scripts/check-handoff.mjs`: 51화면·118페이지·585참조, 실패0.

사용자 후속 지시로 Java25 + Gradle Wrapper9.8.2로 전환했다. `gradlew --no-daemon build`를 실제 Java25.0.4.1에서 실행해32개 테스트 실패0·실행 JAR 생성 성공. 컴파일 class major69(Java25) 확인. CI도 JDK25/Gradle build로 변경하고 Maven 설정/Wrapper는 제거했다.
