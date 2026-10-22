# Flutter 앱 — issue 16

소스는 `apps/mobile`, 제품 기준은 POLICY.md와 screen_v1다. Flutter/Riverpod/go_router/Dio, REST 쓰기와 STOMP 읽기 알림을 사용한다. 화면 토큰은 design/system/tokens.css에서 native ThemeData로 매핑했다. `review/`는 열람하지 않는다.

## 실행

Windows SDK: `C:\Users\minjoun\Documents\Codex\tools\flutter` (저장소 외부).
공식 안정 Flutter 3.47.7 / Dart 3.13.5. 공식 releases_windows.json이 지정한 archive의 SHA256 `c2c875da25a1a1448d18ee4e8f398b2f6fce888b4775d8f9130538e16d826cb4`와 다운로드 파일을 대조했다.

```powershell
$flutter = 'C:\Users\minjoun\Documents\Codex\tools\flutter\bin\flutter.bat'
cd apps/mobile
& $flutter pub get
& $flutter analyze
& $flutter test
& $flutter build web --dart-define=API_BASE_URL=https://api.example.com/api/v1
& $flutter build apk --debug --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

Android emulator의 개발 서버는 `http://10.0.2.2:8080/api/v1`, 브라우저는 localhost를 사용한다. 운영 환경은 HTTPS와 서버 Origin 허용 설정이 필요하다. debug 서명 APK는 스토어 배포 산출물이 아니다.

소셜 공급자 설정은 `GOOGLE_SERVER_CLIENT_ID`, `GOOGLE_IOS_CLIENT_ID`, `KAKAO_NATIVE_APP_KEY`의 dart-define 및 각 공급자 콘솔의 package/bundle ID·인증서·URL scheme으로 구성한다. Apple에는 Sign in with Apple entitlement/서버 audience 설정이 필요하다. 이 공개 client ID와 별도로 서버의 검증키/SMS 자격을 준비한다. 비밀키를 앱 dart-define에 넣지 않는다.

## 구현 경계

- 홈의 정산 할 일·날짜 선택·다가오는 일정, 탐색 검색, 소속 모임, 소개·가입·승인 검토·부원 관리, 공통 이벤트 작성·차수 신청/대기/마감 후 합류/취소를 REST 계약으로 연결한다.
- 납부 신고/부분 실입금 확인/반려, 차수 회비 요청, 증빙 선택 지출, 서버 계산 순차액, 최초 등록/계산 마감, 원본 보존 정정, 외부 환불 기록/수령 확인, 이의·대리 처리 요청을 분리한다. 금융 쓰기는 서버 응답 후 조회하며 낙관적으로 완납/송금 완료를 표시하지 않는다.
- 인계 수락·송금 기록·실제 수령 확인, 적립금 계좌·출처/사용 내역·입출금 확인·모임장 귀속 정리·해산, 프로필/과거 정산/알림/푸시 설정/계정 삭제를 서버에 요청한다.
- 채팅방은 종류·최근 메시지를 표시하고 메시지는 REST 저장 결과를 다시 조회한다. STOMP 재연결 후 누락을 REST로 다시 읽는다. 연결 오류를 성공으로 표시하지 않는다. 채팅은 서버의 확정 참가/차단 접근 경계를 따른다.
- opaque service session은 flutter_secure_storage에 저장한다. ONBOARDING은 SMS/가입 화면만, ACTIVE만 앱으로 진입하며 401은 저장 토큰을 삭제한다. 실제 외부 인증 없이 활성 세션을 생성하지 않는다.
- 한 번 제출한 업무 Command는 UUID 멱등키와 본문을 고정하여 네트워크 재시도에 재사용한다. 409는 최신 자료 조회 후 폼을 다시 작성하게 한다. 금액은 원 단위 정수/0..9007199254740991 범위, 정정은 부호 정수를 검사한다.
- Google은 공식 native SDK의 요청별 nonce를 MethodChannel로 전달하여 매 로그인 시도마다 새 서버 challenge를 사용한다. Flutter wrapper의 초기화 전용 nonce를 반복 초기화하지 않는다.

## 검증 기록과 외부 수락 조건

검증: 현재 작성 소스 `flutter analyze` 오류·경고 없음, `flutter test` 10개 통과. 테스트는 원화 경계, 네트워크 재시도의 동일 멱등키/본문, 409 충돌, 세션 보관/만료/401 제거, Google 요청별 새 nonce, 금융 폼의 실패 후 미확정·재시도, 제한 세션 화면 격리를 검사한다. 실제 서버와 모바일을 함께 실행한 E2E는 아니다.

