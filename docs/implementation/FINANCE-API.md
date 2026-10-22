# Finance API — issue13

현재 상태: 금융 기본/리뷰 회귀를 구현했고 backend-review-green-profile-red의36개 통과와 fixture 수정 후 finance-host-selection-green의 나머지1개 통과를 확인했다. 최신 전체37개 및 서버 전체 build의 최종 단일 실행 증거는 root 통합 검증에서 갱신한다.

2026-10-22 현재 구현 계약. 정본은 POLICY.md, STATE-MODEL.md와 REQUIREMENTS-AUDIT.md다. 아래 계약은 이전 구현의 POSTPAY 기본선택·72시간 자동납부기한·잔여액 이하 단일신고·환불 즉시SENT·등록 후 참가정정 전면거부를 대체한다.

모든 경로는 `/api/v1`. 활성 bearer와 업무 POST의 UUID `Idempotency-Key`가 필요하다. 같은 사용자·작업·key·본문은 같은 응답, 본문 변경409. 금융 쓰기는 GET finance의 book `version`; 참가/비용동의 쓰기는 차수version, 일정변경은 eventVersion을 사용한다. 원화는 정수이며 개별/누적0..9007199254740991, 실수·문자열 암묵변환을 거부한다. 외부 송금은 사용자가 수행하며 앱은 실제 은행 연결이나 외부 송금 성공을 가장하지 않는다.

## 개설·차수·동의

| 경로 | 입력/처리 |
|---|---|
| POST /clubs/{id}/events | 기존 필드 + 필수 settlementMode PREPAY/POSTPAY. 생략400. SQL POSTPAY default는 기존자료 마이그레이션용이다. |
| POST /events/{id}/finance/open | version0, 선택된 mode와 일치해야 한다. 담당자만 초기화. |
| POST /rounds/{id}/payment-requests | book version, amount(0허용), deadline. 마감 전에 조건을 저장할 수 있다. 마감 뒤 실행하면 확정자별 요청을 한 번 생성한다. 조건 변경 이력은 보존하며 기존 기한을 소급 단축하지 않는다. POSTPAY는 선납요청 생성 금지. |
| POST /rounds/{id}/billing/close | book version. 설정된 마감 시각 이후 저장한 조건으로 요청 생성. trusted processDueRounds()도 같은 잠금/버전으로 처리한다. |
| POST /rounds/{id}/fee | round version, cancellationFee, reason. 조건버전 추가, 기존 신청자는 PENDING이며 원래 agreedFee와 참여 유지. |
| POST /rounds/{id}/consents/fee | round version, accepted. 동의만 새 비용 적용. 거부는 CANCELLED/0원/FEE_CHANGE_DECLINED. |
| POST /events/{id}/schedule | event version, startsAt, endsAt, reason. 변경 이력과 재확인 PENDING, 기존 참여 유지. |
| POST /rounds/{id}/consents/schedule | round version, accepted. 거부는 비용 없는 취소 DATE_CHANGE_DECLINED. |
| POST /rounds/{id}/cancel | round version, reason. 해당 금융 담당/주최 권한, 전원 취소·0원·HOST_CANCELLED. 기존 실제 납부는 환불 의무로 남는다. |
| POST /rounds/{id}/participations/{pid}/no-show | round version, reason. 시작 후 실제 노쇼 기록, 동의한 취소 비용과 같은 비용. |

기존 참가 요청·승인·본인 취소는 identity 경로를 유지한다. 마감 후 승인 시 저장된 차수 조건으로 신규 인원에게만 요청한다. 종료된 과거 참가 누락은 본인 요청+현재 조건 동의→주최자의 사유 있는 실제 이력 승인으로 처리한다. 임의의 관계없는 사람을 주최자가 강제로 추가하지 않는다.

최초 등록 뒤 본인 취소는 원래 참석/비용을 즉시 바꾸지 않고 비공개 정정 요청을 만든다. 참가 응답에 correctionRequestId/correctionRequestStatus/financeVersion이 추가된다. 실제 담당자가 원본 보존 정정을 하고 해당 사건의 revision과 결과를 연결한다. 미응답 동의는 자동 취소·새 비용 적용 사유가 아니다.

## 입금·정정·정산

