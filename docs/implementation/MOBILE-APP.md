# Flutter 앱 — issue 16 현재 대조표

정본 POLICY P01~P15, issue16, REMAINING-EXECUTION, 화면 catalog 57개/12흐름, IDENTITY/COMMUNITY/FINANCE/RESERVE/PLATFORM/FILES API를 비교한다. 초기 감사의 누락을 키 미설정으로 축소하지 않는다. 아래 ‘코드’는 원요구/실제 계약의 실행 경로가 있고 회귀가 있다는 뜻이다. 브라우저/실기기 수락은 별도 관찰 근거로 구분한다. `review/`는 열람하지 않는다.

## 실행과 검증

SDK는 저장소 밖 `C:\Users\minjoun\Documents\Codex\tools\flutter`, 공식 stable3.47.7/Dart3.13.5다. 공식 archive SHA256 `c2c875da25a1a1448d18ee4e8f398b2f6fce888b4775d8f9130538e16d826cb4`를 확인했다. Java25 서버와 Android JDK21을 구분한다. Android SDK36/build-tools36.0.0, Gradle workers2/parallelfalse/heap2048m이다.

현재 최종 코드 snapshot(표준 dart format/fix 적용): `flutter analyze` **No issues found**(10.7초), `flutter test` **86개 통과**(41초). 마지막 날짜 한국어 공통 formatter 1줄까지 포함한 TEST web126.8초·production web94.8초·Android debug APK21.1초 빌드가 모두 성공했다(`mobile-*-final-04.log`). 그룹/개인 요청 수락 뒤 최근 대화 즉시 갱신 회귀도 포함한다. iOS는 Windows에서 빌드하지 않았다. 외부 공급자·실송금·실기기 검증은 이 테스트 결과와 구분한다.

```powershell
$flutter = 'C:\Users\minjoun\Documents\Codex\tools\flutter\bin\flutter.bat'
cd apps/mobile
& $flutter pub get
& $flutter analyze
& $flutter test
& $flutter build web
& $flutter build apk --debug
```

API_BASE_URL/Google/Kakao/Firebase 공개 client 설정만 dart-define으로 전달한다. 공급자 비밀키는 앱에 넣지 않는다. iOS Apple entitlement/APNs Debug development·Release/Profile production 설정은 macOS 서명 환경에서 재검증해야 한다. 실제 은행 어댑터는 서버 기본503이며 키만 없는 상태로 축소하지 않는다.

## 57개 화면 추적