`flutter build web` release는 306초 후 성공했다. 이 빌드 뒤 추가한 피드·인수함·일부 금융/설정 UI는 아직 release 재빌드하지 않았다. 따라서 기존 웹 빌드 성공을 현재 최종 소스 전체의 빌드 증거로 쓰지 않는다. 기존 빌드는 IAB에서 로그인 화면/접근성 트리/미지원 인증 클릭을 확인했고 console error/warn은 0건이었다. 캡처: `apps/mobile/docs/screenshots/web-login-unavailable.png`.

Android SDK platform36/build-tools36.0.0을 설치하고 debug APK 빌드를 시작했다. 서버 검증 작업과 CPU 경합으로 자신의 빌드만 취소했다. 아직 APK 성공/실패 결과가 없다. 재실행 설정은 workers2·parallelfalse·heap2048m이다. iOS native 코드는 Windows에서 컴파일하지 않았다.

실계정 소셜·SMS 수신/재전송·중복 번호, 실제 입금/부분 입금/환불·0원 인계, FCM/APNs 수신·백그라운드, 실기기 Android/iOS·접근성·스토어 서명 검증은 외부 자격과 사용자 확인이 필요하다. 공급자 미설정/서버 API 미제공은 오류 상태로 노출하며 QA 완료로 간주하지 않는다. iOS 빌드는 Windows에서 실행할 수 없으므로 macOS/Xcode에서 검증해야 한다.

51개 카탈로그의 구분은 상태와 업무 흐름으로 재사용하며 51개 정적 placeholder를 생성하지 않는다. 관리자 운영 대시보드는 별도 apps/admin 소유다. 아직 서버에 없는 기능은 API 완료·통합 수락 전까지 구현 완료로 묶지 않는다.

## 2026-10-22 요구사항 대조 감사 — 구현 완료 판정 아님

비교 근거: 실제 GitHub 이슈16 본문, POLICY P01–P13, STATE-MODEL, ROADMAP, docs/screens.md의 51개 ID, screen-catalog.json, IDENTITY/FINANCE/PLATFORM/COMMUNITY 실제 계약 및 ReserveController/ReserveService. `review/`는 읽지 않았다. 사용자 지시에 따라 기능 추가를 중단하고 이 감사를 먼저 기록했다.

판정: **이슈16 미완료**. 공통 Form/Remote/List 기반의 실제 API 연결은 있으나 화면마다의 인수 기준·디자인 재현·전체 상태 검증을 완료한 것은 아니다. ‘부분’은 코드가 존재한다는 의미이며 서버 통합·접근성·실기기 인수까지 통과했다는 의미가 아니다.

