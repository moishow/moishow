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

- 기본 프로필: `GET /actuator/health` 외 모두403. 실제 DB 서비스는 `db` 프로필에서만 활성화한다.
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

db 프로필은 납부·지출 출처·선지출·정정·이의, 실제 인계·적립금·해산, WebSocket/STOMP, Quartz/outbox, 비공개 파일 프록시와 FCM 어댑터를 포함한다. 공급자 실접속·실단말 검증은 별도로 관리한다.

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


## 통합 계약과 외부 연결

최신 [요구 대조](../../docs/implementation/REQUIREMENTS-AUDIT.md), [금융](../../docs/implementation/FINANCE-API.md), [인계·적립](../../docs/implementation/RESERVE-API.md), [운영](../../docs/implementation/PLATFORM-API.md), [채팅·홈](../../docs/implementation/COMMUNITY-API.md), [파일](../../docs/implementation/FILES-API.md), [계좌](../../docs/implementation/BANK-ACCOUNT-API.md)를 따른다. 최신 전체 build는 실제 PostgreSQL17 회귀를 포함한196개 통과·실패/오류/skip0이다(codef-full-build-01). Flyway V1~V12 이후 Hibernate validate를 사용한다.

`db`의 서비스 세션은 소셜 토큰 검증 및 신규 SMS 가입 후 발급한다. 각 요청의 현재 DB 권한을 확인한다. 테스트 대역·역할 seed·MobileScenarioHost는 test 소스에만 있고 실행 JAR에 포함하지 않는다. 입력 UUID나 클라이언트 역할로 인증하지 않는다.

S3 파일 읽기는 bearer 인증 프록시를 거치고 현재 관계/정확 사건 권한을 검사한다. 클라이언트에 장기 공개 URL을 만들지 않는다. FCM HTTP v1 성공은 공급자 접수이며 실제 단말 도착을 가장하지 않는다. 계좌는 BANK_DATA_KEY_BASE64의 별도32바이트 키로 보호한다. CODEF 예금주+1원 코드 인증 어댑터와 일회 증명을 구현했으며 기본 CODEF_MODE=DISABLED다. 미설정은 인증을 거부한다. 실제 상품 계약·운영 키·은행별 기관코드·실계좌 수락은 별도다.


## CODEF 계좌 인증

해찬 문서의 CODEF 예금주명+1원 인증을 [별도 계약](../../docs/implementation/BANK-VERIFICATION.md)으로 대조해 issue/3-codef-bank-verification에서 구현했다. 가입은 소셜+SMS 그대로다. 실제 계약/상품승인·실계좌1원 인증은 아래 설정만으로 검증됐다고 표시하지 않는다.

| 환경 변수 | 역할 |
|---|---|
| CODEF_MODE | 기본 DISABLED. DEMO/PRODUCTION 분리; DEMO 랜덤 데이터는 실계좌 인증에 사용 금지 |
| CODEF_CLIENT_ID / CODEF_CLIENT_SECRET | 서버 전용 OAuth 자격, 앱/저장소/로그에 게시 금지 |
| CODEF_BANKS_JSON | 기본빈배열. 두 상품의 실제 지원 기관코드를 각각 확인한 은행만 설정 |
| BANK_DATA_KEY_BASE64 | 별도32바이트 키. 기존 계좌 AES-GCM과 인증코드/요청 지문 HMAC. 키 분실/교체는 별도 마이그레이션 필요 |

은행 설정 형식은 `[{"id":"server-stable-bank-id","name":"은행 표시명","holderOrganization":"확인된 예금주 기관코드","transferOrganization":"확인된 1원 기관코드"}]`다. 이 예시는 유효한 코드가 아니므로 그대로 사용하지 않는다. 임의 숫자 패딩이나 클라이언트가 보낸 기관코드로 호출하지 않는다. 공식 문서의 기관표가 과거 시점일 수 있어 현재 콘솔/계약을 다시 확인한다.

1원 전송 요청이 결과불명/timeout이면 같은 키로 상태를 확인하고 자동 재전송하지 않는다. 운영자는 CODEF 추적 결과를 확인하되 provider trace를 회비 입출금 거래근거로 바꾸지 않는다. 계좌 인증 완료는 실제 회비/환불 송금과 구분한다. 운영 사실을 직접 확인하지 않은 상태에서 DB 인증상태를 수동 VERIFIED로 바꾸는 복구 절차는 제공하지 않는다.
