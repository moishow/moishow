# 모이쇼 Flutter 앱

홈·피드·중앙 만들기·채팅·마이에서 모임·차수 참가와 외부 송금 정산을 처리한다. [정책 정본](../../docs/product/POLICY.md), [화면별 구현·검증 범위](../../docs/implementation/MOBILE-APP.md), [서버 실행](../api/README.md)을 먼저 확인한다.

## 실행·검증

기준 Flutter3.47.7/Dart3.13.5, Android 빌드 JDK21이다. 서버는 별도 Java25/Gradle을 사용한다. 이 폴더에서 실행한다.

```sh
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=https://your-configured-api.example/api/v1
flutter build web --dart-define=API_BASE_URL=https://your-configured-api.example/api/v1
flutter build apk --debug --dart-define=API_BASE_URL=https://your-configured-api.example/api/v1
```

위 URL은 예시이며 실제 배포된 API가 아니다. 소셜/SMS·은행·푸시·파일의 서버 설정과 공개 client 설정을 맞춰야 한다. 공급자 비밀키는 dart-define이나 앱에 넣지 않는다. 실제 운영 배포·스토어 서명·iOS 빌드/기기 수락은 별도로 검증한다.

## 계좌 인증

해찬의 CODEF 설계대로 예금주 확인 → 1원 요청 → 은행 앱 코드 입력 → 최종 계좌 등록을 나눈다. [API 계약](../../docs/implementation/BANK-VERIFICATION.md). 개인 계좌·적립금 계좌·새 보관 담당자 계좌가 공통 절차를 쓴다. 가입 소셜+SMS와 별개이며 회비·환불 송금 성공을 뜻하지 않는다.

생년월일/인증번호는 인증창 메모리에서만 사용한다. 응답 유실 시 같은 키로 재시도하거나 기존 인증 상태를 조회하고 자동 새1원 요청을 하지 않는다. 창을 닫은 뒤 VERIFIED 증명을 재사용하려면 마스킹된 은행을 확인하고 원번호·예금주를 다시 입력한다. 최종 등록409가 발생하면 기존 계좌가 유지되며 최신 version과 미소비 인증을 확인한다. 공급자가 준비되지 않으면 미연결을 안내한다. 데모 랜덤 응답으로 승인하지 않는다.

## 로컬 시나리오 전용

`test_support/main.dart`와 서버 test source `MobileScenarioHost`만 TEST 역할 선택·가상 공급자를 제공한다. 정상 `lib/main.dart`나 운영 JAR에 로그인 우회/seed가 들어가지 않는다. 실제 PostgreSQL/REST를 사용하지만 실제 은행/문자/푸시 검증은 아니다.

```sh
flutter build web -t test_support/main.dart --output build/test_web
```

테스트 서버는 localhost18080, preview8766의 `/__scenario/manifest`를 통해 gitignored 세션 manifest를 제공해야 한다. 단순 정적 production web 서버와 구분한다. manifest의 토큰을 로그·Git·공개 웹에 게시하지 않는다. 가상 CODEF 은행은 `TEST 가상은행`, 예금주는 `테스트예금주`, 공개 테스트 코드는 `4837`이다. 실제 코드 수신/1원 송금은 발생하지 않으며 production 인증 수명/권한/증명 소비 로직은 그대로 실행한다.

`test_support/seed_finance.py --manifest <gitignored-loopback-manifest>`는 같은 TEST 환경을 검사한 뒤 실제 REST 명령으로 금융 시나리오를 준비한다. 계좌도 시작→코드→등록 순서를 사용하며 결과불명 요청을 자동 재전송하지 않는다. 예금주/코드 값은 개인 정보가 아닌 명시적 가상 fixture다.