| ID | 현재 코드·연결 | 실제 부족/미검증 |
|---|---|---|
| LOGIN | native Google nonce bridge, Apple/Kakao SDK, 서비스 세션 교환 | native 빌드/실계정 미검증. Apple Android callback/options 미구현. 공급자 구성 누락 안내는 있음 |
| SMS | E.164·6자리 입력, 발송/재발송·검증 REST | 실제 수신 미검증. 재발송 카운트다운/TTL 표시 없음. 중복 번호별 기존 로그인 복귀 UX 부족 |
| ONBOARD | SMS 성공 뒤 서비스 닉네임 필수·register | 관심사 입력·설정 없음. 프로필 첫 설정은 SMS 화면에 통합 |
| HOME | tasks/upcoming REST·알림 벨·날짜 선택 | 최근 backend와 실통합 안 됨. +는 모임 목록으로 이동하며 직접 공통 작성 화면이 아님 |
| TODO | 홈 task title/kind/eventId 목록→동일 finance | 상태별 필터·세부 마감/미납/환불 이력 카드 없음. 전역 진행업무 상세 없음 |
| SCHEDULE | 홈 날짜 선택·upcoming 로컬 날짜 필터 | 선택 날짜 빈 결과 안내·취소된 일정 표현·모든 달력 상태 부족 |
| EXPLORE | 이름 검색/소개 진입·개인 피드 | 위치/분류 필터·공개 번개 탐색 카드 없음. 내부정보 숨김은 서버 위임, 모바일 E2E 미검증 |
| CREATE | 모임 상세 공통 CommandForm, 종류/공개/정산 방식/시간 | 홈에서 바로 선택 불가. 차수는 생성 뒤 별도 추가. 실제 datetime picker 대신 ISO 문자열. 서버 기본 POSTPAY 자율 채택 |
| CLUB_CREATE | 이름·즉시/승인제 REST | 소개·지역·이미지·개설자 모임별 닉네임 선택 없음. 중복 이름 별도 UX 없음 |
| CLUB_PREVIEW | name/joinMode/내 관계 조회 | 소개 본문·인원/역할 요약 없음. preview와 club 화면 통합 |
| CLUB | 이벤트·부원·권한별 일부 버튼·적립금·같은 방·게시판 | 공지/탭 구성 없음. 초대 생성 UI 없음. role/action 권한 일부는 서버403에 맡김 |
| JOIN | 모임별 닉네임/초대 토큰·version 쓰기 | 승인 대기 표시. 강퇴/블랙 우선순위의 앱 E2E 미검증 |
| JOIN_REVIEW | pending 목록·승인 버튼 | 거절·처리 이력 화면 없음. API 거절 계약도 현재 문서에 없음 |
| EVENT | event/rounds/access/참가목록 REST·정산/같은 방 진입 | GET event 날짜/주최 정보 부족. 명확한 날짜/장소 상세와 공개정보별 화면 미완 |
| ROUND | 정원/마감/고지 취소비·참여 POST | 의미 있는 차수 이름 대신 정원 표시. 참가 동의 버전 표시 없음 |
| WAITLIST | 내 participation의 WAITLISTED 상태 문자열 | 전용 대기 안내·순서/상태별 UX 없음. 상태 enum이 그대로 노출됨 |
| JOIN_LATE | 같은 참여 POST→LATE_REQUESTED, 담당 승인 | 요청 메모·거절 UI 없음. 승인 직후 해당자 요청 생성 모바일 통합 미검증 |
| ATTENDANCE | 참가 목록은 조회 | 참석/노쇼 기록 UI/API 연결 **없음** |
| PAY | 본인 잔여액 신고·외부 송금 설명·계좌 조회 경로 요청 | finance transfer-instructions는 아직 backend 확정 전 요청 경로. 실제 수취 계좌/예금주 검증 통합 안 됨 |
| PAY_PENDING | pending report/status·신고액/실확인액 구분 | 실제 입금시각/반려 이력/처리 대기 시각 표시 부족 |
| COLLECT | 담당 실제금액/시각(미확인 null)/반려 REST | 선택 UI 일부는 이미 처리된 신고에도 노출돼 서버409. 첨부 원본 실제 열람 없음 |
| CANCEL | 본인 차수 취소·고지비 재안내 | 주최자 차수 취소/날짜 변경/재참여 의사 확인 UI **없음**. 취소 후 금액 결과 안내 부족 |
| CONSENT | 없음 | 취소비 변경 제안·재동의·거부 무료취소·미응답 유지 UI **없음** |
| EXPENSE | 차수ID/항목/원화/선택 evidence 문자열 REST | 차수 선택기가 아닌 UUID 직접입력. 실제 파일 선택/업로드/비공개 증빙 열람 **없음** |
| SETTLE | 서버 positions 순차액·기입금/기환불·최초등록 | 차수별 식/취소비 수령/호스트 부담/총액 보존을 설명하는 상세 UI 부족. 금액보존 서버테스트에만 위임 |
| REFUND | 담당 외부환불 SENT 기록·본인 confirm REST | 실제 이체·수령 검증 미검증. 불필요한 타인 confirm 버튼도 노출 가능. 환불계좌/상세 지급 이력 UX 부족 |
| CLOSED | close·후속 동일 요청 접근 | 원본 잠금 의미는 설명하나 원본/후속/정정 상세 타임라인 미완 |
| CORRECTION | 사용자별 signed adjustment·사유 append | 사용자 UUID 직접입력, 합계0/중복사용자는 서버 검증. round expense delta 계약 UI 없음. revision snapshot/영향자 내역 미표시 |
| DISPUTE | reason/evidence 문자열·이의 등록 | 실제 첨부 업로드/민감 증빙 뷰어 없음. 최근 dedicated private dispute GET 미연결 |
| DISPUTE_REVIEW | resolve/withdraw + support escalation 요청 | assigned case handler의 개별 이의 상세→정정/처리 연결 **없음**. 처리자 결정 UI 분기 부족 |
| HANDOVER | 이벤트 proposal/list·설정의 /me/handovers 수락/송금/0원포함확인 | nominee UUID 직접입력. 전체 native/REST E2E 미검증. 일부 event 목록 메뉴는 상태·actor별로 덜 제한됨 |
| RESERVE | balance/entries/계좌/출처·목적·실입출금 | provider 없는 초기 계좌는503. 잔액/담당 닉네임 실제 DTO 대조 진행. 권한별 UI 일부 서버 위임 |
| RESERVE_ADD | deposit/sent/confirm REST·계좌 지침 확장 | 출처 event UUID 수동입력. 모든 상태별 메뉴 필터 부족. 실제 송금 미검증 |
| RESERVE_USE | spend/execute REST·보관담당 인계 제안 | request만 차감하지 않음. 취소/reversal UI 없음. 내역 필터/진행 설명 부족 |
| DISSOLVE | payout/실출금/dissolve 폼·의무유지 설명 | reserve 없는 모임 GET404이면 해산 진입 미완. 귀속확인 bool은 안내 후 제출하며 실제 확인 UI 분리 부족 |
| MY | 프로필·지난 정산·설정 | 모임 레벨은 현재 club 상세에만 있음(P11 배치 미충족). 현재 돈액션/일정 중복은 없음 |
| HISTORY | /me/history→같은 finance | 개인 단면·날짜/금액 요약 필터 없음. server history 통합 미검증 |
| LEVEL | club 상세에서 본인 점수/history REST | 마이에서 모임별 레벨 진입 없음. 이력 라벨 일부 enum, 판정 근거 상세 부족 |
| PROFILE | 서비스 nickname/version POST | 소개/이미지·모임별 nickname 수정 없음. 모든 과거 화면 현재 nickname 갱신 E2E 미검증 |
| SETTINGS | 푸시 전체 off/inbox 유지 안내·인수함/로그아웃/삭제 | 종류별 개별 설정 없음(전체 off 가능). FCM/APNs SDK·토큰 등록·알림 클릭 처리 코드 **없음** |
| BANK | reserve 보관계좌 폼만 있음 | **개인 계좌 등록/예금주 검증 화면/API 연결 없음**. 키 없는 것과 별개로 앱 기능 미구현 |
| ACCOUNT | /me/delete server 거부/완료·담당인수함 | 로그인 방식/전화번호 변경·계정 복구 UI/API 연결 없음. 실제 인계/삭제 E2E 미검증 |
| NOTIFICATIONS | inbox/read/event link | 앱 푸시 deeplink/만료 폴백 없음. body별 링크는 모든 eventId를 finance로 통일한 자율 단순화 |
| CHAT | unified rooms/kind/lastMessage·DM pending 수락 | 정렬 서버 위임. 요청 거절/철회·검색·차단관리 UI 없음. STOMP 실제 backend handshake 미검증 |
| CHAT_ROOM | REST 저장·sequence cursor 재조회·STOMP 재연결 | cursor200회복 코드가 있음. 전체 이력 메모리 로드로 페이지 UX 없음. 수신/전송·차단/권한취소 E2E 미검증 |
| FEED | personal/club feed·block/follow POST | 반응·모집 카드·언팔로우/차단해제 관리 없음. 조회 query 및 backend 실통합 미검증 |
| POST | bottom sheet 상세/comments·신고 | 작성자 삭제/만료 상태 UX 없음. 신고가 contentId/contentType을 보내지 않아 실제 원문 조치 연결 미완 |
| COMPOSE | personal/club body REST | 이미지/범위선택·공지권한 UI·모집카드 자동 생성 없음. 일반 폼 재사용 |
| REPORT | 유형/대상/사유·지원 case 등록 | 증빙 업로드 없음. 게시글/댓글 ID를 신고에 연결하지 못함. UUID 입력 기반 |
| MODERATION | own/assigned case 목록·사유·history·상향 | 처리자의 PROGRESS/RESOLVE/조치 제출 UI **없음**. 별도 admin 웹으로 위임은 이슈16 앱 인수를 자동 충족하지 않음 |
| OPS | mobile에 없음 | apps/admin의 별도 소유. 51개 카탈로그의 모바일 범위 제외 여부는 사용자 결정 필요 |