| POST /events/{id}/finance/… | 입력/처리 |
|---|---|
| reports | version, requestId, amount, evidence 선택. 본인 요청만. 복수 신고·초과입금도 기록하며 신고는 실제 입금으로 집계하지 않는다. |
| reports/{rid}/verify | version, amount, transactionReference, allocations[{roundId,kind:ATTENDANCE/CANCELLATION/HOST_CONTRIBUTION,amount}], actualReceivedAt 선택. 담당자가 실제 금액을 확인. 귀속 합계=입금액, 해당 사용자의 실제 참가 차수만. 같은 실제 보관자 scope의 외부 거래 식별자 중복409. 다른 보관자의 같은 문자열은 허용한다. |
| reports/{rid}/reject | version, reason. 원 신고와 반려/처리자/시각 보존. |
| reports/{rid}/correct | version, reason, amount 선택, actualReceivedAt 선택, allocations 선택. 확인 원본은 보존하고 유효 금액/시각/귀속을 append. 금액 변경 시 새 귀속 합계 필수, 시각만 뒤늦게 확인하면 원래 귀속 재사용. |
| requests/{rid}/extend | version, deadline, reason. 담당자가 명시한 기한 지정/연장 이력. 과거 기한 단축 금지. |
| expenses | version, roundId, title, amount, fundings 필수(0원은 빈 배열 허용); evidence 선택. 각 portion은 paidByUserId/source/amount/actualPaidAt 선택시각. source는 PERSONAL 또는 EVENT_FUNDS이며 합계=비용이다. top-level paidByUserId는 단일 납부자 호환 필드로만 허용하며 portions와 일치해야 한다. |
| register | version, 명시적인 deadline 필수. 이벤트 종료 후 최초 계산·등록자·시각·원본 snapshot 보존. 72시간은 최초 등록 판정이며 참가 납부기한의 기본값이 아니다. |
| close | version. 등록 후 계산 마감. 미납·환불·이의·후속 입금 처리는 유지한다. |
| revisions | version, roundId, reason + amount(지출 증감, fundings 명시) 또는 adjustments[{userId,amount}]. 개인 조정은 그 차수 참석자만, 합계0, 최종 부담 음수 금지. 원본/지출 행을 덮어쓰지 않는다. |
| participations/{pid}/correct | version, status CONFIRMED/CANCELLED/NO_SHOW, reason. 담당자의 실제 사실 정정. 비용 증액에는 해당 사용자가 동의한 feeVersion과 agreedFee 근거 필요. 기존 개별 배분이 새 참석자 구성과 안 맞으면 replacement adjustments 필수; 빈 배열은 현재 기본 균등분담. |
| late-fees | version, status REFUND/RESERVE, reason. 최초 등록 후 실제 받은 취소비 중 미배분분만 선택. 미선택은 기존 부담을 바꾸지 않고 보류. 일반 환불은 적립 전환하지 않는다. 해산 모임의 새 RESERVE는 거부한다. |

최초 등록 시 선납 요청을 SUPERSEDED로 남기고 이벤트 개인별 순차액 요청을 만든다. 후속 정정으로 기존 기한이 지난 새 부담이 생기면 기한 지정 대기이며 자동 지연 판정하지 않는다. actualReceivedAt 미확인과 해당 사용자의 OPEN/REVIEWING 이의는 점수 보류다. FinanceScoreSource.reassess는 정정된 유효 거래·시각을 사용한다. 외부 은행 검증을 호출한다는 의미가 아니다.

## 환불·이의·증빙

| POST /events/{id}/finance/… | 입력/처리 |
|---|---|
| refunds | version, 본인 또는 담당자가 지정한 userId, amount. REQUESTED 생성. 최초 등록 전에는 취소/노쇼의 확인 입금-동의 비용-실송금 환불 범위만. |
| refunds/{rid}/sent | version, actualSentAt, transactionReference, 실제 amount 선택(생략은 요청액). 담당자가 사용자의 외부 송금 사실을 별도로 기록한다. REQUESTED는 돈으로 차감하지 않고 실제 sentAmount만 최종 순차액/현금 흐름에 반영한다. |
| refunds/{rid}/confirm | version. 수령자 본인만 실제 수령 확인, 금액을 다시 차감하지 않는다. |
| disputes | version, reason, evidence 선택. 본인 과거 확정 참가의 이의. |
| disputes/{did}/review | version, reason. 정확한 처리 담당자가 REVIEWING으로 전환. |
| disputes/{did}/resolve | version, status ACCEPTED/REJECTED/WITHDRAWN, reason. 인정/반려는 publicResult 필수. 금액 변경은 revisionId·correctionAmount(해당 사람 순부담 변화)와 일치해야 한다. 철회는 당사자만. |

