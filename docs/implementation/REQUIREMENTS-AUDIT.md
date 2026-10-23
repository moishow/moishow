# 요구사항·이슈·계획·구현 대조 및 결정 원장

> 2026-10-22 사용자 지시. 모든 구현 시작 전과 머지 전 대조한다. 진행 중 결정도 이 문서에 모으고 전체 충돌을 재검토한다. 검증 명령 통과는 정본 일치의 대체가 아니다.

## 정본 우선순위·절차

사용자 후속 확정 > POLICY.md > 현재 도메인 시나리오 > 해당 이슈의 정본과 양립하는 인수기준 > 구현계획 > 코드. 이전 이슈의 포인트/에스크로/PASS 실명 전제가 새 정책과 다르면 이전 요구가 대체되었음을 기록한다. 이슈를 충족시키려고 새 정책을 되돌리지 않는다.

1. 작업 전에 요구사항ID·이슈·계획·예상변경·인수테스트를 한 행으로 연결한다.
2. 불일치/미명시/외부검증불가를 구분한다. 불일치는 구현 전에 해결하고, 기존 코드는 회귀 테스트로 수정한다.
3. 작업 중 결정한 값·상태·범위·예외를 아래에 기록하고 기존 결정 전체와 충돌 여부를 확인한다.
4. 머지 전 구현·테스트·남은환경항목과 대조표를 갱신한다. 미완료/미검증을 완료로 닫지 않는다.

## 현재 감사 범위

기존 main 정책/51화면, PR19/20, 미커밋13~16/앱 통합 API. 새 기능 추가를 잠시 멈추고 요구/이슈/계획 대조 중이다. 작업자별 감사 결과를 통합해 수정 순서를 결정한다.

| 요구 | 이슈·계획 | 구현/테스트 | 상태·필요한 조치 |
|---|---|---|---|
| P02 개설 시 정산 방식 선택 |13·16/Finance·Mobile | EventForm mode 추가 중, 생략POSTPAY 기본값 | 불일치 후보: 묵시적 선택이 사용자 선택을 대신하는지 확인 후 필수선택으로 수정 |
| P04 사전 고지·변경 재동의·미응답 참여유지 |13·16 | identity agreedFee 스냅샷만, 변경/동의 API 미구현 | 미완료: 변경·동의·미동의/기존비용 유지 흐름 구현 필요 |
| P04 주최 취소/날짜 변경 불참 전액환불 |13·16 | 일반 참가자 CANCELLED 비용계산만 | 미완료: 주최 사유 취소/재확인/비용면제 및 환불 연결 필요 |
| P05 늦은 취소비 REFUND/RESERVE 선택 |13·14 | choice+earmark 구현, 일반환불전환 차단 | 코드/통합테스트 최종 확인 중 |
| P06 마감 후 원본 보존 정정·미납/이의 유지 |13 | 원본snapshot+append 구현, 명단 변경 일괄거절 | 정정으로 실제 참석/노쇼/참가 오류를 고칠 수 있는지 감사 |
| P07 실제 수령/0원 확인 후 담당 이전 |14 | handover 구현2기본 테스트 통과 | 전체수령/버전/권한·담당삭제 가드 추가 검증 |
| P08 적립 실확인·사용/해산 잔액0·모임장 귀속 |14 | reserve 구현, 계좌설정 제약오류 수정중 | 은행 검증미연동과 알고리즘 미완을 분리, 실제흐름 테스트 필요 |
| P09 계좌등록 별도 예금주 검증 |12·14·16 | BankOwnershipVerifier 기본503, 보관계좌만, 개인계좌없음 | 외부키 부재뿐아니라 어댑터/개인계좌 흐름 미완료로 기록 |
| P11 인앱/푸시·채팅 |15·16 | 플랫폼 FCM HTTPv1·단말등록·기기별outbox 및17회귀 통과, 채팅은 커뮤니티 통합중 | 실제 FCM/실단말 수신·모바일 등록 연결은 환경/앱 검증으로 구분 |
| issue16 실기기/실공급자/오프라인/증빙 |16 | Flutter web/test확인, Android빌드대기 | 코드누락과 환경미검증을 분리해 인수기준을 유지 |

## 임의 결정 원장(현재까지 수집, 감사 후 계속 추가)

| 결정 | 근거/분류 | 충돌·비용 및 조치 |
|---|---|---|
| 서버 Java25/Gradle/Boot4.1.1 | 사용자확정 | 유지 |
| 세션 제한15분/활성8시간, OTP5분/5회·60초/계정시간5회 | 구현 보안 기본값(사용자 숫자확정 아님) | 개인정보·푸시 정책과 무충돌, 설정/문서화. 환경테스트 필요 |
| 초대7일 | 구현 보안 기본값 | 강퇴/블랙 우선순위를 바꾸지 않음 |
| 소유자 승계 전 탈퇴 거부 | 책임유지 가드, 승계누락 때의 임시제약 | 승계 수락API14에서 제거가능. 계정삭제/보관계좌 인계와 함께 확인 |
| 종료 후 신규 합류 거부 | 정책 미명시 구현 선택 | 소급 실제참가 정정 수단이 없으면 정산누락 충돌. 정정의 명단수정 필요 여부 검토 |
| 대기 자동승격 없음 | 정책 미명시·무단선정 방지 | 미납자동취소금지와 무충돌. UX에 대기유지 명시 |
| 등록 후 참가상태 변경409 | 원본보존 위한 구현가드 | 이의 인정/참석정정 경로가 빠지면 요구불충족, append정정으로 대체 |
| 업무POST UUID Idempotency-Key + resource version | STATE-MODEL/구현명세 | 인증OTP/토큰발급을 같은응답원장에 넣지 않는 예외, 재시도 UX검증 |
| root reserve 은행검증 기본503 | 미검증성공금지 | 영구stub를 외부키 미설정으로만 설명하지 않음. 실제계약 어댑터/개인계좌 필요 |
| STOMP 쓰기는 REST, 구독만WebSocket, 단일노드broker·DB이력 | 기술구현 선택 | 메시지보존/재연결/권한 실효를 테스트. 다중서버배포미지원 명시 |
| 새API default/dev DB비활성, db프로필만 영속 | 개발편의·안전경계 | 앱기동/배포안내와 일치검증 |

## 수정·검증 기록

감사 진행 중. 위 항목은 해결됐다고 표시하지 않는다. 작업자별 원본요구 대조와 임의결정을 수신 후 머지 전 갱신한다.

## 도메인 감사 통합 — 수정 전 실제 상태

### 정산13 대조

- P02: 개설 방식 생략POSTPAY는 요구 이탈. 신규 생성은 명시선택 필수, DB default는 이전자료 마이그레이션에만 사용한다. 차수별 선납 조건을 마감 전에 저장하고 마감 실행/작업이 확정자에게 요청하도록 수정한다. 마감 후 합류 승인에는 기존조건으로 신규인원 요청만 만든다.
- P03: 한 요청당 신고1개/잔여액이하 신고/신고액이하 확인은 실제 입금 사실을 버릴 수 있는 임의제약이다. 복수/초과입금을 기록하고 실제확인 거래 식별자의 중복을 막는다. 확인액·실제시각 오류/나중시각확인은 원거래 보존 정정으로 처리한다.
- P04: 일반 취소만 구현하고 주최취소·날짜변경·미응답 유지·비용재동의·실노쇼 기록은 미완료였다. agreedFee에 동의조건 버전/시각·면제 사유를 연결하고 사용자 확인 전 새 비용을 적용하지 않는다.
- P05: 이벤트 전체 사용자간 임의금액 조정은 불참 차수 비용 전가 위험. 차수별 참가자 근거에 한정한다. 복수차수 현금 귀속을 임의우선순위로 정하지 않고 확인 화면에서 귀속/금액을 명시해 합계를 검증한다. UUID만 정렬한 동명이 사용자 다차수 귀속 순서는 비결정적이므로 고친다.
- P06: 등록 후 실제참석/취소/노쇼 정정을409로만 막고 '정정 이용'이라고 안내했지만 정정API가 이를 지원하지 않았다. 원본 스냅샷을 남기고 정정기록으로 유효상태/금액/실제거래를 바꿀 수 있어야 한다.
- 환불은 SENT부터 시작·서버현재시각을 실제송금으로 대신한 압축 흐름이었다. REQUESTED→SENT(실제송금시각/식별)→CONFIRMED 수령을 분리한다. 미수령을 소멸시키지 않는다.
- 이의 REVIEWING 및 결과/정정금액 공개·revision연결이 빠져 있었다. 당사자/정확히 할당된 처리자만 상세·증빙을 조회하고 다른부원은 상태·결과·정정액만 보도록 수정한다.
- 기한 미입력시 최종등록+72h 자동납부기한은 사용자결정과 충돌한다. 주최자가 정한 차수별 납부기한을 요구하고 명시적인 연장 이력을 남긴다. 72h는 최초정산 등록기한에만 적용한다.
- 앞선5개 테스트만 GREEN; 이후모드/자동합류청구/기한/개인범위/이의위임 변경은 감사시점 미검증이었다. 이 상태로 PR13을 완료라고 보고하지 않는다.

### 커뮤니티·홈 대조

- 개인 글 전체 노출은 시나리오F1의 내모임·팔로우 콘텐츠와 불일치. 글 직접조회권한과 홈피드선별을 분리한다.
- 차단 시 양방향 follow를 삭제하고 차단된 사용자가 unblock도 못하게 한 것은 요구 밖 부작용. 차단은 피드/DM에만 적용하고 안전조치인 차단/해제는 제한사용자도 허용한다. 금융권한은 건드리지 않는다.
- PENDING DM은 첫 메시지도 못 보내고 받은 요청함/거절이 없어 시나리오와 다르다. 첫 메시지 요청·받은 요청 목록·수락/거절을 구현하고 정상목록과 구분한다. '알려진 상대=상호팔로우만'은 미확정 구현선택이므로 같은모임/확정이벤트 관계도 대조한다.
- 이벤트 endsAt가 지나면 저장한 채팅도 전면차단한 것은 승인되지 않은 제약. 확정 참가자의 기존이벤트 기록과 일반모임 탈퇴 권한을 구분한다.
- my/history에 미래 주최/참가일정을 넣은 것은 '과거정산' 요구와 충돌. 홈날짜선택/현재업무와 분리하고 미송금환불/인계/적립 할일을 포함한다.
- 좋아요·사진·편집/삭제·공지 권한·이벤트 자동모집카드·단일글조회·댓글 직접접근검증·모임닉네임변경·삭제계정표시가 미완료였다. 관련 시나리오/화면과 연결해 보완한다.
- issue5 임의 다인원DM은 검토 요청일 뿐 채택되지 않았다. DIRECT+CLUB+EVENT를 구현했다고 그 검토요구까지 완료라고 닫지 않는다. 모임 공개/비공개 탐색상태 역시 명시정책이 없어 구현완료로 조작하지 않는다.

### 모바일16 대조

실제 REST폼/목록이 있으나 51화면 전체 수용기준은 미완료다. ATTENDANCE, 비용변경CONSENT/주최취소/날짜변경, 개인계좌/계정복구, 증빙실업로드/보호뷰어, 푸시단말등록/백그라운드, 모더레이터 결정화면, 피드반응/공지/수정삭제/모집카드, 홈+공통작성진입, 닉네임 선택기 대신UUID입력, 앱재시작 후 동일키 재시도 복구가 빠졌다. Android Apple로그인 콜백/옵션 부재는 키 미제공과 다른 코드누락이다. 51행 앱대조표는 MOBILE-APP.md에 연결한다.

### 수집한 추가 임의결정(분류 후 충돌검토)

- 정산: finance/open 별도·version0초기값/응답1; 선납금양수만; 마감후수동청구; RoundBilling 불변; 개별기한앞방향연장; 실제시각nullable보류; 신고승인/반려terminal; 증빙문자열10000/제목100/사유1000; 지출0허용; 지출증감/개인보전조정상호배타; 첫등록actual처리자HOST점수; 모르는실제시각/분쟁전체HOLD; READ_COMMITTED→repeatable-read 조회; 수동DBversion; 범용Form 미사용필드 허용; 첫등록시선납요청SUPERSEDED; 늦은취소비미선택보류·현재미배분분전체선택·향후입금다시보류; 해산후새RESERVE선택금지; SENT금액환불차감은실송금확인과일치하므로유지. 제품행동이 바뀌는 제한은 수정하고 형식/보안 제한은 명세화한다.
- 커뮤니티: 본문10000·검색100; 피드/댓글/이력200·탐색/일정100 제한과페이지누락; 생성순서UTC+UUID; DM쌍영구고유; GET에서방지연생성; 빈방생성순정렬; 소켓단일인스턴스broker·하트비트미설정·동일origin기본·예외시메시지드롭; 메시지불변/보관기간미정·typing/readreceipt/검색/나가기미정. 삭제계정 상대에게 새DM쓰기를 허용한 것은 수정대상이다. 상호차단 표시와 관계삭제를 혼동하지 않는다.
- 모바일: 사용자에게 UUID 입력시키는 폼, 네이티브Google nonce 브리지, API오류를 '외부설정없음'으로표시한범위, 임시selectedmode/증빙텍스트 및 자격증명없음 UI는 코드완료/실검증을 분리한다. 명확히 미구현인 버튼을 단순설정문제로 설명하지 않는다.

