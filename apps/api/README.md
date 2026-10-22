# Moishow Spring API

Java25 · Spring Boot4.1.1 · Gradle Wrapper · 이슈 #18

## 실행·검증

Windows PowerShell:

```powershell
$env:JAVA_HOME = 'C:\tools\jdk-25'
.\gradlew.bat --version
.\gradlew.bat build
.\gradlew.bat bootRun '--args=--spring.profiles.active=dev --server.port=18080'
```

JDK 경로는 각 환경의 Java25 설치 위치로 바꾼다. PATH의 java와 JAVA_HOME이 다른 JDK를 가리키면 wrapper는 JAVA_HOME을 우선할 수 있으므로 `--version`을 확인한다. Linux/CI는 `bash gradlew --no-daemon build`를 사용한다.

## API 경계

- 기본 프로필: `GET /actuator/health` 외 모두403, 실제 서비스 인증/권한이 구현된 상태가 아니다.
- dev 프로필: loopback에서만 `POST /api/v1/settlements/preview` 숫자 계산 제공. DB·실계좌·사용자 상태를 읽거나 쓰지 않는다.
- 0 이상 정수 원화, 안전 범위·합계 검증. 소수·문자열 강제 변환을 거부한다. 잘못된 JSON/도메인 입력400.

```json
{
  "hostId": "host",
  "rounds": [{"id":"r1","expense":25000,"attendeeIds":["a"],"cancellations":[]}],
  "receipts": [{"id":"p1","userId":"a","amount":30000,"confirmed":true}],
  "refunds": []
}
```

위 예제의 a 환불은5,000원이다. `cancellations[].received`는 실제 확인한 취소 비용 충당액이며 원래 선납액 전체가 아니다. 해당 사용자의 확인 입금 합계를 넘어 여러 차수에 중복 충당할 수 없다.

후속: 금액 원장·정산 상태(이슈13), WebSocket/STOMP·Quartz·S3/FCM. 현재 패키지에 없는 기능을 연결 완료로 취급하지 않는다.

Gradle Wrapper 9.8.2와 SHA-256 배포 검증값을 저장소에 고정한다. `build`는 테스트와 실행 JAR(`build/libs/server-0.0.1-SNAPSHOT.jar`) 생성을 수행한다. Java toolchain도25로 지정한다.

## PostgreSQL 계정·모임·참가 API

`db` 프로필에서만 활성화한다. 기본/dev는 DB 없이 계산 테스트가 가능하다. DB는 Flyway 마이그레이션 후 Hibernate validate로 검사하며 자동 스키마 수정·데이터 삭제를 하지 않는다. 테스트는 Docker가 필요하고 Testcontainers PostgreSQL17을 실제로 실행한다. Docker 부재를 통과/생략으로 처리하지 않는다.

```powershell
# apps/api에서 실행. 로컬 전용 DB 암호를 환경 변수로 설정한다.
$env:DB_PASSWORD = 'choose-a-local-password'
docker compose up -d
$env:DB_URL = 'jdbc:postgresql://127.0.0.1:15432/moishow'
$env:DB_USER = 'moishow'
.\gradlew.bat bootRun '--args=--spring.profiles.active=db --server.port=18080'
```

프로필 db+dev를 함께 켜면 숫자 미리보기 API도 사용 가능하다. 운영에서는 dev를 켜지 않는다. 기본 바인딩은127.0.0.1이며 TLS/외부 접근은 별도 배포 설정이 필요하다. Compose 종료는 `docker compose stop`, 데이터 보존 볼륨을 임의 삭제하지 않는다.

소셜: `AUTH_GOOGLE_CLIENT_ID`, `AUTH_APPLE_CLIENT_ID`, `AUTH_KAKAO_APP_ID` 중 연결할 공급자 설정. Google/Apple은 서버 challenge nonce를 공급자 로그인 요청에 그대로 넣은 ID token, Kakao는 해당 앱의 access token을 제출한다. nonce/JWK/issuer/audience/만료 또는 token-info 앱ID를 서버가 확인한다. 클라이언트가 보낸 subject/전화번호로 로그인시키지 않는다.

SMS: `SOLAPI_API_KEY`, `SOLAPI_API_SECRET`, `SOLAPI_FROM` 설정. 초기 발송은 한국 휴대전화 `+8210XXXXXXXX`만 지원한다. 제한 세션만 요청 가능, OTP는응답/로그에 반환하지 않는다. 자격 미설정은503. 어댑터를 구현하고 테스트 대역의 가입 흐름·미설정 시 거부를 확인했으며 **실제 공급자 계정·키·문자 수신을 연결 검증하지 않았다.**

[엔드포인트·권한·버전·재시도 계약](../../docs/implementation/IDENTITY-API.md)을 따른다. 세션·OTP·초대·Idempotency 원장 보관/정리와 전면적인 서비스·IP 단위 rate limit은 공개 배포 전에 운영 정책을 추가해야 한다.