| 화면 | 실제 코드/경로 | 확보한 근거 | 남은 차이·수락 |
|---|---|---|---|
| LOGIN · 로그인 | NativeAuth Google/Kakao/Apple·공급자 오류·기존 세션 복원 | Google fresh nonce·Apple PKCE/state 단위 테스트, 작은 화면200% 로그인 회귀 | 공식 기존 공급자 복구 도움 링크 있음; 공급자 실인증/실기기 미검증 |
| SMS · 전화번호 인증 | ONBOARDING 전용 SMS 발급/확인·중복 번호 서버 차단 | 제한 세션 앱 진입 차단 회귀 | 국내010/E164 정규화·서버와 같은60초 재발급 안내 있음; 실문자 수신 미검증 |
| ONBOARD · 첫 설정 | 서비스 닉네임 가입 후 선택 관심사·소개·SELF 사진 설정/건너뛰기 | Profile REST 실PG3 부모 GREEN, 선택 정규화·명시 사진 해제 회귀 | 선택 설정 실제 가입 이어쓰기 브라우저 미검증 |
| HOME · 홈 | tasks/upcoming·공통 작성 +·날짜·알림 진입 | 공통 작성 진입 및 nullable task 경로 회귀 | 실제 역할별 홈 브라우저 검증 대기 |
| TODO · 정산 할 일 | 한국어 미납/확인대기/환불/이의/인계·적립 업무 분리·정확 자원/원본기록 진입 | nullable task 경로·실제 서버 모임장/참가자 업무 조회 | 정본에 별도 종류 필터/완료업무 전역목록 요구는 없음(부모 대조 확정). 실상태별 QA 진행 |
| SCHEDULE · 내 일정 | 주간 날짜 strip·월 달력 선택·서버 날짜조회·빈날짜 안내·이벤트 상세 차수 취소 상태 | 정본 Home hero/달력/중앙+ 및 공통작성7개 회귀 | 실제 날짜 전환 QA 진행 |
| EXPLORE · 모임 탐색 | 독립 /explore 이름/지역/분류 검색·200개 페이지 누락 회복·모임 소개 | 선택 조건 쿼리/pagination 회귀·서버 discover 정확일치 GREEN | 실제 필터/피드 관계 QA 진행 |
| CREATE · 정모·번개 만들기 | 공통 composer·명시 종류/정산 방식·복수 차수·날짜 picker | 중단 개설 재시작·고정 key/body 복구 회귀 | 모든 역할 실제 개설 브라우저 QA 대기 |
| CLUB_CREATE · 모임 만들기 | 이름/명시 가입방식·선택 소개/지역/분류·personalPOST 대표사진·실제 결과 진입 | metadata composer·서버 ClubRequest5 GREEN | 실제 이미지 picker/소개 범위 역할 QA 진행 |
| CLUB_PREVIEW · 모임 소개 | 소개/지역/분류/인원·정확 보호사진·가입 방식/내 관계 | 서버 public intro만 이미지 허용/다른개인사진403·clear접근회수 GREEN | 실제 소개/사진 역할 QA 진행 |
| CLUB · 모임 홈 | 부원/이벤트/공지·같은 방·적립금·활성 부원 레벨·닉네임·초대 생성/복사 | 해산 작성 금지·관리자 역할 제한·정확 멤버 레벨 회귀 | 실제 모임장/관리자 QA 진행 |
| JOIN · 모임 가입 | 모임별 닉네임·초대 토큰·승인 대기 | 서버 버전/멱등 명령 | 강퇴/블랙 우선순위 실제 화면 검증 대기 |
| JOIN_REVIEW · 가입 신청 검토 | 신청 메모·명시 승인/거절 사유·현재 닉네임/탈퇴표시의 비공개 이력 | 서버 ClubRequest5 및 private RequestHistory 위젯 GREEN | 실제 신청·거절·재신청 QA 진행 |
| EVENT · 정모 상세 | 일정·방식·차수·역할 access·참여/정산·동일 채팅방 | P04 위젯 회귀 | 전체 역할 접근·해산 뒤 의무 실제 검증 대기 |
| ROUND · 차수 신청 | 정원/마감·고지 비용/동의 버전·명단 | P04 위젯 회귀 | 차수별 상세 디자인 QA 대기 |
| WAITLIST · 참여 대기 | 대기 상태·미납 자동취소 아님 안내 | 서버 참가 상태 사용 | 순서 표시는 서버 계약 없음; 실제 승격 검증 대기 |
| JOIN_LATE · 마감 후 합류 | 마감 뒤 본인 합류 메모·활성 주최자 승인/거절·본인/담당자 이력 | 서버 late reject/이미확정·등록금융 우회409 및 앱 role/private이력 회귀 | 실제 합류 요청/거절 QA 진행 |
| ATTENDANCE · 참석 확인 | 실제 노쇼·등록 후 원본 보존 참석 정정·정산 인수자와 주최자 권한 분리 | 정확 참석 재분배·인수자 host변경 불허 회귀 | 실제 참석/노쇼·영향금액 QA 진행 |
| PAY · 회비 보내기 | 본인 요청별 정확 송금안내·신고·부분/초과 납부 | 동일 명령 네트워크 재시도·비낙관 완료 회귀 | 실은행 검증 어댑터 코드 미구현; 실송금 미검증 |
| PAY_PENDING · 확인 대기 | 신고액/실확인액 분리·확인대기·추가 이체 경고 | pendingVerification 계약 | 실제 신고/반려 타임라인 QA 대기 |
| COLLECT · 입금 확인 | 실금액·시각/null·거래근거·허용 차수별 귀속·보호 증빙 | 개별 allowedAllocationKindsByRound/HOST_CONTRIBUTION·실금액 정정 회귀 | 실입금 공급자 자동 검증 없음(사람의 실제 사실 기록) |
| CANCEL · 참여 취소 | 본인 취소·주최자 차수 취소·일정변경 | P04 비용 동의/거부 무료취소 회귀 | 등록 후 변경 금액과 거부 상태 전체 E2E 대기 |
| CONSENT · 변경 동의 | 비용/일정 재동의·거부 무료취소·미응답 참여 유지·동의 이력 | 실제 P04 위젯 회귀 | 개별 상태 브라우저 검증 대기 |
| EXPENSE · 지출 입력 | 차수/항목/원화·사진·개인/수금 명시 자금 배분·혼합 지급자 | 명시 자금 출처/합계 회귀·실제 multipart API | 이미지 선택 native/보호 PDF 렌더 QA 대기 |
| SETTLE · 이벤트 최종 정산 | 차수별 계산 근거·실제 입금/개인지출/일반환불/선지출 분리·최초기한 | 서버 canonical funding DTO | 참석0명/혼합 차수 실제 브라우저 QA 대기 |
| REFUND · 환불 확인 | REQUESTED→실제 SENT→수령자 CONFIRMED·정확 수령 계좌 | 역할/상태 분리·실제 API | 실이체·수령 미검증 |
| CLOSED · 계산 마감 | 계산 마감 뒤 기존 의무/후속입금/이의 유지·불변 원본 전후 비교 | RevisionComparison7 GREEN·정확6금액/부호/누락/320폭200% 검증 | 실제 원본 비교·미완 업무 QA 진행 |
| CORRECTION · 정정 기록 | 부호 지출/혼합 자금·0합 조정·입금/시각·참석 정정·0원 명시 빈배분·전후 비교 | 0원 receipt/expense+양수 빈배분 차단·HOST 귀속·비교7 회귀 | 실제 정정 후 자기 금액/원본 QA 진행 |
| DISPUTE · 이의 제기 | 사유·multipart 보호 사진·본인 이의·정확 사건 상세 | 실제 private GET/flags | 실제 민감 사진 역할별 접근 브라우저 검증 대기 |
| DISPUTE_REVIEW · 이의 처리 | 검토·인정/반려/철회·공개결과·관련 정정 원본 선택·대리/상향 | 연결할 정정 기록 위젯 회귀 | 실제 담당자 배정·금액영향 E2E 대기 |
| HANDOVER · 정산 인계 | 정확 적격후보·원/최신 명세·수락/실송금/0원포함수령·건별 수령계좌 | stale 수령/명세변경 보존·수령계좌경로 회귀·서버 Reserve23 GREEN | 실제 재수락/반환 UI QA 진행·실송금 미검증 |
| RESERVE · 모임 적립금 | 잔액/가용/부족·목적/담당/시각·정확 flag 액션 | 역할/부족 중 별도 실제거래 회귀 | 실은행 어댑터 코드 미구현 |
| RESERVE_ADD · 적립 입금 확인 | 현 담당 narrow context·보관자명·자기 event deposit 목록/flag·제안→실송금→실수령·정확 계좌 | 실제 서버 Reserve23 GREEN·탈퇴 담당자가 전체원장 없이 첫/후속업무 처리 회귀 | 실제 적립 업무 QA 진행·실은행 공급자 어댑터 미구현 |
| RESERVE_USE · 적립금 사용 | 사용/반환 요청·entry flag별 송금/수령/취소·이미 발생한 거래 기록 | canRecordActual·공개 사유·자동 우회 없음 회귀 | 실제 custodian 전체 브라우저 검증 대기 |
| DISSOLVE · 모임 해산 | 모임장 귀속/실출금·잔액0/업무 유지·무계좌 경로 | 역할/서버 버전 사용 | 실제 0원/미납 잔존 해산 브라우저 검증 대기 |
| MY · 마이 | 프로필·지난 정산·모임별 레벨·운영자 역할 진입 | 200/403 operator endpoint 구분 | 실제 화면 QA 대기 |
| HISTORY · 개인 정산 내역 | 20개 더보기/실패 동일 offset 재시도·lazy 자기8금액·원본 계산/정정 진입 | mock Dio HTTP7 GREEN·늦은 세션응답/숫자 누락/320폭200% 검증 | 실제 비부원/탈퇴 본인 단면 QA 진행; 기간/상태 필터는 정본 요구 아님 |
| LEVEL · 모임 레벨 | My 소속 모임·Club 기존 멤버행·허용 Event/Finance 본인 활동 레벨 | 같은모임 타인/공개 비부원 본인/탈퇴 본인 DTO위젯3 GREEN·ACL 그대로 | 실제 관계별 열람/403 QA 진행·전역directory/새공유프로필 없음 |
| PROFILE · 프로필 | 닉네임/선택 관심사·소개/SELF 사진·부분보존/명시해제 | 서버 실PG3 GREEN·앱 정규화/사진해제 회귀 | 본인 전용 사진의 native 선택/열람 미검증 |
| SETTINGS · 설정 | 기기 소유 영속·만료/401시FCM토큰삭제·다음로그인재발급·refresh/늦은응답 격리·설정/인수함 | A만료→B등록·늦은A응답·구refresh/새rotation·Main만료 cleanup 회귀 GREEN | 실FCM/APNs 자격/실기기 수신·iOS 빌드 미검증 |
| BANK · 계좌 등록·확인 | 본인 masked 계좌 조회·실제 확인 요청·실패 안내 | 개인계좌 UI 회귀·서버 실PG2 GREEN | 실제 공급자 어댑터 미구현(키만의 문제가 아님) |
| ACCOUNT · 계정 관리 | 남은 담당 업무 삭제가드·로그아웃·세션 기한 | 저장 실패/세션전환/401 회귀 | 공식 소셜 계정 복구 도움 연결; 전화번호만으로 병합하는 기능은 만들지 않음 |
| NOTIFICATIONS · 알림함 | 영속 inbox·읽음·기기 열기 인앱목록 | 푸시 중복방지 회귀 | social 댓글/좋아요→정확 글·DM/GROUP 요청→수신함 연결 회귀; 폐기 자원/권한회수 실제 QA 대기 |
| CHAT · 채팅 | 종류/최근 대화·별도DM 요청 수락/거절·그룹 초대 | DM/GROUP inbox 회귀 | 실제 STOMP 수신/차단/재연결 브라우저 QA 대기 |
| CHAT_ROOM · 이벤트 채팅 | REST 저장·sequence200페이지 회복·STOMP·서버 canWrite·메시지 신고 | 실제 계약 구현 | 전체 이력 메모리 조회(대화가 클 때 페이지 UX 부족)·실제 소켓 검증 대기 |
| FEED · 피드 | 독립 /feed 개인 글·모집 카드·반응·글쓰기·모임 찾기→/explore, 모임 공지 | 실제 reaction 위젯 회귀 | 실제 공개 범위/차단 브라우저 검증 대기 |
| POST · 게시글 상세 | 본문/사진·댓글 CRUD·좋아요·본인 수정/삭제·정확 원문 신고 | 실제 ID연결 REST | 삭제/차단 후 타화면 갱신 실제 검증 대기 |
| COMPOSE · 글쓰기 | 개인/모임 범위·공지 권한·사진 업로드/명시 해제 | 실제 POST multipart·REST | 실기기 이미지 QA 대기 |
| REPORT · 신고 | POST/COMMENT/MESSAGE 정확 content ID·대상 유형·사유 | 원문 연결 계약 | 신고 별도 첨부사진 UI는 현재 계약 없음 |
| MODERATION · 신고 처리 | case별 canReadDetails/canClaim/canDecide·정확 담당·결정/상향·한국어 이력/시각 | 맡기 회귀·CREATED/CLAIM 한국어+로컬시간 회귀·부모 실제 운영자 PROGRESS 저장 | 보호 증빙/권한회수 역할 QA 진행 |
| OPS · 운영 대시보드 | 실제 operator 권한 endpoint·정확 사건 담당·기록/보호 snapshot·결정 | 부모 실제 Chrome 운영자→정확 맡기→진행 안내 사유 저장→서버 상태/이력 확인 | root-operator-qa.md/운영 캡처 보존, 사진 없는 fixture는 사진 QA로 간주 안 함 |
| GROUP_CREATE · 그룹 대화 만들기 | 제목·알고있는 연락처 복수선택·명시 초대 | 그룹 작성·inbox 회귀 | 실제 사용자별 초대 상태 QA 대기 |
| GROUP_INVITE · 그룹 초대 | 참여자만 알려진 연락처 초대·수신함 수락/거절 | 서버 canInvite/실제 REST | 실제 차단 대상·권한회수 QA 대기 |
| GROUP_MEMBERS · 그룹 멤버 | 방별 명단·상태·본인 나가기 | 실제 members/leave 연결 | 관리자 강제퇴장은 새 정책으로 만들지 않음·실제 QA 대기 |
| ADVANCE · 선지출 반환 | 기존 지급자 채권/현금 분리·실반환 요청/송금/수령·정확 수령계좌·남은 현금 추가인계 | 빈이력 최초 현담당 이름·고정수령자·명세금액 회귀 및 서버 GREEN | 실제 금융 상태 단계 QA 진행·실송금 미검증 |
| SELF_RECOVERY · 내 선지출 회수 | 명시 자기상계·제안값과 실제 회수 분리·원장 이력 | 외부 송금 완료 아님 회귀 | 실제 수금 이후 회수 E2E 대기 |
| HANDOVER_REVIEW · 변경된 인계 확인 | 원본/현재 현금·선지출/환불/미수/이의·stale 재수락/반환 | 이미 받은 현금 재청구 없음·권한 미이전 회귀 | 전체 stale/재제안/반환 실제 브라우저 QA 대기 |