## 보완 구현 순서(사용자 기존전체구현 지시 유지)

1. 위 요구 이탈·누락을 근거로 도메인별 수정 계획/실패테스트를 먼저 추가한다.
2. 정산/참가상태·실거래/환불/이의 단계를 수정하고 인계/적립금 가드와 통합 검증한다.
3. 커뮤니티/홈/채팅의 노출·역사·요청함·누락행동을 수정한다.
4. FCM 실제설정가능 어댑터·정확사건할당·콘텐츠 조치, 개인계좌/보호파일 계약을 연결한다.
5. 앱51행 대조표의 실제행동을 연결하고 분석/테스트/웹/APK/E2E를 수행한다. 실기기·실제공급자 수신은 별도환경 검증으로 남긴다.
6. 감사표 해결증거/남은항목을 갱신한 뒤 해당 PR CI·머지·이슈처리. 미완료 요구를 조용히축소하거나 '환경'으로 바꾸지 않는다.

## 후속 사용자 결정

2026-10-22: issue5 임의 다인원 그룹 DM도 추가 확정. 이전 '현재정본3종만'은 이제 대체됐고 정책P11·이슈·계획·앱대조표를 같이 갱신한다. 공개/비공개 검색 정책 질문은 아직 미응답이므로 그 결정에 의존하는 변경은 보류한다. 그룹 DM의 초대/수락/거절/나가기와 멤버·권한 변경도 구현 선택으로 원장에 적고 피드/개인차단·공유방 권한·금융접근과 충돌을 검토한다.

### 플랫폼15 수정 전 요구 대조 — 2026-10-22

이 절은 POLICY P10–P13, 시나리오 회원/홈/모임/피드, GitHub issue15 원문(2026-10-22 조회), STATE-MODEL/ROADMAP/REMAINING-EXECUTION 및 Platform 코드·10개 기존 테스트를 비교했다. 기존 GREEN은 아래 누락의 완료 증거가 아니다.

| 요구·이슈 | 기존 구현 차이 | 수정·인수 증거 계획 |
|---|---|---|
| P11·issue15 실제 설정 가능한 알림 adapter | 인앱/outbox는 영속이나 모든 전송은 영구 미연동 RETRY, 단말등록 없음 | FCM HTTP v1 + 공식 Google 인증 SDK로 서비스계정 파일 설정, 소유자 단말 등록/삭제, 성공은 공급자 접수 SENT로만 기록. 로컬 HTTP 공급자에서 실제 요청/재시도/토큰유출 방지 테스트. 실제 FCM·실기기 수신은 별도 환경 검증 |
| P10 이의 상세는 당사자·해당 건 처리 담당자만 | 큐의 모든 운영자/모임관리자를 처리자로 간주, financial dispute 연결/할당 없음 | 정확 event/dispute/당사자 검증 → 단일 담당자의 명시적 claim → FinanceCaseAccess exact assignment. 미할당 운영자는 비민감 큐만, 다른 이의·전체금융증빙 접근 불가 |
| P10 이의 상태·결과·정정액 공개 | private case 이력만 있고 부원용 공개 상태/결과/정정액 DTO 없음 | 부원 전용 공개 case summary에 상태·결과·확인된 연결 정정액만 제공; 사유/증빙/송금 캡처 제외 |
| P10·피드 F4 글/댓글/대화 신고·콘텐츠 조치 | POST/COMMENT 구현은 있으나 실제 통합회귀 미검증, MESSAGE 미지원 | V6 실제 post/comment/message author·club/room 접근 검증과 상태 REMOVED 전이 테스트. 신고자에게 원래 없는 DM 접근을 만들지 않음 |
| P12 역할별1회·보류·정정 | 최초 등록 수행자를 HOST로 가점한 것은 정본의 ‘주최’와 해석 차이, 인계 후 원주최 감점보류도 미명시 | 사용자 확정 없이 수행자=주최로 재정의하지 않음. root에 쟁점 보고; 인계 중 불확실 판정은 보류로 노출하고 원주최/등록수행자 보존. 이의 전체 HOLD도 영향 당사자/판정만으로 제한 필요 |
| P13 24/72h·운영자 | 기본 24h 재안내/요청자72h상향 구현, 소명·담당할당·최초회신 지표 누락 | claim/진행/결과/근거 기록, 72h 최초 회신 목표 표시, 강제 외부송금/임의확인 API 없음 유지 |

### 플랫폼15 임의결정 전수 기록·충돌 검토

- 인앱 SOCIAL은 동일 사용자+groupKey의 미열람 건만 묶고 읽은 뒤 새 항목을 만든다. MONEY/REFUND/DISPUTE/SUPPORT는 개별. ‘유사 건’ 구현 정의이며 금액 업무 묶기 금지와 충돌하지 않는다. 생성시각 내림차순+UUID 정렬, 무페이지 전체조회는 기존 선택이며 규모 제한/페이지 범위는 아직 사용자 확정이 아니다.
- 전 종류 통합 pushEnabled 기본 true, 별도 미설정 행은 true. 사용자가 모든 종류를 끌 수 있는 P11은 충족하나 종류별 세분화는 미명시다. off 시 기존 대기 outbox도 SUPPRESSED, 다시 on 해도 과거 억제 건을 소급 전송하지 않는 선택을 명시한다. 인앱/금융기록 삭제 없음.
- outbox는 분당 Quartz 스캔, 한 회100개, 미설정/실패15분 후 재시도, 현재 최대시도 제한 없음. 공급자 접수와 단말 배달을 분리한다. FCM timeout/단말토큰 길이·기기당 등록·중복/오류 처리 제한은 아래 수정 기록에 수치까지 적는다.
- Quartz 분당 트리거·JDBC clustered JobStore·Flyway V5 schema·initialize-schema=never·오래된 스케줄 재생성 없음은 issue15의 영속 요구를 위한 기술 선택이다. 24h 재안내는 각 무응답 구간1회, 진행 안내 후 activityAt 재시작, 72h마다 요청자가 명시적으로 상향하며 자동 금융처리하지 않는다.
- 요청 사유 최대4000자·groupKey255자, 보고유형 CLUB_CONTENT/PERSONAL_CONTENT/USER, 콘텐츠 종류 POST/COMMENT(추가 MESSAGE)·처리행동 PROGRESS/RESOLVE/WARN/RESTRICT/CORRECTION_REQUEST/HANDOVER_REQUEST/CONTENT_REMOVE는 형식·워크플로 선택이다. 정정/인계는 담당자에 요청하고 금융 상태를 직접 변경하지 않는다. 제한은 소셜에만 적용하고 정산 접근 보존.
- 운영자 role은 platform_operator 오프라인 SQL 부여/회수만 허용하며 클라이언트/환경의 사용자ID 플래그로 부여하지 않는다. 현재 역할자 전원에게 상세허용은 P10의 ‘해당 건 담당자’와 충돌하므로 claim 단일담당으로 수정한다. 신고자·신고대상은 자기 사건 처리 불가; 일반 support 요청의 HOST는 본인 담당요청을 답변할 수 있다.
- 기존 POST는 UUID Idempotency-Key와 Commands 계정 잠금/응답영속, case version stale409를 사용한다. 새 단말 삭제/claim도 같은 멱등 계약을 따른다. 잠금은 계정→모임→이벤트→book/case; 타인의 계정 잠금 없음.
- level은 사용자/event/role 고유1행과 append audit, 합산 50점 후0..100 clamp. HOLD/ERROR_CORRECTED는 해당 판정delta0으로 정정한다. 이미 정상/회복된 건의 LATE를 무시하던 선택은 실제 시각 오류 정정이 있을 때 소급 오류를 반영하지 못할 수 있어 명시적 correction 경로와 회귀 검증이 필요하다. 원래 시각 미확인/관계 없는 이의를 금융 신용 신호로 취급하지 않는다.
- 운영웹은 동일출처 실제 bearer REST, token은 메모리만, 개발 /api proxy 기본8080, 최대사유4000, API 결과 뒤에만 성공표시. 운영 로그인 공급자화면·권한부여 HTTP·가짜 큐 없음. 실제 배포 TLS/역프록시/공급자 자격증명은 환경 확인 항목이다.

### 플랫폼15 보완 설계 결정(구현 전)

- FCM은 공식 HTTP v1 `projects/{project}/messages:send`, 공식 Google Auth Java 1.54.0의 typed ServiceAccountCredentials parser와 firebase.messaging scope를 사용한다. 배포가 제공한 로컬 서비스계정 파일/프로젝트 설정만 읽고 클라이언트 HTTP 입력으로 공급자 URL·자격증명을 받지 않는다. 공급자 endpoint는 공식 Google 주소, 로컬 HTTP 테스트는 테스트 소스에서만 주입한다. 연결5초·요청10초 제한은 운영 기술 기본값이다.
- 단말은 인증 사용자의 FCM token+ANDROID/IOS/WEB, 토큰은 공백 없는1..4096자 형식 제한이다. token은 사용자간 중복 소유409로 거부, owner만 id로 해제한다. 응답·로그·FCM오류에 token을 노출하지 않는다. 해제 시 원문 token을 지우고 소유·전송 audit id만 보존한다. 이 기기 인증은 FCM 등록토큰 소지에 의존하고 별도 실단말 인증을 가장하지 않는다.
- outbox는 기기별 공급자 접수 이력을 남겨 부분 실패 재시도에서 이미 접수된 기기 재전송을 피한다. 정상 응답의 message name을 저장한 상태만 SENT이며 단말 배달/열람 DELIVERED로 표현하지 않는다. 전송 후 DB커밋 전 장애의 중복 가능성은 FCM의 멱등 부재로 남으며 notificationId를 앱 중복표시 방지 키로 전달한다. 미설정/일시실패/단말없음은 RETRY, 공급자가 UNREGISTERED라고 명시한 token만 폐기한다. 오류 본문에 포함될 수 있는 비밀값을 저장하지 않고 통제된 오류코드만 기록한다.
- 공개 알림 본문에는 금융 상세·송금 캡처·신고 소명 본문을 담지 않는다. 푸시는 알림 존재·종류·알림ID만 전달하고 상세는 인증된 인앱에서 조회한다. 소셜 그룹 중복 payload와 금융 개별 알림을 구분한다.
- case claim은 명시적인 단일 handler_id 할당이다. 역할자 전원은 내용 없는 큐를 보지만 상세는 당사자와 현재 정확 담당자만 본다. 신고자/대상의 자기 처리 금지는 claim 단계에서도 적용한다. 다른 정상 담당자를 덮어쓰지 않고 409, 기존 역할 실효로 처리권한을 잃은 담당자는 새로운 자격자가 reclaim하며 이력을 남긴다. 상향 시 담당을 해제하고 다음 단계에서 다시 claim한다. claim 자체는 최초 회신이나 실제 진행 안내로 간주해72시간을 연장하지 않는다.
- financialDisputeId는 해당 event의 해당 당사자가 만든 이의와 일치할 때만 연결한다. 정확 할당은 금융 이의1건의 상세·처리 계약에만 연결하며 전체 finance 조회/입금확인/강제송금 권한을 주지 않는다. 부원 공개 결과는 finance 소유의 public_result/correction_amount/revision_id를 읽고 platform 사유/증빙을 섞지 않는다.
- 신고한 글/댓글/메시지의 내용은 접수 시 원문·대상·종류를 case에 보존하여 나중 편집·삭제와 구분한다. MESSAGE는 원래 방을 볼 수 있는 신고자만 신고하고 현재 방 전체를 운영자에게 열어주지 않는다. 운영자는 할당된 단일 신고 메시지 증빙만 읽는다. 메시지 신고는 대화 맥락과 개인 신고 정책상 운영자로 보내며 모임 콘텐츠 글/댓글의 관리자1차 라우팅을 메시지에 임의 확장하지 않는다.
- HOST 인계 뒤 실제 등록 수행자에 정상 HOST 가점을 자동 부여하던 해석은 보류한다. 원주최/실제 등록자 사실을 보존하고 인계 중 귀속이 불명확한 판정은 HOLD로 남긴다(정책 명시 전 보류). 이의/시각 HOLD는 관련 참가자·관련 판정에 한정하며 관계없는 참가자/주최 정상 이력을 지우지 않는다.

