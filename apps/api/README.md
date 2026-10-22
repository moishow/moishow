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

후속: PostgreSQL/JPA/Flyway·OAuth/SMS·WebSocket/STOMP·Quartz·S3/FCM. 현재 패키지에 없는 기능을 연결 완료로 취급하지 않는다.

Gradle Wrapper 9.8.2와 SHA-256 배포 검증값을 저장소에 고정한다. `build`는 테스트와 실행 JAR(`build/libs/server-0.0.1-SNAPSHOT.jar`) 생성을 수행한다. Java toolchain도25로 지정한다.