## 구현 결정과 감사 근거

- 초기 버전의 UUID 직접입력을 이름/모임 부원·참가자·기존 연락처 선택기로 교체했다. 인계 후보는 별도 handover-candidates predicate를 사용하며 글로벌 사용자 디렉터리를 가정하지 않는다. 서버 권한은 각 명령에서 다시 검사한다.
- 정산 방식은 개설 때 명시 선택한다. 공통 작성은 전체 차수 입력을 먼저 검증하고 단계별 원 key/body를 보안저장해 앱 재시작에도 이어간다. 409는 최신 자료 확인 후 재작성하며 임의 버전 갱신 재전송으로 우회하지 않는다.
- 모든 쓰기 Command는 중첩 body까지 불변이고 계정별 영속 멱등키를 재사용한다. 필드 순서는 canonical JSON으로 비교한다. 네트워크/5xx는 원문 고정·재시도, 4xx는 미확정 키를 정리한다. 세션 전환 전후의 늦은 요청/응답은 새 계정 화면을 갱신하지 않는다. 보안 저장 실패를 성공 로그인으로 처리하지 않는다.
- 금액은 정수·허용 범위·배분 합계를 검증하고 실제 숫자 누락을0으로 바꾸지 않는다. 통화는 원 단위 그룹 표기·tabular figures다. 실제 입금/개인 선지출/일반환불/advance 채권을 구분하고 금융 완료는 서버 응답 후 조회한다.
- 실제 입금의 허용 귀속 종류는 private report의 allowedAllocationKindsByRound만 사용한다. HOST_CONTRIBUTION을 이름이나 전역 hostId로 추측하지 않는다. 정정의 기본액은 reportedAmount 대신 실제 amount다.
- Profile 선택 관심사는 순서 보존 trim/dedup20개·각30자, 소개300자다. null 보존/[]·빈bio 초기화, clearAvatar 명시를 사용한다. 사진 연결은 기존 personalPOST 소유 검증이며 다른 사용자에게 공개 권한을 만들지 않는다. 가입 Auth.register는 바꾸지 않고 가입 뒤 선택 설정으로 연결한다.
- 사진 선택 imageQuality90/10MiB, 실제 multipart 파일 업로드/서버 sniff 권한검사를 사용한다. PDF 증빙은 pdfx2.11.0과 로컬 Mozilla PDF.js4.6.82(공식 registry SHA512 integrity 검증/Apache2 라이선스)로 읽는다. 보호 증빙 viewer가 외부 CDN script를 로드하지 않는다. Native/브라우저 PDF 실렌더는 별도 수락이다.
- Google은 시도마다 nonce를 받는 공식 native bridge다. Android Apple은 승인된 S256 PKCE+서버 state/nonce+고정 callback+불투명 일회 ticket만 사용한다. 토큰을 URL query에 넣지 않는다. Apple 서버3개 실제 RS256/HTTP/PG 테스트가 부모158 전체 GREEN에 포함됐지만 실제 Apple 공급자 인증은 미검증이다.
- 예비비 canRecordActual은 ‘이미 발생한 거래 기록’ 별도 진입이다. 부족 중 /execute 오류를 자동 우회하지 않고 원 목적/금액·공개 사유를 유지한다. 인계 뒤 과거 사실 정정으로 남은 현금은 CUSTODY_TRANSFER로 현 담당에게 보내며 권한 이전을 반복하지 않는다.
- 역할·상태 선택 폼은 첫 항목을 임의 기본값으로 제출하지 않는다. pending 조건 재동의 미응답은 참여를 유지하며 거부 무료취소와 구분한다. 정산 등록 후 참석 정정의 기본 재분배는 명시 경고·확인 후 기존 차수 개인 조정을 제거하고 필요하면 별도 정정을 추가한다.
- Theme은 exact CSS palette·Pretendard·20px 여백·금액 tabular 및420폭을 매핑한다. 앱 소유 UI의 최종57개 이미지 비교/명암/초점/스크린리더 QA는 아직 미검증이며 기본 Material Semantics만으로 완료라 하지 않는다.