## 후속 확정 — 인계 전 선지출

사용자: 기존 주최자의 미회수 선지출을 기존 주최자에게 돌려줄 의무로 인계. P07 갱신. 단순 이벤트 전체 입금-지출 합계는 인계 후 현금을 잘못 계산한다(원주최 지출10000/수령4000,0원인계+미회수6000, 새담당 이후6000수령 시 실제보관현금6000/원주최채무6000). 담당자별 실제 입금확인 주체·실송금 주체·지출 지급자를 보존하고, 현금 인계/적립/선지출 반환의 실제 이동도 함께 계산한다. 원주최/실제등록자/현재담당을 섞지 않는다.

수정계획: Finance에 cashMovement(event,actor) 실제확인금액·송금액·지출지급자 기준 제공, Reserve에 인계잔액 대조와 기존 선지출 반환채무/요청/실송금/수령확인 원장 추가. 입금/환불/지출 정정은 원본보존 후 유효현금에 반영. 미회수채무 인계 수락은 현금0원 확인과 별도명세에 드러나야 한다. 이미인계된채무 중복생성/실송금 전 소멸/총액합계만으로새담당잔액0판정은 금지한다. 이 기능은 아직 코드완료가 아니며 테스트먼저 재현한다.

- 점수 재동기화는 입금 원행을 별도 SQL 합산하지 않고 금융 도메인의 FinanceScoreSource.reassess(eventId)를 사용한다. 원본 보존 입금 정정·금액 귀속·활성 요청의 실제 유효값과 같은 계산을 사용하여 스케줄러가 정정 전 시각/금액으로 점수를 되돌리는 충돌을 제거한다. 플랫폼은 club→event→book 잠금과 호스트 등록 시각의 보류만 소유한다.
- MESSAGE 접수는 방 소속만으로 허용하지 않고 커뮤니티가 소유한 canReadMessage의 현재 메시지 열람권한을 확인한다. 특히 GROUP_DM은 방 소속이 유지돼도 개인 차단에 따라 숨긴 작성자의 메시지를 새 증빙으로 조회하지 않는다. 권한 helper 미구현의 default는 false로 닫으며 미연동 성공을 만들지 않는다.


### 플랫폼15 보완 검증 결과 — 2026-10-22

- 수정 전 RED: `.superpowers/audit-combined-red.log`에서 플랫폼2개(단말등록 endpoint 부재, 미할당 역할자의 private case 열람허용)가 실제 HTTP assertion 실패했다. 같은 실행의 정산5개 실패는 별도 도메인 담당자에게 전달했다.
- 수정 후: `.superpowers/platform-file-community-audit.log`의 PlatformApiTest **17 tests / 0 failures / 0 errors / 0 skipped**, 실제 PostgreSQL Testcontainers. 동시 실행 전체는35개 중9개 실패(File3 endpoint미구현, Community6 회귀)이므로 전체 GREEN이라고 보고하지 않는다. 실패는 root·커뮤니티 담당자에게 전달했다.
- 플랫폼 통과 범위: OFF여도 inbox 보존, SOCIAL 묶기·금융개별, 단말소유/원문token비노출/삭제, typed공식SDK의 RSA서명 OAuth와 실제로컬HTTPv1 전송, 부분실패에서 접수기기중복방지·UNREGISTERED폐기·SENT만기록, 공급자미설정재시도, Quartz JDBC 동일DB재기동 보존,24h1회/72h단계상향, role만으로 상세허용금지·claim경합, 정확금융이의1건/다른이의·전체book거절/운영role회수, 공개결과의 private증빙비노출, 실제POST/COMMENT/MESSAGE 단일콘텐츠조치/신고원문보존/운영자전체방금지, 영향participant별HOLD·보정·회복, 인계후원주최점수HOLD.
- 운영웹 `apps/admin`의 `npm run build` 통과. 메모리세션 기반 실제 API claim→사건상세→정확금융이의만조회→기록저장 흐름을 구현했다. 브라우저 운영자 실제계정/배포 E2E와 공급자 실제수신은 이 빌드 증거에 포함하지 않는다.
- 남은 사항: 실제 FCM 서비스계정·프로젝트·단말에 대한 수신 검증, 사용자 후속정책이 필요한 인계 후 HOST점수 귀속. 이 둘을 코드미구현이나 이미 확정된 제품정책으로 혼동하지 않는다. 정산/커뮤니티 후속 변경 후 전체 통합 회귀를 다시 수행해야 한다.

- root 보호파일 연결 계약: assignedContentEvidence(actor,contentId,contentType)는 현재 역할이 유효한 정확한 handler_id와 신고 대상 ID/종류만 검사한다. 종료된 처리 이력의 같은 증빙 열람은 유지하되 전체 모임·글·방 열람권한을 부여하지 않는다. 개인정보 근거 보존을 위한 ‘읽기’와 재처리 권한은 분리한다. 이 연결 추가 후 회귀는 다음 통합 실행에서 다시 확인한다.
- FinanceCaseAccess의 canRead/canResolve 분리도 반영했다. 종료 사건의 정확 담당자+현재 유효 역할은 당시 이의 증빙을 읽을 수 있으나, canResolve는 아직 활성인 정확 할당만 허용한다. 역할 회수 시 읽기도 실효된다. 당사자/현재 책임자의 기존 권한은 금융 도메인이 그대로 관리한다.

- 보호사진 후속 감사(발견 시 미구현, 아래 RED 확인 후 보완으로 대체): 현재 community_post_photo는 글 편집 시 교체되는 현재 연결이라, 신고 당시 사진을 나중에도 확인하려면 case별 파일ID 스냅샷이 필요하다. 텍스트 content_snapshot/정확 contentId 할당만으로 삭제된 사진 연결을 복원하지 못한다. root에 platform_case_photo+assignedFileEvidence 연결과 실제 업로드→신고→편집/조치→정확 담당자 과거사진 조회 회귀를 제안했다. 이후 root 승인·실제 FileApiTest 네 번째 RED 확인을 거쳐 아래 사진 스냅샷 코드로 보완했으며 최종 회귀를 기다린다.
- 운영웹 보호 증빙은 bearer GET `/files/{id}`를 통해서만 받아 임시 Blob URL로 열고 내려받는다. 사건/세션 변경·로그아웃에 URL을 폐기하며 세션 변경 전 진행 중이던 응답은 버려 민감정보를 되살리지 않는다. 브라우저 빌드 통과, 실제 운영자 브라우저 E2E는 아직 별도 검증이다.

## 동시성 재대조(12/공통 STATE-MODEL)

Community 감사에서 실제 FK 교차쓰기와 actor FOR UPDATE의 교착 가능성을 발견했다. 서로 다른 사용자의 독립 명령이 상대방 FK를 만들 때 두 사용자키잠금이 순환한다. 요구는 멱등·독립 동시작업 안정성, 구현계획은 own actor직렬화이지 다른사용자 PK참조까지배타차단하는것이아니다. 실제교차membershipFK 재현테스트를먼저추가해 실패를확인한뒤 immutable계정PK는 FOR NO KEY UPDATE로직렬화해FK KEY SHARE와호환되게수정할계획이다. SQL접근변경은권한을늘리지않고 같은actor직렬화·버전·멱등원장을유지한다. 아직수정/통과로기록하지않는다.

테스트 증거가 다음 선택실행에 덮이지 않도록 scripts/run-api-check.ps1이 실행별 로그/XML을 .superpowers/checks/label에 보관하고 Gradle실패코드를그대로반환한다. 테스트대역/실제DB의범위는 결과별기록한다.

### 신고 당시 사진 이력 보완 — RED 확인 후 구현

root가 P10의 정확한 증빙 이력 범위로 승인했다. `.superpowers/checks/audited-integration-01`에서 실제 업로드→모임장 글/사진→신고→운영자 claim은 성공했지만 글 편집으로 현재 사진 연결이 사라지면 동일 담당자의 사진 GET이403이었다(기대200, FileApiTest 네 번째 사례). 따라서 case별 file ID와 원래 position을 복사하고, 글 row lock으로 본문/사진 스냅샷을 함께 일관되게 보존한다. V4는 platform_case_photo(case_id FK,file_id,position)까지만 생성하며 파일 테이블 FK는 root V7이 소유한다. 현재 유효 역할의 정확한 handler는 활성/종료 사건의 그 사진만 읽으며, 당사자 case DTO의 photoIds 외 공개 DTO에는 사진ID를 넣지 않는다. 실제 blob 조회는 root FileService가 assignedFileEvidence를 호출해 검사한다. 같은 실행의 Platform17개는 추가 read/resolve/content predicate까지 모두 통과했다.

## 통합 검증 증거(아카이브)

.superpowers/checks/audited-integration-01: Finance17/17, Platform17/17, Community16/17(SOCIAL연결누락재현1실패), File3/4(신고사진편집후증빙연결소실재현1실패), Identity 교차FK1/1. 총56중54통과·의도한RED2. SQL교착가설은 실제교차FK테스트가통과했으므로 Store/Commands잠금을 근거없이바꾸지않는다. 기존잠금유지·재현테스트보존으로가설을닫는다.

이후 Community의동일TX SOCIAL trigger, Platform원본사진snapshot+File정확사건접근을수정했다. 아직다음재검증전이며 전체GREEN으로표시하지않는다. 신고원본문·사진순서·fileIDs는수정전snapshot이고 담당자역할/정확사건할당이현재유효할때만조회한다. 원게시글의현재사진연결이삭제되어도정확사건증빙은보존한다.

## 선지출 자금 출처·자기부담 중복 대조(구현 전 계획)

기존 raw calculator는 비용분담/외부납부를 계산하지만 실제지출지급자의 선지출기여를 구분하지 않았다. 참석0명 주최자가100원자비지출한경우 자기부담100원을다시납부요청하거나반환채권100원을만들면중복이다. 정상100원지출/자기부담50원/기타수금0이면순미회수50, 기타참가자50원을본인계좌로이미받았다면회수가능분과상계하여0이돼야한다.

수정계획: 지출의 funding portions(지급자·PERSONAL/EVENT_FUNDS·금액)를명시적으로입력받아합계를보존하고, 실제은행입금과개인지급기여를다른필드로보존한다. 신규에출처기본값을넣지않고이전자료UNKNOWN은분류전인계막음. 사용자최종부담 B, 외부실납부D, 실제일반환불R, 개인자금지출P, 선지출실제반환/명시적자가회수A의경제순액은 B-D+R-P+A로대조한다. 일반환불/선지출채권을중복생성하지않고자기부담과상계한다. 자금보관액은실제수령/모인돈지출/실송금과인계·적립·반환의사실만으로관리한다.

같은담당자가보관금에서자기선지출을회수하는SELF_RECOVERY는외부이체완료가아닌명시적내부상계기록(금액·근거·주체·시각)으로만처리한다. 자동은행거래/자동수령으로꾸미지않는다. 일반환불의무는이상계로소멸하지않는다. 해당계산은Finance단일canonicalreconcile에서제공하며Reserve는실제이동사실만보충한다. 다섯예제·혼합출처·정정·인계·실반환회귀먼저작성후수정한다. 이불일치가해결되기전PR13을머지하지않는다.

### 플랫폼·보호사진 최종 재검증

`.superpowers/checks/platform-file-final`에서 **PlatformApiTest17 + FileApiTest4 =21개 전부 통과(실패0·오류0·skip0)**. 신고 당시 사진 스냅샷·현재 글의 사진 연결 삭제 뒤 정확 담당자 파일조회 유지/무관자거절, 종료된 금융 사건의 증빙 읽기/재처리 금지 분리, 역할 회수 실효를 포함한다. root FileService의 assignedFileEvidence 연결과 V7 파일 FK를 함께 적용한 현재 소스다. 운영웹도 보호파일 bearer→임시BlobURL·세션변경 폐기와 claim한 목록 버전 동기화를 포함해 `npm run build` 통과했다. 초기 runner의 -File 배열 인수 전달 실패(no tests found)는 올바른 pwsh -Command 배열 호출로 고쳐 실제21개를 실행했으며, 완료 근거는 위 archive의 두 XML과 성공 run.log다. 전체 공유 프로젝트의 다른 도메인 후속 변경은 root의 최종 통합 회귀로 확인한다.

### 인계14 추가 대조·결정 — 구현 전

