# 모이쇼 기술스택 — Spring Boot 기준

> 2026-10-22 · 사용자 서버 선택: Spring Boot. 기존 추천 조합의 JavaScript 서버 항목을 아래 Java 대응으로 변경한다. Spring Boot는 사용자 확정이며, 나머지 영역은 이를 기준으로 맞춘 구현 추천 기준이다. 외부 계정/클라우드 자원을 생성한 것은 아니다.

| 영역 | 기준 |
|---|---|
| 앱 | Flutter/Dart, Riverpod, go_router, Dio |
| 서버 | Java 25 LTS, Spring Boot 4.1.1, Spring MVC, Gradle Wrapper 9.8.2 |
| API | REST·DTO 계약 문서. 기계용 OpenAPI 명세는 후속 정비. 최종 정산 계산은 서버 담당 |
| DB/마이그레이션 | PostgreSQL, Spring Data JPA/Hibernate, Flyway |
| 인증 | Spring Security OAuth2 Client/Resource Server, 공급자 검증 및 서비스 세션, 신규 SMS 완료 전 제한 세션 |
| SMS/예금주 | SOLAPI 어댑터, 계좌 확인은 해찬 설계의 CODEF 예금주+1원 인증. 가입 실명/CI 전제 없음. 실제 계약/키/운영 수락 별도 |
| 채팅 | Spring WebSocket/STOMP, Flutter stomp_dart_client. 메시지 DB 저장 후 전송/재연결 누락 조회 |
| 작업 처리 | Quartz JDBC JobStore + PostgreSQL outbox. 현재 요청 제한도 DB로 검증하며 Redis는 향후 캐시 후보 |
| 파일/푸시 | 비공개 S3·현재 권한을 검사하는 bearer 파일 프록시, FCM/iOS APNs. 인앱 알림함은 DB 영속 |
| 운영자 웹 | React/TypeScript/Vite |
| 배포 | Docker·EC2·Caddy, RDS PostgreSQL, S3/CloudFront, GitHub Actions |
| 테스트/관측 | JUnit Jupiter·Spring 테스트·Testcontainers PostgreSQL17·Flutter 테스트, CloudWatch/Sentry |

## Java 전환의 경계

- NestJS·Drizzle·BullMQ·Socket.IO 서버는 채택하지 않는다. STOMP는 Socket.IO와 다른 프로토콜이므로 Flutter 클라이언트도 맞춘다.
- 기존 PR #17의 JavaScript 코어는 정책 대조/브라우저 예제로 보존한다. 운영 서버는 Java 계산을 사용하며 중복 구현의 정책 예제를 맞춘다.
- Java 원화는 long, 비례 곱셈은 BigInteger. 현재 API는 기존 웹 계산과의 호환을 위해 원화 값과 누적 합계를 0~9,007,199,254,740,991로 제한한다. 실수 원화·암묵적 반올림을 허용하지 않는다.
- JPA 트랜잭션과 DB 제약/락으로 입금·정정·인계·적립금을 보호한다. Redis나 단순 스케줄러 메모리만으로 금액·예약 업무를 보존하지 않는다.
- Quartz JDBC의 운영 스키마는 Flyway로 관리하고 자동 재시작 시 테이블을 재생성하는 설정을 사용하지 않는다.

## 이슈 #18 첫 구현

`apps/api/`: 공식 Spring Initializr 기반 Java25/Boot4.1.1, Gradle Wrapper, 순수 정산 코어·정책 테스트·개발용 미리보기 API·보안 기본값. 로컬 JDK25를 사용한다. 이슈12에서 PostgreSQL/JPA/Flyway, db 프로필의 계정·모임·참가 API와 외부 소셜/SMS 어댑터를 구현했다. 정산·인계·운영·채팅·파일 어댑터와 현재 권한 검사를 구현했다. 실제 공급자 자격·수신·배포는 별도 검증이며 계좌 소유 확인 어댑터는 계약 확인 전 미완료503이다. 스택에 기재된 모든 기능을 현재 구현했다고 주장하지 않는다.

기본 프로필은 health 외 모든 요청 거부. `dev` 프로필에서만 loopback에 입력 숫자를 계산하는 미리보기 API를 제공하며 실제 이체/저장/사용자 데이터에 접근하지 않는다. 테스트는 이 경계와 정상/비정상 금액 응답을 검사한다.

## 공식 확인

- Spring Initializr 메타데이터 및 공식 배포 저장소에서 4.1.1 안정 버전 확인.
- [Boot 요구 사항](https://docs.spring.io/spring-boot/system-requirements.html): Java25 및 Gradle 지원 범위 확인.
- [Spring WebSocket](https://docs.spring.io/spring/reference/web/websocket.html), [Spring Security OAuth2](https://docs.spring.io/spring-security/reference/servlet/oauth2/index.html).
- [Quartz JDBC 지원](https://docs.spring.io/spring-boot/reference/io/quartz.html), [Flutter STOMP client](https://pub.dev/packages/stomp_dart_client).

- [Gradle 호환성](https://docs.gradle.org/current/userguide/compatibility.html), [Boot Gradle 플러그인](https://docs.spring.io/spring-boot/gradle-plugin/index.html): Java25 실행/도구체인 지원 조합으로 Gradle9.8.2를 고정. 공식 Initializr wrapper 사용, 배포 SHA-256 검증.

## 이슈12 영속 기반

[API 계약](../implementation/IDENTITY-API.md)과 [실행 계획](../implementation/IDENTITY-DB-PLAN.md). PostgreSQL17/Flyway V1·Hibernate validate, db 프로필만 영속 기능 활성화. 권한은 매 요청의 DB 세션/관계에서 검사한다. 테스트는 실제 PostgreSQL Testcontainers이며 H2 대체·Docker 없을 때 자동 생략을 사용하지 않는다. Compose는 로컬 loopback 전용이다.