## 실제 서버 역할 검증 환경

`MobileScenarioHost.java`는 test source 전용 PG Testcontainer + 명시 db/dev/mobile-scenario profile이며 127.0.0.1:18080만 바인딩한다. Social/SMS/Bank 대역도 test source에만 있고 production login 우회가 없다. 세션 manifest는 gitignored `.superpowers/mobile-scenario/manifest.json`에만 쓰며 명령줄/query/로그에 토큰을 출력하지 않는다.

Flutter `test_support/main.dart`만 서버가 발급한8역할을 선택하고 TEST 배너를 표시한다. 정상 main 로그인과 분리한다. test_support/seed_finance.py는 실제 REST로 은행 TEST대역 등록·이벤트/참여/지출/정산/신고/실제사실확인/환불요청 fixture를 만든다. 앱 상태를 가짜 완료로 직접 채우지 않고 실제 은행 이체라고 주장하지 않는다. 8766 loopback preview와57개 역할 흐름 관찰 결과는 확인 후 갱신한다.

## 완료 판정

원요구 대조에서 확인한 앱 코드 누락과 독립 P2는 수정하고 회귀로 검증했다. 로컬 최종 빌드·대표 실제 역할 GUI 및 PR22의 정확 코드 HEAD CI8개를 통과했다. 외부 공급자·실기기·전체 화면 시각/접근성 수락까지 완료한 것으로 확대하지 않는다. 환경 수락은 공급자 실인증/SMS/FCM/APNs·실은행·iOS 빌드/실기기·서명배포·대규모 페이지/소켓 복구다. 서버168개 GREEN과 이후 이력 이름 선택5개 GREEN은 앱57개 실제 수락과 구분한다. 중앙 REQUIREMENTS-AUDIT/결정 원장과 vault는 parent가 동시 편집 충돌 없이 갱신한다.