P07의 실제 수령 후 권한 이전과 잔여 의무 보존을 기준으로 확인했다. 기존 인계는 client inventoryAmount를 사실로 취급하여 없는 현금을 만들거나 실제 보관금을0원으로 누락할 수 있었고, 앞선 테스트도 실제 입금 없이100원 인계를 허용했다. canonical Finance.reconcile의 서버 현금/채권/일반환불/미확인 거래 명세와 정확히 대조하고 UNKNOWN 출처·음수 현금은 인계를 막는다. 실제 정정으로 드러난 현금 부족은 기존 실제송금/지출을 삭제하거나 개인자금으로 재분류해 숨기지 않고 표시한다.

추가 전이 결정: 선지출 REQUESTED 및 적립 PROPOSED 업무는 명세에 포함하여 새 담당자가 이어 처리하고 createdBy와 실제 sentBy를 분리한다. SENT는 실제 이동이므로 경제적 회수에 반영하되 기존 채권자의 CONFIRMED 전 미확인 수령 의무는 남긴다. 인계로 채권 원본을 복제하지 않는다. 자기회수는 명시적 SELF_RECOVERY로만 기록하고 은행 거래 식별을 만들지 않는다.

삭제/접근 결정: 실제 송금 대기 중인 인계 후보·제안자나 선지출 수령 확인 당사자의 계정 삭제를 막아 확인할 주체를 잃지 않는다. 후보 자격은 실제 송금 직전 다시 검증한다. 계정은 활성인 상태에서 적격 보관담당 후보가 이미 수락하고 실제 송금까지 받은 경우, 이후 모임 탈퇴만으로 그 실제 수령 확인 접근을 없애지 않는다. 이는 P07의 기존 금융 의무 접근 보존을 같은 실제 인계 의무에 적용한 구현 해석이며 일반 모임 관리권한은 주지 않는다. 0원 인계는 실제 송금이 없으므로 완료 시 현재 후보 자격을 검증한다. 전체 근거/제한은 RESERVE-API.md에 모은다.

### 앱 사용자 선택 API 대조 — 구현 전

P10의 모임 내부 정보 제한·P11 개인/그룹 대화와 이슈16의 실제 사용자 선택 흐름을 비교했다. UUID 수기 입력은 실제 앱 흐름이 아니므로 GET /me/contacts를 추가한다. 기존 알려진 DM 관계 정의와 같은 활성 모임·같은 확정 이벤트(주최자 포함)·상호 팔로우만 후보로 제공한다. 전역 사용자 목록이나 전화번호 검색을 새로 만들지 않는다. 본인·비활성 계정·양방향 차단 상대 제외, 프로필 닉네임/ID만 반환, 닉네임+ID 고정 정렬, offset/limit(1..200)은 기술 선택이다. 선택 결과 자체는 송금/인계 권한을 부여하지 않고 각 명령에서 현재 권한을 다시 검사한다. 관련자/무관자·차단·페이지·민감 필드 미노출 HTTP 회귀의 실제 실패를 확인한 뒤 구현한다.

### 인계 후 입금 증빙 당사자 접근 — 구현 전

P07/P10의 기존 금융 의무·당사자 접근 보존과 FileService를 대조했다. 기존 입금 확인자(processedBy)는 인계 뒤 현재 담당자가 아니라는 이유로 본인이 확인한 송금 증빙에 접근하지 못했다. 해당 payment_report의 불변 processedBy에만 정확히 증빙 읽기를 유지하며, 모든 정산/다른 참가자의 증빙 권한을 원주최자에게 추가하지 않는다. 신규 담당자·해당 납부자·기존 해당 입금 확인자 허용/무관자 거절의 실제 HTTP 회귀를 먼저 확인한 뒤 수정한다. 이의 역시 현재 담당자와 별도로 사건 생성 당시 상대 당사자를 불변 보존해야 하며 Finance 담당자와 생성 계약을 맞춘다.

### 운영 큐 역할별 앱 동작 대조 — 구현 전

P10의 정확 사건 담당자·당사자 구분과 이슈15/16 역할별 처리 화면을 비교했다. 큐에는 요청자와 처리 후보가 함께 오지만 기존 summary에는 역할별 실행 가능 여부가 없어 앱이 UUID 추정/403 응답에 의존했다. 기존 visible/eligible/processor와 동일한 현재 판정으로 isRequester/canReadDetails/canClaim/canDecide 네 bool을 summary/detail에 제공한다. 새 권한을 주거나 reason/증빙을 summary에 추가하지 않는다. 다른 유효 담당자가 이미 맡았으면 canClaim=false, RESOLVED면 canClaim/canDecide=false이고 정확 담당자 읽기는 유지한다. 실제 POST 권한 검사는 매번 유지하며 bool은 버튼 안내용이다. 요청자/미배정 후보/정확담당/다른후보/종료사건 HTTP 회귀를 먼저 실패 확인한다.

### 실제 사실과 새 자금 사용 분리 — 인계14 후속 확정

root가 원래 사용자 P07/P08 요구에 필요한 범위로 확정했다. 실제 지급/입금 사실 정정은 trusted FinancialChanged 원인 FACT_CORRECTION으로 보존하고, 기존 적립 출처보다 실제 적격금액이 줄면 unbackedAmount를 노출한다. 부족 해결 전 신규 사용·해산·관련 인계를 막는다. 일반 배분/선택 변경(ALLOCATION_CHANGE 기본)은 기존 적립 출처를 지우거나 일반 환불을 적립으로 바꾸지 못하도록 원래 동기 가드를 유지한다. 실제 이미 발생한 송금·수령 확인을 영원히 기록하지 못하게 막지 않는다. 반환은 보관 담당 실출금→이벤트 담당 실수령 확인으로 분리하며 수령 전 출처 earmark를 해제하지 않는다.

인계 송금 후 book 변경 시 실제 수령을 RECEIVED_STALE로 기록하고 현금 이동만 반영한다. 권한은 원담당에 남으며 후보에게 최신 전체 명세(원담당 보관금/후보 이미 수령금/채권/일반환불/미확인 업무)를 다시 제시한다. 원담당은 현재 남은 자기 보관금만 새 인계로 제안하고 이미 송금한 금액을 다시 요구하지 않는다. 현재 명세를 후보가 다시 수락하고 추가 현금 실제 수령 또는0원 확인을 마치면 권한을 이전한다. 기존 stale 인계는 사실 원장으로 남기고 SUPERSEDED 처리한다.

후보가 변경 명세를 거절하면 RECEIVED_STALE 인계에서 후보 실제 보관금과 아직 반환하지 않은 원래 수령금 이하로 반환을 요청한다. REQUESTED는 현금을 바꾸지 않고 SENT 실제 송금은 후보 보관금만 차감한다. 원담당의 CONFIRMED 실수령 때 원담당 보관금을 증가시킨다. 후보/원담당 확인 전 삭제를 막으며, 반복 송금·초과 반환·제3 후보에게 미해결 보관금 책임을 숨기는 인계를 거부한다. 이 분리는 정산 권한을 미리 주거나 외부 송금을 자동 완료하는 동작이 아니다.

### 앱 선택·입금 증빙·인계 추가 검증

contacts-file-green-reserve-stale-red 아카이브에서 contacts HTTP1개와 File 원 입금 확인자의 정확한 증빙 접근 HTTP1개는 통과했다. 같은 실행의 Reserve 신규3개는 기대한 실제 실패였다: 송금 후 명세 변경 시 실제 수령 확인까지 STALE_INVENTORY로 차단하는2개, 실제 입금액 정정을 RESERVE_REVERSAL_REQUIRED로 거부하는1개다. 이 실패를 근거로 실제 사실 보존·새 명세 재수락/반환을 수정 중이며 전체 통합 통과를 의미하지 않는다.

사용자 확정 그룹 DM과 기존 주최자 선지출 반환 의무를 화면 정본에 반영했다. catalog는51→57개이며 신규 GROUP_CREATE/GROUP_INVITE/GROUP_MEMBERS/ADVANCE/SELF_RECOVERY/HANDOVER_REVIEW, 기존CHAT/EXPENSE/HANDOVER와 회원/모임 시나리오를 함께 갱신했다. 최신57개 HTML,12개 와이어플로우,변경9개 실제 full-page JPEG와 manifest SHA256을 동기화했다. 정적 목업과 실제 앱 검증을 구분하고 외부 인증/실이체 미연동 목업 표기를 유지한다. --screen-refresh는 새 구현 문서/스택 설명을 오래된 생성기 baseline으로 덮지 않기 위한 생성 범위 옵션이다. check-handoff는 apps의 Vite/Flutter 소스·빌드파일을 정적 설계 페이지로 오인하지 않도록 apps를 제외하고, 실제 앱은 각 빌드/테스트로 검증한다.

### 개인 계좌 준비 계약 — 구현 전

BANK-ACCOUNT-PLAN.md의 개인 계좌 등록 부분을 공급자와 분리해 먼저 준비한다. V8은 개인 계좌의 검증 이력을 append 보존하고 current 한 건만 둔다. 계정 단위 Commands 잠금·멱등/버전, 원문 AES-GCM, 본인 조회는 accountMasked/holderMasked만. 공급자 실패 때 기존 current/버전/이력을 변경하지 않는다. 이는 등록·교체 기술 계약이며 실제 기본 verifier 어댑터는 사용자 공급자 답변 전 미완료503 상태를 유지한다. BankApiTest는 명시적 test-only verifier와 실제 PostgreSQL/HTTP로 검증하며 실계좌 성공을 주장하지 않는다. 송금 안내의 전체 계좌는 이후 정확 업무의 현재 송금 당사자 검사에만 연결하며 전역 타인 계좌 GET을 만들지 않는다.

bank-platform-apple-green-01에서 Platform18/18·Apple3/3 통과. Bank 등록/멱등/암호화/거절 보존은 진행됐으나 GET 동일 응답 비교에서 DB timestamptz의 마이크로초 정밀도와 초기 Java 나노초 차이로1개 실패했다. 등록 verifiedAt을 DB 정밀도인 MICROS로 고정해 동일 상태를 안정적으로 읽도록 수정하고 재검증한다. 실패 원인은 공급자 성공이나 DB 암호화 오류가 아니며 아직 Bank 최종 통과로 표시하지 않는다.

인계 후보 선택기: 모바일 UUID 수기 입력을 제거하기 위해 GET /events/{id}/handover-candidates를 현재 담당자만 읽는 배열로 제공한다. 새 권한을 만들지 않고 기존 서버 candidateEligible의 활성 계정+현 관리자 또는 everConfirmed 참여 이력을 그대로 재사용한다. 본인은 제외하고 개인정보가 아닌 {id,nickname,departed}만 반환한다. 취소·모임 탈퇴 이력이 있어도 기존 이벤트 참가자는 가능하며 개인 차단은 금융 권한에 영향이 없다. 무관한 일반 모임 부원·삭제 계정은 제외한다. 모임장/보관 담당 후보는 기존 모임 부원·역할 목록으로 충분하므로 별도 전역 후보 API를 만들지 않는다.

개인 계좌 등록 Bank1은 bank-green-candidate-red에서 HTTP/PG 통과했다. 다음 송금 안내는 정확한 ACTIVE 납부요청의 납부자→현재담당자, REQUESTED 환불의 현재담당자→수령자에게만 전체 검증 계좌를 제공한다. 금액은 Finance.requestView의 remaining을 그대로 사용하고 별도 수학을 만들지 않는다. 모임 탈퇴/개인차단은 기존 금융 당사자 관계를 없애지 않는다. 인계 뒤 이전 담당자는 새 송금 안내 권한을 잃고 현재 담당자의 수령 계좌를 사용한다. 납부 SUPERSEDED/완료·환불 SENT/CONFIRMED는 송금 안내 신규 조회를 막는다. 이는 이미 끝난 지급 기록 삭제가 아니다. 실제 송금·수령 완료를 자동 기록하지 않는다. 정확 당사자/무관부원/탈퇴/인계/종료업무 HTTP 회귀 실패를 먼저 확인한다.

### 기존 참고 PR17 재대조 — 병합 전

별도 managed worktree core-reference에서 기존 issue/11-core를 유지하고 최신 origin/develop을 일반 merge했다. 충돌은 Java25/Gradle 서버 CI와 Node 참고검증을 함께 보존하고 생성기 양쪽 참고 링크/서버설명을 유지하는 방향으로 해결한다. 사용자Java서버선택을 되돌리지 않는다. 순수JS코어는 실제금융상태/선지출/인계 서버를대신하지않는 참고예제다. 원 #11설계/계획은 '금액 누적도 안전정수 이내'를 요구하지만 서로다른사용자의 실제입금·환불 합계는 경계가없었다. MAX_SAFE_INTEGER+1 합계의실패회귀를 먼저 확인하고 전 이벤트 실제확정 ledger누적검사를 추가한다. unconfirmed신고를실제수금으로계산하지않는기존정책은유지한다.