GET `/events/{id}/finance/disputes/{did}`는 당사자/현재 책임자/FinanceCaseAccess의 정확 할당 읽기만 허용한다. 과거 담당자의 증빙 읽기와 현재 canResolve 권한을 분리한다. 배정자에게 전체 finance·입금 확인·환불·정정 권한은 부여하지 않는다.

`file:UUID` evidence는 AttachmentAccess(PAYMENT/EXPENSE/DISPUTE)로 소유/이벤트/범위를 검사한다. 연결 미설정503. 다른 문자열은 메모이며 업로드된 증빙으로 표시하지 않는다. 파일 경로나 외부 URL을 서버가 임의로 읽지 않는다. 미첨부 지출은 NO_EVIDENCE, 텍스트는 NOTE, 보호 파일은 ATTACHED다.

GET finance는 version/status/mode/eventVersion, 요청·입금신고/정정·지출·환불·사건·참가변경 이력, 원본/후속 snapshots, calculation, names{userId:{nickname,departed}}, permissions{manageSettlement,canCreateDispute,canRequestOwnRefund}를 반환한다. 이의 신청 가능은 과거 확정 참가자만, 본인 환불 요청 가능은 기존 당사자 자격과 실제 일반환불 잔여액에서 REQUESTED 합계를 뺀 양수 여부다. UI 힌트이며 POST가 다시 권한/버전을 검사한다. 부원은 일반 개인별 부담/납부·지출 근거·이의 상태/공개 결과/정정액을 본다. 탈퇴자/비부원은 자기 관련 차수·자기 금융 사실만 본다. 송금 캡처·이의 사유/대화/증빙은 일반 부원에게 노출하지 않는다.

## 영속성·검증·미완료 경계

Commands own-actor→club→event→book→child 직렬화와 idempotency receipt, 모든 금융 변경의 book version을 사용한다. 실제 교차 사용자 FK 잠금은 공통 Store/Commands의 별도 회귀 대상이다. FinancialChanged는 재계산 뒤 동기 발행한다. trusted FACT_CORRECTION은 이미 발생한 입금·송금/증빙 정정을 보존하고 부족을 드러낸다. 새 배분 의도는 ALLOCATION_CHANGE이며 적립 출처 guard를 유지한다. 이 태그는 HTTP 입력으로 선택할 수 없다.

실제 PostgreSQL17/HTTP `FinanceApiTest` 17개 실패0/오류0/생략0: `.superpowers/checks/audited-integration-01/TEST-com.moishow.identity.FinanceApiTest.xml`. 모드·명시기한·마감 전 조건, 복수/초과입금·동일 거래 중복·원본 보존 입금 정정, 요청/실송금/수령 환불, 비용 재동의·날짜 변경·주최 취소·노쇼/참석 정정, 과거 정정 요청, 차수 배분 대체, 비공개 증빙·공개 결과, 동시 버전/범위/실수·합계 한계를 검증했다. 소셜/SMS 대역은 테스트 소스에만 있다. 공급자 실거래/실수신을 검증했다는 뜻이 아니다.

## 자금 출처와 선지출 정산 계약

POST expenses/revisions의 `fundings`는 `[{paidByUserId,source:"PERSONAL"|"EVENT_FUNDS",amount,actualPaidAt?}]`다. 복수 납부자·두 출처 혼합을 허용한다. 정정은 원래 expense/portion을 수정하지 않고 부호 있는 새 expense+portions를 추가한다. 누적 개인/공동자금 출처 금액은 음수가 될 수 없다. 기존 출처 없는 지출은 UNKNOWN이며 임의 PERSONAL 기본값을 넣지 않는다. `POST expenses/{id}/classify`는 version/reason/fundings로 실제 출처를 append하고 분류 전에는 인계를 막는다.