## 최종 회귀와 실행 근거

- `.superpowers/mobile-scenario/verification/mobile-analyze-final-05.log`: No issues found, 10.7초.
- `mobile-test-final-05.log`: 86/86 GREEN, 41초. 도움 helper의 History7/Revision7을 포함한 전체 실행이다.
- 최초 APK `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`: 2029.8초 성공. SDK34/35/CMake3.22.1을 공식 도구로 자동 설치했다. KGP 이행/SDK XML/Java8 obsolete 경고는 빌드 오류와 구분하며 최신 소스 재빌드는 별도 로그로 남긴다.
- 원화0 정정은 allocations/fundings=[]를 명시 선택해 보낼 수 있고 양수/부호 배분 합계·출처 검증은 유지한다. 실제 기존원본은 append 이력으로 남는다.
- FCM 소유/미완등록 표식을 보안저장하고 계정 만료 때 auto-init을 끈 뒤 SDK deleteToken을 호출한다. 다음 계정은 새 토큰을 등록하고, epoch/등록순서/직렬화로 늦은 응답을 격리한다. 서버의 다른 계정 소유 토큰을 강제로 빼앗지 않는다. [Firebase Android deleteToken/API](https://firebase.google.com/docs/reference/android/com/google/firebase/messaging/FirebaseMessaging), [Flutter 수신 설정](https://firebase.google.com/docs/cloud-messaging/flutter/get-started). 실제 공급자의 단말 전달/삭제 전파는 외부 수락이다.
- Host는 최신 V11/요청 이력 이름/Origin DTO의 classes/resources를 `.superpowers` 시각별 snapshot으로 복사한 독립 Java25 프로세스다. Gradle project lock과 동시 컴파일 영향을 분리했다. shutdown.request 파일 신호로 정상 JVM/PG 종료하며 bearer/token을 명령줄에 넣지 않는다.
- Home/Level/metadata/가입·합류/각종 금전 실제 행동은 기존 관계/문맥 안에서만 연결한다. 신규 전역 사용자 목록·계정 전화번호 병합·이미지 전체 공개·은행 namespace 추정은 추가하지 않는다.


최종 GUI 보완: 중앙+의 실제 AX 이름 `정모·번개 만들기`를 확인했고, 실제 TEST PG/REST 환불 SENT→본인 CONFIRMED5000원 뒤 `수령 확인 완료` 카드와 확인 버튼 제거를 확인했다(`apps/mobile/docs/screenshots/test-refund-confirmed.png`, `test-refund-sent.png`). 외부 은행 송금은 하지 않았다. 피드/탐색 분리 회귀와 초대수락 뒤 최근 대화 즉시 갱신 회귀를 포함한 최신 전체86개 GREEN은 `mobile-analyze-final-05.log`, `mobile-test-final-05.log`에 보존했다. 실제 그룹초대 수락에서 발견한 stale 목록은 같은 화면의 관계 변경 성공 때 최근 대화도 재조회하도록 수정했으며 별도 권한/API를 만들지 않았다.

최신86 TEST web에서 그룹초대 수락 후 같은 목록에 그룹방이 즉시 표시되고(`test-group-accepted.png`), 실제 그룹방 REST 작성 및 다른 테스트 역할이 쓴 메시지를 새로고침 없이 STOMP로 받았다(`test-group-message.png`, `test-group-live-received.png`). 피드 탭은 검색 폼 없이 별도 글 화면으로 확인했다(`test-feed-final.png`). 사진 선택은 브라우저 chooser까지 진입했으나 자동 파일 주입은 확장의 로컬 파일 접근 설정 때문에 차단되어 GUI 업로드/보호 뷰어 완료로 표시하지 않는다.

최종 플랫폼 실행: `mobile-test-web-final-04.log` TEST web126.8초, `mobile-web-final-04.log` production web94.8초, `mobile-apk-final-04.log` debug APK21.1초 모두 성공. 마지막 변경은 기존 한국어 날짜 formatter 재사용 한 줄이며 금액/권한/전이 변경이 없다.


PR22의 f34fc26은 Java/Node/문서/운영웹/모바일 CI8개가 모두 통과하고 develop e84f1f1에 병합됐다. 운영 웹도 최신 실제 PG에서 사건 맡기→원문/CLAIM→PROGRESS 사유 저장→버전2와 목록/상세 이력 갱신을 확인했다. Origin5173은 test-only host의 정확 허용 목록이며 생산 권한/CORS 변경이 아니다. root 추가 역할 검증에서는 탈퇴/블랙리스트 이력자의 본인 미납/레벨 접근과 내부 콘텐츠 비노출을 확인했다. 실인증·실은행·기기 수신/서명 배포·iOS 및 자동 사진 업로드 GUI 제약은 위의 미검증 범위를 유지한다.