Finance27 통과 후 파일 연계에서도 원 이의 상대방 counterpartyId를 DISPUTE 첨부파일 접근에 반영한다. 별도 권한 체계를 만들지 않고 정확 증빙에 연결된 사건의 counterparty_id만 판정하며, 원주최자에게 후속 사건의 증빙 전체를 공개하지 않는다. 기존 사건 허용/후속 사건 거절/현재 담당자는 둘 다 허용의 HTTP 회귀를 추가하고 실제 RED 후 수정한다.

### 인계14 추가 현금·정확 수령자 삭제 가드

P07 인계 완료 후 과거 입금 사실 정정이 이전 processedBy의 보관금을 증가시키는 경우를 보존한다. 별도 권한 인계를 반복하지 않고 현담당자에게 보내는 CUSTODY_TRANSFER를 기존 실제 이동 원장으로 기록한다. 목적지는 서버의 현 responsibleId로 고정하고 본인 실제 보관금에서 이미 예약한 출금을 뺀 한도 안에서 요청한다. SENT는 이전 담당 보관금 차감, 현담당 CONFIRMED는 현담당 보관금 증가이며 responsibleId를 바꾸지 않는다.

일반 환불 REQUESTED/SENT 수령 당사자 계정 삭제도 확인할 주체 소실을 막기 위해 거부한다. CONFIRMED 이후 해당 가드는 사라진다. 다른 사람이 환불을 보내지 않아 삭제가 막히면 기존 처리 요청/상향 경로를 사용하며 임의 환불 완료로 우회하지 않는다. 미납 참가자 전체의 계정 삭제 차단, 채권 포기, 타인 수령 위임은 이번에 새로 확정한 정책이 아니므로 확대하지 않는다.

모바일 대조에서 추가 발견: 일반 reserve DTO에 full holderName이 남아 P09 별도 송금 맥락 원칙과 충돌하고, 모임을 나간 현 이벤트 담당자는 전체 reserve 읽기 권한이 없어 정당한 적립 제안에 필요한 account version을 구할 수 없었다. 전자는 일반 DTO에서 제거하고 승인된 transfer-instructions에만 유지한다. 후자는 현 이벤트 담당자만의 좁은 reserve-transfer-context(버전·해당 출처 가용액·마스킹 계좌·허용 여부)로 해결하며 전체 잔액/입출금/모임 권한을 주지 않는다. 두 사례는 실제 RED 확인 후 수정한다.

독립Finance13 검토는28개통과만으로머지하지않고두구체P2를추가재현한다. zero-attendee hostContribution 청구를받은비참가원주최자의실납부배분이참가여부gate로거절되고, 비참가자PARTICIPANT점수발행도피해야한다. 혼합PERSONAL기여+외부입금은개인지출시각미상/지연을무시하고ON_TIME으로판정하던경로가있다. 필요한금액의실제시각을함께평가하고미상은보류하는회귀후수정한다. 새기능확장이아닌P06/P12정본일치수정이다.

ClubService.clubView는membershipStatus/role만반환해모임해산후에도OWNER·ACTIVE멤버십만본앱이작성버튼을잘못표시했다. 실제Club.status를동일DTO에추가하며새권한/멤버십변경은없다. ACTIVE/DISSOLVED상태와OWNER역할보존의HTTP회귀실패후필드를추가한다.

## 독립 리뷰 후 Finance P2 대조 (구현 전 회귀 계획)

P05 참석0명 원주최 부담 및 P07 선지출 채무 보존은 원주최자의 참가 여부와 별개다. 기존 saveAllocations가 모든 납부자에게 everConfirmed를 요구하여 실제 hostContribution 납부를 막는 불일치를 확인했다. 정확한 원주최자·해당 차수의 현재/불변 정산 hostContribution 근거에 한해 명시 HOST_CONTRIBUTION 배분을 허용한다. 원주최자를 참석자로 추가하거나 자기계좌 간 가짜 입금을 만들지 않는다. 실제 초과입금은 일반 입금과 같이 보존하고 초과분은 일반환불로 남긴다. 현재 hostContribution이 정정으로0이 된 뒤에도 불변 원본/원배분 근거로 원래 납부 사실을 정정할 수 있어야 한다. 납부 사실만으로 비참가자에게 PARTICIPANT 점수를 생성하지 않는다. 기존 HOST 판정은 유지한다.

P12의 기한 내 실제 납부 완료와 시각 미확인 보류는 실제 은행 입금과 자기부담을 충족하는 PERSONAL 기여에 함께 적용한다. 기존 코드는 은행 입금이 존재하면 PERSONAL 시각을 무시하여 B100/P50(미상 또는 늦음)+기한내 입금50을 정상으로 판정했다. 필요한 실제 기여가 기한내 충족됐는지 금액 합계와 각 실제 시각으로 판정하고, 미상 시각이 필요한 경우 HOLD, 실제 늦은 충족은 LATE/RECOVERED로 처리한다. 기한내 알려진 입금만으로 부담을 충족하면 불필요한 미상/늦은 초과기여 때문에 불리하게 만들지 않는다. 실제시각을 임의 등록/신고시각으로 채우지 않는다. review* HTTP 회귀5개를 먼저 작성하고 RED 이후 최소수정한다. 별도 EventService.financial ownFinancialRelationship 경로는 이미 존재하여 코드 미확인 권한 확대 제안은 반영하지 않는다.

### 인계14 최종 회귀 증거 — 2026-10-22

.superpowers/checks/reserve-bank-green-review-red/TEST-com.moishow.identity.ReserveApiTest.xml: 실제 PostgreSQL Testcontainers ReserveApiTest 17 tests / 0 failures / 0 errors / 0 skipped. 실제 입금 없는 허위 현금 명세, 자기부담을 뺀 canonical 선지출 채무, SELF_RECOVERY, 실제 선지출 반환·수령 확인, stale 송금의 실제 수령/최신 재수락/거절 후 실제 반환, 인계 뒤 과거 입금 정정으로 남은 보관금의 현담당 추가 인계, 사실 정정·source 부족 표시·실반환 확인, 보관담당 송금 중 재사용 방지, 명시 모임장 수락·해산, 후보 predicate, 정확 ordinary refund 수령자 삭제 가드, 일반 예금주명 제거 및 탈퇴 담당자 전용 적립 맥락을 검증했다.

앞선 finance-reserve-bank-integration-01의 Reserve401 다수는 권한 누락이 아니라 Spring proxy의 내부 필드(.json/.events) 직접 참조 NPE였다. 각각 ObjectMapper/EventService를 직접 주입하고 실제 HTTP로 재검증했다. 테스트의 ACTIVE 요청 필터도 공개 상태 UNPAID/remaining 계약에 맞춰 고쳤으며 정책/계산을 테스트 오류에 맞추지 않았다.

정본과 비교하여 모인 돈·개인 선지출·경제 순채권은 Finance 단일 계산을 사용한다. ACTOR_FALLBACK 실제 거래 식별의 서로 다른 은행 계좌 구별 한계, 기본503 은행 공급자 어댑터/공식 은행 identity 미구현, 실은행·배포 검증은 남아 있다. 같은 실행의 별도 Finance review RED를 포함해 서버 전체가 통과한 것은 아니므로 전체 회귀와 남은 환경/구현 항목은 root 통합 결과로 판단한다.

검증 갱신: reserve-file-green-privacy-club-red에서 File6/6 통과(counterparty사진 포함), Reserve기본15통과+privacy2정확RED, Club.status누락RED확인. 수정뒤 reserve-bank-green-review-red에서 Reserve17/17 및 Bank2/2 통과했다. Finance 독립검토 혼합시각2개는 실제RED, host납부회귀는 인계fixtureactualAt 누락400으로 먼저 실패했으므로 아직 allocation거절 재현 증거로 쓰지 않는다. fixture수정후정확 RED확인중이다. 과거28개Finance 통과와새review 회귀는구분한다.

PR17은독립검토P1/P2없음, Node22개·정적51개검사와exacthead67b2381의GitHub Spring/handoff4checks SUCCESS후 develop d0ab62f에일반merge완료했다. 기존issue/11-core브랜치는삭제·재작성하지않았다. 현재주작업issue/13-settlement의미커밋코드는보존하며추후develop새기준을병합한다.

Finance 리뷰 회귀 근거: `reserve-bank-green-review-red`에서 혼합 기여 미상/늦음2개는 실제 ON_TIME 오판정 RED를 확인했다. 원주최자 테스트의 첫400은 인계 확인 actualAt/reference 누락 fixture였으므로 배분 재현으로 세지 않았다. fixture 수정 뒤 `review-host-fixture-red`에서 실제 verify의 INVALID_ALLOCATION400을 확인했다. `review-personal-correction-red`는 PERSONAL100→귀속시각 불명 -50 정정 뒤 실효P50+정시 D50을 ON_TIME으로 오판정하는 실제 RED를 확인했다.

판정 구현 결정: 최초 등록 후 실제 필요한 총 기여는 canonical B+R+A(부담+실제 일반환불+실제 선지출 회복)이고, 그 기여의 은행 실납부 D와 실효 개인지출 P를 시간별로 비교한다. 최초 등록 전에는 기존 활성 billing 목표/실제 은행 납부를 유지한다. 은행은 원 요청의 명시 기한, PERSONAL은 해당 차수의 요청 기한 또는 최종 요청 기한을 따른다. 기한 내 알려진 기여만으로 필요액을 충족하면 미상/늦은 초과분을 무시한다. 미상 기여로 정시 여부가 바뀔 수 있으면 HOLD다. 음수 PERSONAL 정정은 round+actualPaidAt의 같은 기여군에서 차감하고, 음수 시각이 없거나 동일 기여군을 초과해 어느 원본을 줄였는지 특정할 수 없으면 실효P 전체의 시각을 불명으로 두어 HOLD한다(실제 금융 원장과 P 금액은 유지). 이 가정은 시각을 임의로 빨리/늦게 귀속하지 않는 P12 보류 원칙이다. HOST_CONTRIBUTION은 취소비 실수령으로 재분류하지 않는다. source 적용 후 Finance 전체34개 회귀를 검증한다.

구현계획의 이슈별독립PR 가정은 실제교차회귀와맞지않아 REMAINING-EXECUTION.md에서서버통합PR+앱별도PR로조정했다. 요구기능/권한/인수기준을줄이거나테스트를mock으로대체하지않는다. HOST_CONTRIBUTION 비참가자납부는실제인계·Platform역할검증과함께검증해야하고, 운영신고사진/채팅권한도실제Community/File연결이필요하다. 공유작업트리에서다른사람수정파일을임시삭제·브랜치전환하지않고, 도메인별완료커밋을선택해원격통합PR에제시한다.

Reserve독립검토의3개P2를현재17개통과와별도로추가재현한다: 이미요청된지출의출처부족후실행, REVERSAL실수령대기당사자의인계후계정삭제, 실제보관담당교체뒤참조번호충돌. 실거래확인사실을기록하지못하게막는것도금지이므로정상신규사용과이미발생한거래기록은명확히분리하고같은기존담당자의권한·실제시각/참조/사유원장을유지한다. 새비즈니스권한이아닌기록보존/출처제약동시충족을위한경로선택이다.

리뷰 보완 결과: `finance-review-green-01`에서 Finance34개 전체 GREEN(기존28+리뷰6). 원주최자의 실제150/의무100/환불50, 비용0 정정 뒤 원배분 시각정정/환불150, 비참가자 PARTICIPANT 없음 및 혼합 시각6개가 통과했다. testClasses 이후 known(on+late) 합계가 필요액보다 부족해 미상 기여가 필요한 부분납부도 HOLD하는 한 줄을 보강했으므로 최신 소스의 root 통합 회귀를 최종 근거로 사용한다.

### 독립 인계14 리뷰 P2 — 수정 전 재대조

P07은 실제 수령 확인할 당사자를 유지해야 한다. REVERSAL/TRANSFER_PENDING의 recipientId는 송금 당시 담당자로 고정되어 이후 책임 인계와 별개다. 현 담당자 조회만으로 삭제를 허용하면 유일한 실제 수령 확인자가 사라지므로 해당 불변 recipientId의 미확인 반환을 정확히 차단한다. 실제 수령 뒤 남은 보관금도 현담당자에게 실제 이전하여0원이 된 뒤 삭제 가능함을 회귀로 확인한다.