### 자율 판단·충돌·기존 이탈 목록

10개 흐름(`docs/wireframe.html`)의 연결 판정:

| 흐름 | 현재 끊기는 지점 |
|---|---|
| F01 가입과 모임 | 소셜·SMS 실제 공급자 미검증; 관심사/풍부한 모임 소개 없음. API 폼 연결만 존재 |
| F02 차수 신청과 납부 | 실제 수취계좌 지침 계약 미완; 미납/대기/실확인 상세 UX 및 실계좌·모바일 E2E 없음 |
| F03 마감 후 합류 | 요청·승인 코드는 있으나 거절/상태별 안내와 승인→본인 회비 생성 통합 미검증 |
| F04 취소와 조건 변경 | CONSENT·주최자취소·일정 변경 재의사 확인 미구현으로 전체 흐름 미완 |
| F05 지출과 최종 합산 | ATTENDANCE 미구현, 지출 파일 증빙 없음, 차수별 근거 상세 부족 |
| F06 마감 후 이의·정정 | 민감증빙 업로드/열람·assigned handler 상세 연결·원본/정정 비교 미완 |
| F07 실제 인계와 계정 종료 | 제안/수락/0원확인/삭제 요청 코드, 실제 금액 인계·권한이전 E2E 미검증. 계정복구 없음 |
| F08 적립금과 해산 | 보관 계좌 provider503; 무계좌 해산 진입·취소/reversal UI 없음. 실입출금 미검증 |
| F09 소셜과 안전 | 피드/댓글/신고 존재, content 원문 연결·mobile moderation/OPS 미완 |
| F10 개인 기록과 알림 | 마이 레벨 배치·푸시/딥링크 미구현, 소켓 서버 통합·기기 수신 미검증 |