GET finance의 `funding`은 eventId/ready/unclassifiedExpenses/positions/custody/factsAvailable이다. positions 각 행은 userId/obligation/deposits/ordinaryRefunded/personalExpense/advanceRecovered/ownExpenseOffset/additional/ordinaryRefundDue/advanceDue/totalReceivable, custody는 actorId/cashHeld/advanceDue/proposedSelfRecovery/transferableCash/remainingAdvanceLiability/deficit를 반환한다. 부원 외에는 본인 행만 제공한다. 비용 DTO는 fundings와 fundingStatus, 현재 단일 납부자 paidByUserId(혼합이면 null), 원래 header originalPaidByUserId를 제공한다.

B=최종 부담, D=실제 은행 입금, R=실제 일반환불, P=개인 선지출, A=실제 선지출 상환+명시 SELF_RECOVERY라 하면 순부담=B-D+R-P+A다. additional=max(0,순부담), totalReceivable=max(0,-순부담), 일반환불=min(totalReceivable,max(0,D-R-B)), advanceDue=totalReceivable-일반환불이다. PERSONAL은 실제 은행 입금으로 합산하지 않는다. EVENT_FUNDS 지출만 납부자의 공동 보관액에서 차감한다. 자기 부담만큼 선지출한 주최자에게 자기 입금·이중 채권을 만들지 않는다.

custody는 실제 입금 확인자 processedBy가 보관한 돈에서 실제 환불 송금/공동자금 지출을 빼고 FinanceFundingFacts의 실제 인계·적립·상환 사실을 반영한다. 자기 채권과 자기 보관액이 겹치면 제안액만 표시하며 root14의 명시 SELF_RECOVERY 기록 전에는 실제 은행 송금으로 만들지 않는다. 음수 custody가 정정으로 드러나면 deficit/ready=false를 표시하고 실제 거래를 삭제하거나 PERSONAL로 바꾸지 않는다.

거래 reference registry는 서버가 실제 보관자 ACTOR scope를 기록하여 입금/환불/MOVEMENT 간 같은 출금·입금 사실 중복을 막는다. 현재 실공급자 은행코드+검증된 실계좌 identity가 없어 actor fallback이며, 동일 actor의 서로 다른 실계좌에서 같은 reference를 사용한 경우는 구분할 수 없다. 클라이언트 UUID로 scope를 나누지 않는다. 선택 cashAccountId는 trusted FinanceCashAccountScope가 실제 검증 계좌를 확인할 때만 사용하며 provider가 없으면503이다. 현재 계좌 변경만으로 기존 scope를 자동 변경하지 않는다.

사건 생성 시 현재 책임자를 immutable counterpartyId로 보존한다. 인계 후에도 그 사건의 원래 상대방은 정확한 사건과 증빙을 읽으며, 새 사건 전체에 대한 접근 권한은 얻지 않는다. 상세 GET permissions는 canReview/canResolve/canWithdraw/canAppendFinancialRevision, relatedRevisions는 해당 사건 신청인의 순부담을 바꾼 revision id/createdAt/createdBy/correctionAmount만 제공한다.

추가 구현 결정은 사용자 확정 P05/P07 선지출 채무 인계와 기존 금액 보존을 따른다. 은행 연결 없이 외부 송금 성공을 생성하지 않으며, null actualPaidAt/actualReceivedAt는 점수 판정을 보류한다. FinanceFundingFacts는 Store-only 실제 사실 bridge이며 Finance 재호출/별도 채권 계산을 하지 않는다. 추가 funding/보관자별 reference/원래 사건 상대방 테스트는 실제 RED 후 구현하여27개 GREEN으로 확인했다. permission DTO 추가1개도 실제 RED 후 구현하여 전체28개 GREEN으로 검증했다.

검증 갱신: `.superpowers/checks/finance-reserve-bank-integration-01/TEST-com.moishow.identity.FinanceApiTest.xml` —27개 실패0/오류0/생략0,44.335초. funding7개·은행 reference scope2개·원래 사건 상대방1개와 기존17개 회귀를 포함한다. 같은 실행의 Reserve8 실패 및 Bank 신규 안내1 의도 RED는 별도로 수정·검증한다.

최종 금융 회귀: `.superpowers/checks/funding-permissions-green-custody-file-red/TEST-com.moishow.identity.FinanceApiTest.xml` —28개 실패0/오류0/생략0,73.458초. 같은 실행의 다른 모듈3개 RED는 금융 테스트 통과와 별도로 추적한다.

## 독립 리뷰 보완 계약