P08 출처 부족 시 신규 적립금 사용 금지와 실제 이미 발생한 사실 보존을 분리한다. 정상 SPEND/DISSOLUTION execute는 unbackedAmount=0이어야 한다. 이미 발생한 출금은 같은 보관 담당자의 명시적 record-actual에서만 실제 시각·거래 식별·사유와 함께 기록하며 요청 금액/원래 purpose는 바꾸지 않는다. actualRecordReason, actualRecordedAt/By, 당시 unbackedAtActualRecord를 남겨 부족 중 사용을 숨기거나 정당화하지 않는다. REVERSAL은 부족 수정 목적이므로 막지 않는다. 모바일은 '이미 발생한 거래 기록'으로 표시하고 execute 오류를 자동으로 우회하지 않는다.

P09의 은행 identity 미확정 원장에 맞춰 reserve_entry 중복 범위도 변경해야 한다. 교체 가능한 reserve_account 행 ID를 은행 계좌 namespace로 쓰지 않는다. 불변 실제 confirmedBy(actor fallback)+confirmedReference로 중복을 검사하여 서로 다른 실제 확인자가 동일 은행 reference를 쓰는 경우를 분리하고, 같은 actor 재사용은 거부한다. 임의 client namespace는 받지 않는다. 기존 ACTOR_FALLBACK의 동일 actor 여러 은행 계좌 구분 한계는 유지하여 공개한다.

독립File 검토에서 정확case사진snapshot을추가한뒤에도 기존assignedContentEvidence(postId) 우회조건을남겨, 담당자가신고후원문에새로추가된사진까지볼수있는실제P2를발견했다. 기존사진A snapshot유지/신규사진B는담당자403·현재모임부원200/운영역할회수후A403을 실제글수정API로추가회귀한다. FileService는평소canReadPost 또는정확assignedFileEvidence만으로허용하고포스트ID대리권한으로후속사진을공개하지않도록RED확인후수정한다.

## 독립 리뷰 추가 P12 개인 기여 시각 정정 (RED 계획)

원래 P12는 이벤트·역할별 중복 가점을 금지하면서 실제 사실 오류는 정정하도록 요구한다. Finance.revise의 amount0+fundings[-기존금액 oldAt,+같은금액 correctedAt]는 원본 보존 시각 정정을 허용하지만 기존 PARTICIPANT 판정의 명시 무효화가 없어 Platform once-per-role 보호가 정시↔지연 재판정을 무시하는 불일치를 코드에서 확인했다. HTTP 회귀2개로 +1→-1 및 -1→+1을 재현하고, 정확히 영향을 받은 user/event/PARTICIPANT만 ERROR_CORRECTED 후 canonical assessParticipant를 호출한다. 다른 참가자·HOST의 점수/감사 행을 리셋하지 않는다. 금액·실제 자금 원장·HOST 판정 귀속을 새로 바꾸지 않는다. production 변경은 실제 RED 이후 진행한다.

동일 리뷰의 화면 계약 결정: HOST_CONTRIBUTION 선택은 이름 추정이나 전체 참가자 권한 확대 대신, 각 기존 비공개 report 응답의 allowedAllocationKindsByRound로 제공한다. 실제 report.userId와 정확 round의 기존 saveAllocations/hostContributionBasis 관계 판정을 재사용하며, 원주최자 긍정 사례·일반 참가자 HOST 불가·무관 차수 누락·외부인 finance 접근 거부를 회귀 검증한다. manager/해당 납부자/원확인자만 reports를 읽는 기존 필터는 변경하지 않는다. source는 DTO와 동일 validation helper를 공유하고 현재/불변 근거를 동일하게 사용한다.

전체 build full-server-audit-red-01은158개실행,146개통과·12개실패·오류/skip0이다. 의도한회귀는Finance시각정정/배분힌트4,Reserve독립P2 3,File후속사진1,새Profile3이며 별도Platform scanner NPE1도발견했다. 이값을전체GREEN으로표시하지않는다. Platform스택은수동legacy VERIFIEDreport의processedBy=null을Finance.reconcile TreeSet에넣는원인으로확인됐다. 임의현재담당자를역사적보관자로만들지않고unknown을표시해funding.ready=false·nullactor제외로안전하게처리하며시각판정은실제확인시각에따른다. File정확snapshot밖의post후속사진우회는실제403/200 RED후제거했다. Profileavatar사례는LOCAL_FILE_STORAGE_DEV_ONLY 503으로아직실제profile논리에도달하지않았으므로테스트전용dev저장환경을고친후재현한다(운영File권한완화금지).

추가 리뷰 실제 RED/최소수정: `full-server-audit-red-01`의 Finance 개인시각 양방향은 HTTP200 및 초기 점수 확인 후 최종 -1 기대/+1 실제, +1 기대/-1 실제로 실패했다. 새 hint와 기존 원주최 hint도 누락 필드의 기대 true/실제 false였다. PERSONAL 기여군(round+actualAt별 signed합계 및 귀속불명 여부)을 변경 전/후 비교하여 달라진 payer의 historical PARTICIPANT만 ERROR_CORRECTED 후 canonical 재평가한다. 동일 사실 반복·다른 참가자·HOST는 무효화하지 않는다. saveAllocations와 allowedAllocationKindsByRound는 같은 allocationKinds helper를 공유하며 기존 private report 필터는 유지한다.

동일 전체 통합 실행에서 Platform scheduler가 기존 SQL fixture의 VERIFIED/processedBy=null 자료를 canonical reconcile에 전달하여 TreeSet.add(null) NPE가 발생한 실제 회귀도 확인했다. 미상 보관자를 현재 담당자로 가정하지 않는다. null actor를 보관자 목록에서 제외하고 해당 실수령이 양수이면 funding.ready=false로 인계를 보류한다. 은행 실제 기여의 금액/시각은 별도로 보존하여 점수 판정을 계속 처리한다. 정상 HTTP 확인은 기존대로 actual processedBy를 항상 기록한다.

`backend-review-green-profile-red` 결과: Finance37개 중36개 GREEN, 새 개인시각 양방향/일반 참가자 hint 회귀가 통과했고 Platform18개 전체 GREEN으로 null 보관자 scheduler 회귀도 해소됐다. 유일한 Finance 실패는 원주최자가 모임장이므로 GET 요청 목록이 전체였는데 fixture가 UUID 순서의 첫 요청을 본인 것으로 간주한 OWN_REQUEST_ONLY403이었다. 요청의 userId==원주최자 ID로 명시 선택하도록 test-only 수정했으며 실제 권한/금융 동작을 완화하지 않았다. 이 한 사례 재검증 후 최종 결과를 기록한다.

### 인계14 독립 리뷰 P2 최종 검증 — 2026-10-22

.superpowers/checks/full-server-audit-red-01/TEST-com.moishow.identity.ReserveApiTest.xml: 기존17 통과, 신규3 실제 RED(오류0). 새 보관 담당자의 동일 입금 reference가 account_id 제약으로409, 인계 후 pending REVERSAL 불변 수령자 삭제가200, 출처 부족 뒤 기존 SPEND execute가200임을 재현했다.

최소 수정 후 .superpowers/checks/backend-review-green-profile-red/TEST-com.moishow.identity.ReserveApiTest.xml은 Reserve20 tests / 0 failures / 0 errors / 0 skipped다. 불변 pending 반환 recipientId 삭제 차단과 실제 수령·현담당자에게 남은 현금 전달 뒤 삭제를 검증했다. 정상 SPEND/DISSOLUTION 부족 차단과 별도 record-actual의 사유필수/미래시각/다른금액/중복은행식별/잘못된담당자 거부, 목적보존, 기록자·기록시각·기록 당시 부족액 audit를 검증했다. 서로 다른 실제 confirmer의 같은 reference 허용, 같은 confirmer의 재사용/앞뒤 공백 우회 거부 및 새 식별로 실제 확인 완료도 검증했다.

신규 권한·client namespace·가짜 은행 완료는 추가하지 않았다. 기존 source 부족과 잘못된 사용을 audit로 남기며 record-actual을 신규 사용 허용으로 취급하지 않는다. 은행 공급자503·ACTOR_FALLBACK의 여러 실계좌 구분 한계는 그대로 남는다. root 최종 전체 build 전이므로 이번 도메인20개 통과를 서버 전체 통과로 확대하지 않는다.

최소 수정 후 남은 원주최자 fixture의 `userId` 명시 선택을 `finance-host-selection-green`에서 재검증하여 단일 사례 실패0/오류0/생략0 GREEN을 확인했다. 새 HOST hint와 실제150/의무100/환불50, 비용0 정정 후 과거 배분 시각정정/환불150, 비참가자 PARTICIPANT 없음까지 통과했다. 최신 backend 실행의36개 통과와 이 단일 통과를 구분해 보존하며, 최종 전체37개/서버 통합 build의 단일 GREEN 증거는 root 최종 실행으로 확인한다. Finance 생산 코드는 그 이후 변경하지 않았다.

최종서버근거: full-server-final-01에서최신V1~V10·Profile3·Finance37·Reserve20·Platform18·Community18·File6·Bank2·Apple3과기존정산/기본경계전부를함께실행해158/158통과(실패0·오류0·skip0), Gradle build/JAR생성성공. 독립P2 fix-closure에서도남은구체P1/P2없음확인. 실제공급자/단말/배포와앱57흐름QA는별도이며코드완료와혼동하지않는다. 운영자웹의JSX는원기술명세React/TypeScript/Vite와달라strict TSX로정리하고동일동작의타입검사+Vite빌드통과했다. 실제버전은공식npm registry조회TypeScript7.0.2/@typesReact19.3.0으로확인·lockfile고정,별도앱QA전이다.

기술명세의 presigned URL/Redis/기계OpenAPI 표현은실제현재구현과구분한다. 현재파일은철회가능한실시간권한검사bearer프록시이며Redis캐시는없고금액/요청제한을DB로검증한다. 기계OpenAPI는아직없고구현계약Markdown/DTO가현재정본임을명시한다. 공개스펙/인프라후속을현재완료로표시하지않으며관련외부/운영준비이슈정리에서추적한다.

## 앱16 모임 소개·가입/합류 요청 계약 대조 — 구현 전 2026-10-22

POLICY P02/P03·모임 시나리오·STATE-MODEL·issue16(ISSUES.md)·MOBILE-APP.md와 실제 screen-catalog의 CLUB_CREATE/CLUB_PREVIEW/JOIN_REVIEW/JOIN_LATE를 대조했다. 현재 서버는 이름/가입방식만 저장하고, 가입 승인/합류 승인만 제공하여 소개·인원 및 거절/이력/메모가 빠져 있다. 이름·가입방식 필수는 유지하며 소개/지역/분류/대표이미지는 선택으로 보강한다. 지역·분류는 자유 텍스트 메타이며 GPS/지도·새 개인정보 권한을 추가하지 않는다. activeMemberCount는 현재 ACTIVE membership 실제 수이며 신청/탈퇴/강퇴 인원을 세지 않는다. 공개/비공개 검색 정책은 사용자 미응답 상태를 유지하고 flag를 만들지 않는다.

기술 결정: 선택 소개1000자, 지역/분류100자, 신청메모/거절사유1000자. 앞뒤 공백 제거 후 길이를 검사하고 선택 null/빈값은 비어 있음으로 처리한다. metadata 갱신은 null 보존/빈문자 지움, 대표사진은 clearImage=true 명시 해제로 한다. 개설·변경 시 요청자가 소유한 personal POST 이미지만 명시 선택하여 가입 전 소개 범위에 재공개한다. 해당 club.imageFileId의 정확 연결만 파일ACL에 추가하고, 내부 게시물/금융/분쟁 증빙 또는 선택하지 않은 개인사진 접근을 넓히지 않는다. 모임장·현재 ADMIN만 수정하며 이미지 교체는 새 요청자 소유 사진이어야 한다.

가입 거절은 PENDING만, 합류 거절은 현재 active 원주최자만 LATE_REQUESTED && everConfirmed=false에 허용한다. 정산 인수자에게 이벤트 운영 거절권을 부여하지 않는다. 거절은 REJECTED 상태로 보존하며 취소/노쇼/비용/점수로 연결하지 않는다. 신청·승인·거절 이력은 별도 행으로 남기고 신청메모/사유는 본인 또는 정확 현재 가입관리자/이벤트주최자에게만 반환한다. 일반 소개/부원목록/정산담당자 참가목록에는 메모/사유를 노출하지 않는다. 가입 재신청은 기존 join 규칙대로 가능하며 초대·강퇴이력·블랙 우선순위가 유지된다. 합류 재신청은 기존 participation의 차수+user unique/409 규칙을 유지하여 임의 재오픈 정책을 발명하지 않는다. 거절과 영구 차단은 구별한다.