어느 흐름도 현재 ‘실제 공급자/실기기까지 전체 완료’로 체크하지 않는다. 아래 판단 중 새로 기능을 줄이거나 계획을 대체하려는 사항은 사용자 승인 전 완료 범위로 간주하지 않는다.

| 판단 | 현재 처리 | 감사 판정/후속 |
|---|---|---|
| 화면 수 대신 재사용 | 15개 route와 공통 Form/Remote, 여러 상태를 한 finance/club에 통합 | 기능별 상태 인수를 충족하면 가능하나 현재 51개 완료로 말할 근거 없음. 카탈로그/PNG 일치 검증 안 함 |
| 생성 기본값 | LIGHTNING·비공개·POSTPAY를 첫 선택값, 차수비0 | POSTPAY는 서버 호환 기본값; 사용자가 기본 정산 방식을 승인한 것은 아님. 생성시 명시 선택·저장 확인 필요 |
| 정산 open | event 생성과 별개로 /finance/open 수동 버튼·mode 재선택 | 생성때 선택한 mode와 불일치 가능409. 저장 모드로 일관화할 필요 |
| 내비게이션 | 홈+→모임목록→모임의 공통 생성폼, 레벨은 모임상세 | P11의 홈+ 공통 작성 진입/마이 레벨 배치와 차이. 수정 대상 |
| 디자인 native 매핑 | 소수 tokens를 ThemeData로 수동 매핑, Material 아이콘·시스템 폰트·최대폭640 | fromSeed 파생색/폰트/아이콘/레이아웃이 원토큰과 완전히 일치하지 않음. 420폭·51화면의 visual QA 미충족. 금액 헤드라인 tabular 숫자도 일괄 보장 못함 |
| 일반 ID 폼 | 차수/환불/정정/인계 후보를 UUID 문자열 입력 | 동작 가능한 API 폼이지만 일반 사용자가 수행할 수 있는 최종 UX 아님. 현재 nickname 기반 선택기로 바꿔야 함 |
| 증빙 | 문자열 reference만 선택 필드 | ‘선택 증빙’ 정책을 파일 연동 완료로 해석하면 안 됨. 파일선택·업로드·짧은 URL·민감뷰어 전부 미구현 |
| 금융 확정 | 성공 POST 뒤 재조회, 납부신고만으로 완납 안 함, 금액계산은 서버 | 현재 바른 경계. 실송금/수령은 사용자의 주장 기록이며 실제 계좌 검증 성공을 앱이 만들지 않음 |
| 버전409 | 폼 차단→원 리소스 조회→닫고 새 작성, 원본 덮어쓰기 안 함 | 현 폼 테스트 통과. 여러 nested Remote/입력 결과의 전체 E2E 없음 |
| 재시도 | 동일 열린 폼의 Command key/body 고정. transport실패 후 입력 잠금 | 재시도 단위는 **메모리상 열린 폼**뿐. 폼 닫기/앱 재시작 이후 pending key/결과 복구 저장 없음. shallow map freeze이며 nested List는 완전한 deep freeze 아님 |
| 오프라인 | 오류/수동 재시도, 낙관 금융 갱신 없음 | offline draft/outbox/resume/읽기 캐시·연결복구 UX 없음. 네트워크 끊김 인수의 일부만 검사 |
| 데이터 모델 | Map/List dynamic decode, null numeric은0 표시 | malformed contract를 빈목록/0으로 잘못 표시할 위험. typed DTO/필수값 검증 미완 |
| Google nonce | Flutter wrapper initialize-once 한계를 피하려 native MethodChannel 양 플랫폼 작성 | 매 시도 nonce 교체 unit test 통과. native bridge 컴파일/실인증 미검증. 재시작 요구 초안은 제거함 |
| Apple Android | plugin을 iOS native 방식으로 호출 | Android web auth options/callback이 없으므로 기능 미구현. 단순 provider키 미확인으로 분류하면 안 됨 |
| 공급자 키 구성 | dart-define와 native scheme/provisioning 의존 | Google/Kakao/Apple 실제 콘솔·서명키·URL 설정 없음. Kakao는 Gradle/native 변수와 dart-define을 함께 설정해야 하며 자동 일치 검사 없음 |
| 세션 | secure storage·onboarding/active route gate·401제거 | 메모리 시간경과를 깨우는 타이머/서버 세션 선검증 없음. 저장소 복호화 실패 시 복구 UX 없음 |
| 채팅 수신 | REST write+STOMP read, reconnect5초·cursor 순차회복 | protocol 일치. backoff/jitter·백그라운드복귀·재연결 auth/권한변경·실소켓 검증 안 됨 |
| 권한 UX | 중대한 권한은 항상 서버 확인 | 일부 불가능한 UI 메뉴를 보이고403/409 처리. 서버 보안이 있어도 역할별 화면 인수와 동일하지 않음 |
| 푸시 | preference REST만 | FCM/APNs는 공급자 키만 없는 것이 아니라 모바일 SDK/토큰/메시지 핸들러 코드도 없음 |
| 공개/탈퇴/차단 | 서버 DTO 권한과 nickname map 재사용 | 권한 보존/민감증빙/블랙 우선순위 mobile E2E 미검증. UI 신고→content 원문 연결 누락 있음 |
| 관리자 앱 범위 | OPS/일부 moderation을 별도 apps/admin으로 간주 | 사용자의 51개 앱 흐름에서 제외한다는 명시 승인 없음. 재판정 대상 |
| 접근성 | 기본 Material semantics, login AX 확인, 버튼 최소48 보강 | TalkBack/VoiceOver·글자 확대·금액읽기·색대비·초점·오류 live-region 전체 인수 미검증 |
| 개발 순서 | 앱 소스를 먼저 쓰고 검증테스트를 추가, widget 실제 버그 확인 후 수정 | 이슈16의 실패 테스트→구현 순서를 처음부터 준수하지 못함. 지금 통과하는 테스트를 최초 TDD 증거로 소급하지 않음 |
| 검증 범위 | unit/widget10개·이전 snapshot web build/로그인브라우저 | 실제 server+mobile 통합/51화면 오류·권한·수신/AndroidAPK/iOS/실기기/공급자 수락과 구별. 완료/머지 판단 전에 차이 수정 필요 |

### 즉시 고쳐야 할 코드 차이와 외부 환경만 필요한 검증의 구별

**코드 미구현/이탈**: 위 표의 ATTENDANCE·CONSENT·일정변경·주최자취소·개인BANK·복구·파일/민감증빙·푸시SDK·moderation결정·content 신고연결·UUID선택UX·홈작성/마이레벨·재시작 멱등복구·권한/상태별 UX·정정상세·무계좌해산·디자인/접근성 보강. 이들은 공급자 키를 받는 것만으로 해결되지 않는다.

**환경 수락 미검증**: 설치된 Flutter에서 현재 소스 최종 web/APK 빌드, macOS iOS 빌드, native provider의 실자격·실기기 callback/SMS, FCM/APNs 실수신(선행 코드 구현 후), 실제 계좌 송금·부분입금·환불·0원인계, signed distribution, server+mobile 권한·재연결·네트워크 끊김 E2E. 재현 테스트/빌드가 실패하면 그 실패는 별도 코드/환경 원인으로 분류해야 한다.