원주최자가 차수 참가자가 아니어도 참석0명 hostContribution 부담을 실제 납부할 수 있다. 명시 `HOST_CONTRIBUTION` 배분은 정확한 원주최자와 차수의 현재/불변 정산 snapshot 또는 원배분 근거를 검사한다. 실제150원이100원 부담에 입금되면150원을 보존하고50원을 일반환불로 남긴다. 현재 부담이0으로 정정되어도 과거 원본 근거가 있는 납부 사실/시각 정정은 허용한다. 참가 이력 없는 원주최자에게 PARTICIPANT 점수를 부여하지 않는다.

P12는 필요한 은행 납부와 실효 PERSONAL 기여를 합쳐 실제 시각을 판정한다. B100/P50+D50에서 P 시각 미상은 HOLD, P가 실제 늦으면 LATE→RECOVERED, 둘 다 기한 내면 ON_TIME이다. 정시 D100만으로 B100을 충족하면 불필요한 미상/늦은 P50은 불리하게 반영하지 않는다. 음수 지출 정정은 실효 P 상한과 원 시각별 금액에 반영하며, 어느 기여를 줄였는지 모르면 임의 시각 대신 HOLD한다. 신고/등록시각을 실제 기여 시각으로 바꾸지 않는다. 중앙 결정/실제 RED 근거는 REQUIREMENTS-AUDIT의 독립 리뷰 후 Finance P2 절에 기록한다.

리뷰 보완 회귀: `.superpowers/checks/finance-review-green-01/TEST-com.moishow.identity.FinanceApiTest.xml` —금융34개 전체 GREEN. 이 테스트 실행의 testClasses 뒤 필요한 미상 기여가 알려진 합계만으로 부족하면 HOLD하는 보수 조건 한 줄을 추가했으므로, 최신 소스의 통합 compile/회귀는 root 최종 검증으로 확인한다.

개인 기여 시각 정정 후 점수: delta0와 명시 fundings[-oldAt,+correctedAt]를 포함하여 실제 PERSONAL 기여군이 바뀌면 정확히 해당 이벤트·납부자의 PARTICIPANT 판정만 무효화한 뒤 같은 canonical 기여로 다시 평가한다. 정시+1→실제 늦음 순-1, 반대는 순-1→정시+1이며 다른 참가자/주최 판정은 유지한다. 동일한 실효 기여를 다시 append한 경우 판정을 불필요하게 리셋하지 않는다.

기존 private report DTO는 `allowedAllocationKindsByRound:{roundUUID:["ATTENDANCE","CANCELLATION","HOST_CONTRIBUTION"]}` 중 실제 허용되는 차수/종류만 포함한다. 배열은 예시이며 납부자의 원주최/참가/취소 관계 및 현재·불변 부담 근거로 줄어든다. 검증과 동일 helper를 사용하고 증빙/보고서 읽기 권한은 확대하지 않는다. 과거 VERIFIED 자료의 processedBy가 없으면 보관자를 추정하지 않고 funding.ready=false를 반환한다.

추가 리뷰 검증: `backend-review-green-profile-red`에서 개인시각 정정 양방향·다른 참가자/HOST 점수/감사 보존·허용 배분 DTO의 음성 사례를 포함한 Finance36개와 Platform18개가 통과했다. 나머지 원주최자 사례는 모임장이 볼 수 있는 전체 요청 중 첫 행을 선택한 fixture 오류(OWN_REQUEST_ONLY403)를 납부자 ID 선택으로 수정한 뒤 `finance-host-selection-green` 단일 회귀 GREEN으로 확인했다. 이 사례는 HOST hint·초과입금150/의무100/환불50·비용0 정정 뒤 원배분 시각정정/환불150·PARTICIPANT 점수 없음까지 확인한다. 원래 요청 검증/금액/읽기 권한은 완화하지 않았다. 최종 전체37개 및 전체 서버 build는 root 통합 실행을 따른다.

앱16 가입/합류 거절 경계: `REJECTED && everConfirmed=false`는 generic `participations/{pid}/correct`로 CONFIRMED/CANCELLED/NO_SHOW로 재분류할 수 없다(409). 거절된 미확정 요청을 금융정정으로 재승인하거나 취소·노쇼 비용/점수 대상으로 만들지 않는다. 다른 기존 실제 참석 정정 경계는 유지한다. 거절 후 실제 참석 사실이 뒤늦게 확인된 경우의 별도 절차는 미결이다.