ClubRequestApiTest 실제 PostgreSQL/HTTP 회귀3개를 먼저 작성했고 Gradle host lease 조율 후 RED를 확인한다. 이 절은 구현계획이며 검증 완료 주장이 아니다. 공급자503/실공급자·배포 한계는 변경하지 않는다.


## 앱16 금융 조회·브라우저 채팅 계약 보완 — 2026-10-22

PR21/develop743478a의 전체158개 검증과 별도로 앱 계약을 재대조했다. 탈퇴한 현 이벤트 정산 담당자의 reserve-transfer-context에는 해당 이벤트 DEPOSIT의 최소 이력만 추가한다. 다른 이벤트·전체 적립금 원장·잔액·원문 은행참조를 공개하지 않으며, 재시작 후 처리에 필요한 정확 custodianId/닉네임과 reserveVersion을 반환한다.

인계·적립금 담당자 인계·선지출 반환·보관금 이전·인계 반환의 송금 안내 GET은 각 정확 송금자와 불변 수령자, 현재 상태/금액/실제 보관금/최신 명세/후보 자격을 검사한다. 예금주 검증된 계좌만 내부 PersonalBankService로 조회하며 no-store를 적용한다. GET으로 송금 사실을 만들지 않는다. 0원·이미 송금/완료·오래된 명세는 안내를 거부하고 미등록 계좌는409로 표시한다. 선지출 요청의 가용금액 계산에서는 자기 요청의 예약금만 한 번 제외해 이중 차감하지 않는다. client 계좌 ID로 거래 중복 범위를 바꾸지 않는다.

브라우저 채팅은 기본 same-origin을 보존하고 명시 CHAT_ALLOWED_ORIGINS의 정확 http(s) origin만 추가한다. wildcard/path/query/userinfo는 거부하며 별도의 STOMP bearer 인증은 계속 필수다. Native Origin 없음은 기존 동작을 유지한다. 광범위 CORS/무인증 채팅으로 우회하지 않는다.

mobile-contract-followups-red-01의 신규6개는 실패6/오류0이다. 좁은 context 필드 누락, 신규 송금 안내 route 없음, 허용 origin handshake 실패를 확인했다. 가입 메모/합류 route도 미구현 차이를 확인했고 소개 이미지503은 파일 fixture 원인을 먼저 분리한다. 이번 보완은 별도 GREEN/전체 회귀 검증 전이다.

앱16 탐색 기술 결정: 기존 가입 전 소개와 동일한 ACTIVE 모임 집합에서 q는 이름 부분 일치, region/category는 trim 후 대소문자 무시 정확 일치로 필터한다(각100자). 지역·분류별 별도 GPS/지도 taxonomy는 만들지 않는다. 검색 결과는 소개 메타와 ACTIVE 인원 요약만 반환하며 내부 글/명단/신청 메모를 포함하지 않는다. 기존 offset/limit/이름+id 정렬을 유지한다.

실제 RED1: mobile-contract-followups-red-01 ClubRequest3개 실패/오류0. 가입 메모 기대값 누락과 late reject 미구현404를 확인했다. 소개 이미지 사례의503은 테스트 프로필을 file-test에서 club-request-test로 분리하면서 LOCAL 저장 허용 dev 프로필을 빼먹은 fixture 문제였다. 해당503을 metadata 구현 누락 증거로 세지 않는다. 테스트 dev 프로필만 보강하고 소개 필드/실제 서로 다른 지역·분류 검색 반례 회귀를 추가하여 다시 RED를 확인한다. 운영 파일스토리지/개인사진 권한을 완화하지 않았다.


후속 선택 검증 `movement-context-origin-green-01`: Bank2/Community19/Origin1/Reserve22 총44개 실패0·오류0·생략0, Gradle 성공5분36초. 신규 custodian0원/은행정보 비공개/no-store 및 다른 이벤트 이력 격리·반환 SENT 추가 반례는 이 실행의 bytecode 뒤 추가되어 최종 전체 회귀에 남는다. 실행하지 않은 테스트를 GREEN으로 합산하지 않는다.

교차 검토에서 새 REJECTED && !everConfirmed도 Finance.correctParticipation의 일반 참석 정정을 통해 everConfirmed=true 및 취소/노쇼 비용 대상으로 변환할 수 있음을 확인했다. P02 합류 거절과 P07 금융 승계는 일반 참가 승인 권한을 주지 않는다. 새 거절 상태에 한해 generic 금융 참석 정정을 거부하는 최소 회귀를 먼저 추가한다. 기존 WAITLISTED/LATE_REQUESTED의 실제 사실 정정 경로는 이번 수정으로 임의 제한하지 않는다. 거절 뒤 실제 참석이 뒤늦게 확인된 경우 별도 재승인/사실 확인 정책은 미확정으로 남기고 금융 정정으로 우회하지 않는다. 실제 RED 이후 조건을 수정하고 기존 Finance 전체를 재검증한다.


앱 독립 검토 P2: 인계 후 과거 입금150원으로 정정되어 원담당자에게50원이 새로 남고, 추가 보관금 이전 이력이 아직0건이면 cashTransfers.names가 비어 있었다. 앱은 이미 응답에 있는 responsibleId의 닉네임을 필수로 읽으므로 최초 이전 요청에 접근할 수 없다. UUID/가짜이름 fallback 대신 서버가 현재 담당자의 기존 공개 닉네임을 names에 항상 포함하는 계약을 최소 보완한다. 기존 실제 인계→실수령→실입금 정정 회귀에서 빈 이력의 현재담당자 이름을 먼저 검증하여 실제 RED를 확인한다. 조회 관계·잔고·송금 권한은 넓히지 않는다.

REJECTED 교차 경계 결정: 기존 Finance.correctParticipation의 generic 실제 참석 정정은 새 REJECTED && everConfirmed=false 요청을 CONFIRMED/CANCELLED/NO_SHOW로 바꿔 거절 재승인·취소비 부과를 할 수 있는 경로였다. root 재대조 승인에 따라 이 정확한 새 상태만409로 제한하고 기존 확정 이력·WAITLISTED/LATE_REQUESTED의 기존 사실 정정 규칙은 바꾸지 않는다. 현재 원주최자 또는 정산 인수자가 거절된 요청을 generic 금융정정으로 재승인하지 않는다. 거절 후 실제 참석 사실이 뒤늦게 확인된 경우의 별도 사실 추가 절차는 미결로 남긴다. 요청자·사유·권한을 생략한 임의 운영권 확대를 만들지 않는다. ClubRequestApiTest에 현재 host/financialsuccessor × 세 상태의 HTTP 회귀를 먼저 추가했다.


앱 독립 검토 P2 추가: (1) finance_editor의 마지막 배분 행 강제가 실입금0원 정정의 allocations=[]와0원 지출 fundings=[]를 막는다. 0원일 때 명시적 빈 배분을 허용하고 양수·부호 정정의 합계/출처 검증은 유지한다. (2) 세션 만료/401의 push.dispose만으로는 A계정 서버 device/FCM 소유가 해제되지 않아 B계정 등록409 및 A의 오래된 푸시 전달 위험이 생긴다. 계정 소유와 늦은 응답을 구분하고, 만료된 bearer로 강제 다른 계정 토큰을 빼앗지 않으며 기기 FCM 토큰 폐기/재발급 등으로 분리한다. 둘 다 실공급자 없이 앱 회귀로 재현·수정하고 이후 실제 단말 수락은 별도로 남긴다.

새 optional record 필드는 Commands의 직렬화 bodyHash에 null 키를 더할 수 있어 이전 앱/서버 버전의 같은 멱등키 재시도가409가 될 수 있다. 현재 실배포 완료를 주장하지 않는 개발 단계이며 운영 장애로 단정하지 않는다. 이전 fingerprint와 새 null 필드의 호환 회귀 또는 정확 새 component만의 null 제외 방식을 후속 검토하며 Commands 전체 canonical fingerprint를 임의 변경하지 않는다.

### 앱16 소개·신청 결정 최종 선택 회귀 근거

`club-metadata-meaningful-red-02`는 테스트 dev LOCAL fixture 복구 후 ClubRequest4개 중1개 GREEN·3개 정확RED였다: activeMemberCount 기대2/실제0, 소개 기대 ‘강변 산책’/‘함께 걸어요’ 실제빈값. `club-filter-finance-rejection-red-03`에서는 소개/정확 대표이미지 ACL/가입/합류3개 GREEN, 실제 region/category 검색 기대1/실제3 및 거절된 미확정 요청의 generic 금융정정 기대409/실제200 두 개가 정확RED였다(오류0).

최소수정 후 `.superpowers/checks/club-contract-green-reserve-names-red-04/TEST-com.moishow.identity.ClubRequestApiTest.xml`은 실제 PostgreSQL17/HTTP5개 모두 GREEN(실패0·오류0·skip0)이다. 선택 소개 trim/길이·실제 ACTIVE 인원·정확 personal POST 대표이미지의 소개 재공개/미선택·내부사진·타인사진 거부/연결 해제 접근 회수, 가입거절 admin권한·이력 privacy·동일key 무중복·재신청·확정부원거절불가, late 요청 메모·current financial successor 거절권 없음·일반 참가목록 비노출·확정참가자 제외 금지, 실제 서로 다른 지역/분류 모임 필터, host/현재 financial successor 각각이 세 상태(CANCELLED/NO_SHOW/CONFIRMED)로 generic 금융정정하는 우회409와 everConfirmed=false/요청·참가자 점수 없음 보존을 확인했다.

동일 실행의 별도 Reserve1개는 root가 추가한 ‘최초 보관금 인계 목록에도 현재 담당자 이름 필요’ 회귀로 names.empty 기대false/실제true의 정확RED였다. 따라서 이 실행 전체 build를 GREEN으로 표시하지 않는다. API Gradle lease를 root에 반환했으며 기존 Finance 전체·최종 서버 통합 build·실제 앱57흐름 QA는 root의 후속 근거를 따른다. 실공급자·실은행·배포·공개/비공개 검색정책 미응답 한계는 그대로다. Vault는 root가 중앙 갱신한다.


HISTORY 화면 대조: 원안의 핵심은 개인합산·차수근거·실입금·차액과 탈퇴 후 원본/후속 처리 유지다. 별도 기간/상태 필터는 명시 요구가 없어 임의 기능으로 늘리지 않는다. 목록은 실제20개씩 더 보기, 각 행 확장 때만 금융 원본을 조회해 대량 N+1을 피한다. funding.ready의 정확 session.userId position만 요약하고, 미확정 분류는 안내/원본 진입으로 유지한다. 본인이 금액대상이 아닌 주최/담당 이력은 그 사실을 표시하며 다른 사람 첫 position이나 누락값0원을 사용하지 않는다. TODO도 종류별 업무/확인대기 분리·정확 자원 진입을 검증하며 원안에 없는 필터를 필수로 만들지 않는다.

GitHub issue16을 현재57개화면/12개와이어플로우/JPEG 및 Java25·Gradle실제계약·서버PR21완료/앱미완·실공급자/단말수락분리로 갱신했다. 앱 인수기준을 없애거나 실공급자검증을 성공으로 표시하지 않는다.


운영 웹 대조 P2: Platform P11의 정확 담당자 인수/회수 계약은 handlerId 유무가 아니라 canClaim/canReadDetails/canDecide로 응답한다. 앱은 flags를 따르지만 admin main.tsx는 handlerId가 있으면 무조건 상세 GET을 호출해, 기존 담당자 권한 회수 후 canClaim=true인 다른 운영자가 인수할 수 없었다. 로컬 명시 계약 대역18081(실제공급자/권한없는실사용자자료아님)으로 handlerId=revoked-handler, canClaim=true/canReadDetails=false를 반환하여 실제브라우저 클릭의 CASE_ACCESS_DENIED/GET1·claim0 RED를 확인했다. canClaim에 따라 명시 담당하고 열기/POSTclaim을 선택하고 최신 capabilities를 반영한다. 처리 폼도 canDecide만 허용하며 서버 검사를 대체하지 않는다. 기존실제PG TEST서버의 운영자 목록/상세 조회는 별도로 성공 확인했다.


운영 웹 재인수 fix 검증: 동일 계약 대역의 canClaim=true/기존handler 존재 응답을 수정 후 명시 담당하고열기로 POSTclaim(version0)하여 상세version1/새handler를 열었다. 상태 claimed=true/gets1/claims1(수정전 GET1은 보존)이며 캡처 operator-web-reclaim-green.jpg에 보존했다. 최신 strict TypeScript/Vite production build 통과. 실제PG서버의 기존담당사건 목록/상세·snapshot·진행이력 열람도 별도확인했으나 이 대역을 실제운영자 회수DB검증으로 주장하지 않는다.


최신 통합 결과(2026-10-22): full-mobile-contract-server-01 Java25 Gradle build/JAR 성공7분46초, 최신 V11/정확 names 수정과 모든 회귀168개 실패0·오류0·생략0. Finance37/Reserve23/ClubRequest5/Community19/Origin1을 포함한다. 서버 금융·identity 및 운영웹4변경/names1줄의 독립 closure 검토에서 남은 구체 P1/P2가 없었다. 최신 운영웹 strict TypeScript/Vite build 및 재인수 브라우저 GREEN도 별도 확인했다. 앱0원/푸시 fix·57흐름·최신APK/실단말/공급자 수락은 별도 진행이며 서버168GREEN을 앱 완료로 확대하지 않는다.


앱 PR 검증 계획과 기존 CI를 대조하니 서버/Node참고/운영웹만 있어 Flutter를 검증하지 않았다. 최신 로컬과 같은 Flutter3.47.7 및 Android Java21로 analyze/test/web/debugAPK CI 작업을 추가한다. 서버 Java25는 별도 job에서 유지한다. Flutter 설치 action의 실제 action.yaml과 v2의 현재 commit1a449444c387b1966244ae4d4f8c696479add0b2를 공식 upstream GitHub API로 확인하고 commit에 고정했다. 이 작업은 CI설정이며 원격 실행 결과 확인 전 성공으로 주장하지 않는다. iOS/실공급자/서명배포 수락을 대체하지 않는다.


후속 앱 표기 계약 대조: join/late 이력은 정확 본인/관리자/원주최자에게만 반환하지만 DTO에 userId/createdBy만 있어 PENDING/REJECTED/탈퇴 신청자의 이름을 ACTIVE 부원 목록으로 찾을 수 없었다. P10 닉네임 표시를 위해 같은 제한된 이력에 nickname/departed·actorNickname/actorDeparted를 추가한다. 신청자의 명시 모임 신청 닉네임과 기존 현재/마지막 닉네임 관계를 재사용하며 이력 본문·ID·접근필터는 보존한다. 예금주명·전역 디렉터리나 새 공개범위를 추가하지 않는다. HTTP 회귀 RED 후 최소 DTO 변경/선택 GREEN과 최종 CI 전체 검증으로 확인한다.

RevisionComparison은 제공된 snapshot/afterSnapshot의 사용자 union과 정확 필드쌍만 읽어 비교한다. 원본/정정후 없는 사용자 기록은 기록없음, after자료없음은 명시하고 현재 원장으로 가짜 복원하지 않는다. 누락/잘못된 금액은 확인필요로 표시하며0원을 만들지 않는다. net은 선지출반영 순차액, refund는 일반환불로 구별하며 새 정산/델타를 계산하지 않는다. 별도 기간/필터·서버쓰기 없이 기존 원본 dialog에 통합한다.


마지막 표시 DTO 검증: club-history-names-red-01에서 신청닉/late서비스닉 실제누락2개 RED 후 ClubService.decisionView만4표시필드 보강, club-history-names-green-02 실제PG ClubRequest5개 실패0·오류0·생략0/Gradle성공1분44초. 기존 전체168개는 그 직전 DTO이며 최신 표시 변경은 이 선택5개+최종 원격CI 전체로 구분 검증한다. DB/개인정보필터/원본결정 이력은 변경하지 않았다.

현재 문서 감사에서 남아 있던 '앱미생성/금액원장없음/contacts다음작업/승계미구현/종료후합류무조건거부'는 실제 현재계약으로 정정했다. 과거 PR20의50개/초기51화면/Maven32개 기록은 날짜 있는 과거이력으로 보존한다. FILES-API에는 실제 PAYMENT scope와 명시 대표사진 정확연결 staged 예외를 반영했다. 미배포/실공급자·S3/실기기 한계는 계속 별도다.


LEVEL 진입 대조: 서버는 같은 모임/확정 이벤트 관계(탈퇴·공개비부원 포함)의 레벨 조회를 허용하지만 앱은 ACTIVE 모임 목록의 본인 진입만 제공해 기존 관계자가 기능에 도달하지 못했다. 새로운 공개프로필/공유링크/전역검색 대신 기존 모임 멤버행의 해당 멤버 레벨 및 기존 이벤트/정산의 본인 활동레벨 진입으로 최소 보완한다. 이미 반환된 사용자/모임 ID만 사용하며 일반 미확정 구경꾼에게 접근권을 만들지 않는다. 서버 LEVEL_RELATION_REQUIRED는 그대로 적용하고 관계 회수/403을 안내한다. 자체 점수 계산/개인 상세 납부·분쟁 증빙 공개는 추가하지 않는다.


최종 실제 GUI 인수에서 두 표시/접근성 누락을 추가 재현했다. NavigationBar 중앙+는 tooltip이 Semantics에서 제외되고 label이비어 스크린리더에 무명이었다. Semantics 이름0개 RED 후 아이콘의 명시 '정모·번개 만들기' label로 외형/동작을 유지하며 수정했다. 일반환불 SENT→수령CONFIRMED 실제 TEST API 전이는 성공했지만 참가상태 공통라벨 '참여 확정'을 잘못 재사용했다. 금융맥락 전용 '수령 확인 완료'/'송금 기록·수령 확인 대기'를 분리하며 참가 상태 전역라벨·금액·전이는 변경하지 않는다. 새 정책이 아닌 기존 완료 단계/접근성 의미 일치이며 회귀와 최종 빌드로 검증한다.

운영웹 실제 POST QA의403은 test-only MobileScenarioHost HTTP CORS가8766만 허용한 설정 문제였다. 같은 /reports OPTIONS가 Origin8766→200,5173→403 Invalid CORS request로 원인을 확인했다. 실제 제품권한/생산CORS를 우회하지 않고 테스트 환경에 운영웹의 정확 loopback5173도 추가하여 실제 PG claim/progress 재검증한다.


실제83 GUI에서 피드 탭이 /explore의 '모임탐색' 헤더·이름/지역/분류 폼을 먼저 표시하고 개인 Feed를 아래에 혼합한 것을 확인했다. catalog의 FEED(소셜 글/모집카드·POST/COMPOSE)와 EXPLORE(모임검색·소개)는 별도 원안이다. 새 기능을 만들지 않고 기존 Feed를 /feed의 주화면으로 재사용하고 모임찾기에서 기존 /explore로 이동하게 최소 라우트/위계를 정렬한다. 가입 전 내부 콘텐츠 필터와 서버 API는 그대로이며 피드 탭 실제 콘텐츠 회귀로 확인한다.


커밋 인수: Flutter 최신86개/분석 GREEN 후 코드 동결했다. upstream Pretendard/PDF.js의 원문 라이선스에는 배포본 공백이 포함돼 있어 내용을 수정하지 않고 해당3개 라이선스/OFL만 whitespace 검증에서 제외한다. 소유 코드/일반 문서는 계속 diff --check로 검사하고 생성된 iOS project 끝의 중복 빈줄은 정리한다. 라이선스 문구·해시 검증된 vendor 원본을 숨기거나 실행 코드를 검사 제외하지 않는다.


최종 앱 통합 근거: f34fc26 PR22의 정확 HEAD에서 CI8개(Spring/정적·Node/운영웹/Flutter 각 push·PR)가 모두 성공하고 develop e84f1f1에 병합됐다. 로컬 최신 final05 Flutter86개/분석 GREEN, 마지막 표시 formatter 한 줄 포함 final04 TEST웹126.8초·production웹94.8초·debugAPK21.1초 성공과 실제 APK SHA256 FEFCFBDF18E04BDC52F7CA2A87ECA9A9EDD8EB6DBF412FEE5FF5CD3CEDB83817을 확인했다. 마지막5개 UI 수정 독립 closure도 남은 구체 P1/P2 없음이다.

원격 CI와 별도 실제 최신PG GUI에서 운영웹 claim→PROGRESS 저장/버전2·목록/상세이력, 탈퇴자의 본인 미납·레벨50점, 블랙리스트 이력자의 금융 유지/일반모임 내부콘텐츠 비노출을 확인했다. GROUP 즉시목록·REST/STOMP 교차역할 수신 증거 PNG를 보존한다. 사진chooser 자동파일주입은 브라우저확장의로컬파일권한으로막혀 생산/앱권한을완화하지않고 GUI미검증으로남긴다. 실공급자/실은행어댑터503·실기기/iOS/서명배포/공개범위 미결은 성공으로 덮지 않는다.


### 2026-10-23 CODEF 기존 설계 복원과 계좌 인증 대조

사용자가 해찬 문서의 공급자 선정을 지적해 `origin/haechan:docs/external/codef.md`와 회원 시나리오를 재검토했다. CODEF 예금주명 인증+1원 이체+서비스 코드 대사 설계가 이미 존재한다. 이전의 '공급자 미정/문서 주소를 기다림/단순 후보' 설명은 부정확하며 CODEF 기준으로 정정한다. 실제 어댑터 미구현/계약·키·실계좌 검증 미확인은 별도 사실이다. 구 PASS CI는 현재 사용자 확정 소셜+SMS 정책으로 대체됐으므로 되살리지 않는다.

요구사항/이슈3/현 구현을 대조하니 BankOwnershipVerifier 4인자 동기 호출과 단일 등록 POST만 있어 1원 코드 입력/수명/일회 증명/실패 후 재시도 경계가 빠졌다. `BANK-VERIFICATION.md`와 `../superpowers/plans/2026-10-23-codef-bank-verification.md`를 먼저 작성했다. 개인 계좌·적립금 계좌·새 보관 담당자 계좌에 공통 인증을 적용하되 기존 권한/실제 수령/금액/version은 유지한다.

결정 원장: (1) 코드 유효10분/5시도, 사용자 간격120초/같은은행계좌 일5회는 남용·재시도 제어 기술 기본값이며 사용자 확정 정책으로 표시하지 않는다. (2) 예금주 exact trim 일치, 임의 자르기/유사이름 승인 없음. (3) DEMO는 인증 계좌를 만들지 않음, 기본DISABLED·catalog빈값. (4) provider HTTP 전에 durable dispatch선점, 외부IO중 DBtx없음, 결과불명 자동재송금 없음. (5) 코드 오답도 attempts/idempotency를 커밋한 뒤 오류반환. (6) actor/bank/account/holder/purpose/context 일회 증명, 최종쓰기 실패시 소비rollback. (7) identity는 transient, 원문코드 DB/응답없음; 코드/계좌fingerprint HMAC, 계좌/holder암호화. (8) 기존 테스트lambda호환은 test-only이며 운영oldverify는failclosed. (9) CODEF 추적ID는 은행거래reference나 자금출처namespace가 아니다. ACTOR_FALLBACK 한계를 receivingbank인증으로 임의 해결하지 않는다. (10) 새 optionalverificationId=null을 fingerprint에서 제외해 기존 멱등재시도 호환 보존. (11) 앱 인증 begin/confirm의 민감 입력은 영속 commandjournal에 저장하지 않고 같은 키의 인메모리 재시도로 제한하며, 결과 확인/재진입은 본인 challenge상태로 지원한다.

원문 프로토콜 수정: inPrintType필수, 공식SDK whole-JSON URLencode/응답one-decode, HTTP200+CF-00000+필수값, 공식SDK sandbox별도호스트 존재, 기관코드 두상품별명시매핑/지원여부 확인. 이 문서 작성 시점은 구현·운영성공 주장이 아니다. 실공급자 승인/키/기관코드/실기기/실송금은 별도 수락으로 남긴다.


CODEF 추가 경계 결정: 동일계좌 일5회는 Asia/Seoul 달력일 기준·사용자 간 공유이며 catalog별칭 bankId로 우회되지 않도록 확인된 transferOrganization+번호를 HMAC scope로 사용한다. 사용자lock과 별도로 같은계좌 신규생성의 동시성을 직렬화한다. 이 일자 기준도 운영기관의 리셋 시각을 확인한 사실이 아니라 서비스 제어 기본값이다. 단계가90초 이상 진행중이면 조회는 결과미확인으로 표시하되 GET으로 사실을 다시쓰기/외부전송을 재개하지 않는다. 앱 재진입의 미소비 VERIFIED 증명은 원번호/예금주를 재입력하여 exactbinding을 확인하며 masked정보에서 복원하지 않는다. 은행목록 wrapper는 {available,banks:[{id,name}]}, 본인 인증목록은 plainarray, provider호출실패는 FAILED/UNKNOWN 상태200으로 구분한다.
