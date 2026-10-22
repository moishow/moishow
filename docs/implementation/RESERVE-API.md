# 적립금·인계·해산 API와 요구 대조

정본은 POLICY P07/P08/P09와 issue14다. 선지출 반환 의무는 2026-10-22 사용자 후속 확정을 따른다. 중앙 결정 원장은 [REQUIREMENTS-AUDIT.md](REQUIREMENTS-AUDIT.md), 금액 계산 정본은 Finance.reconcile이다.

실제 PostgreSQL Testcontainers 회귀 20개가 모두 통과했다(실패0·오류0·스킵0). 최신 증거는 .superpowers/checks/backend-review-green-profile-red/TEST-com.moishow.identity.ReserveApiTest.xml이다. 기본 적립·사용·해산, 선지출·자기 회수, 명세 변경 후 실제 수령·재수락·반환, 인계 후 정정 보관금, 정확 수령자 삭제 가드, 예금주명 비공개, 탈퇴 담당자 전용 적립 맥락을 포함한다. 같은 Gradle 실행의 다른 도메인 review RED는 별도로 남아 있어 전체 서버 통과를 뜻하지 않는다. 실은행 공급자 어댑터와 안정적인 은행 계좌 identity는 미구현이며 코드 테스트 통과와 구분한다.

## 금액과 원장 경계

- 개인별 부담·일반 환불·선지출 순채권·실제 보관금은 Finance.reconcile만 계산한다. Reserve의 AdvanceFundingLedger는 Store에서 실제 이동·명시적 자기 회수 사실만 제공하며 Finance를 호출하지 않는다.
- PERSONAL 지출을 모인 돈 지출이나 외부 납부로 바꾸지 않는다. 자기 부담과 상계한 순채권만 반환 대상이며 인계 때 채권을 복제하지 않는다. UNKNOWN 지출은 분류 전 새 인계·회수·추가 송금 요청을 막는다.
- 인계 금액은 actor.cashHeld 실제 전액이다. proposedSelfRecovery/transferableCash는 제안값이므로 자동 차감하지 않는다. 현금50/선지출채권50은 그대로50/50 인계할 수 있고, 사용자가 SELF_RECOVERY50을 명시적으로 기록하면0/0 인계할 수 있다.
- 송금은 외부에서 사용자가 수행한다. SENT는 사용자가 실제 거래 시각·식별을 입력한 기록이며 은행 API가 송금을 실행하거나 자동 입증한 상태가 아니다. 수령 확인 전 의무를 삭제하지 않는다.

## 적립금과 계좌

| 경로 | 권한·효과 |
|---|---|
| GET /clubs/{id}/reserve | 활성 부원 또는 기존 보관 담당자. balance, available, unbackedAmount, fundsInTransit, 마스킹 계좌, 출처·목적·금액·처리자·일시·names·행동 허용 여부. 전체 예금주명·계좌번호는 제외 |
| GET /clubs/{id}/reserve/transfer-instructions | 관리자 또는 해당 이벤트의 현 담당자가 처리 중인 DEPOSIT 맥락. 송금에 필요한 은행·예금주·계좌번호만 제공 |
| GET /events/{id}/reserve-transfer-context | 현 이벤트 담당자만. clubId, reserveVersion, bankName, maskedAccount, sourceAvailable, maxTransferable, canDeposit, custodianId/custodianNickname 및 해당 이벤트 DEPOSIT만의 deposits. 모임 탈퇴자도 자기 의무를 처리하며 전체 적립금 잔액·다른 출처·내역은 읽지 못함 |
| POST /clubs/{id}/reserve/account | 모임장/관리자의 본인 계좌 검증·AES-GCM 암호화. 기존 보관 업무가 남으면 직접 교체 금지 |
| POST /clubs/{id}/reserve/deposits | 현 이벤트 담당자가 해당 source earmark와 실제 보관금 한도에서 제안. 일반 환불을 적립으로 바꾸지 못함 |
| POST /clubs/{id}/reserve/spends | 관리자 요청. REQUESTED는 가용액만 예약하고 잔액을 바꾸지 않음 |
| POST /clubs/{id}/reserve/reversals | 관리자가 원 이벤트의 확정 적립액에서 미완 반환을 뺀 한도로 실제 반환을 요청 |

entries/{entryId}/sent는 현 이벤트 담당자의 적립 실제 송금, /confirm은 보관 담당자의 실제 입금이다. CONFIRMED 때 적립 잔액을 증가시킨다. 인계받은 미송금 제안은 새 담당자가 이어 처리하고 createdBy와 실제 sentBy를 분리한다.

좁은 context의 deposits는 id/version/amount/purpose/status/createdAt/sentBy/sentAt/confirmedBy/actualAt/canMarkSent/canConfirm만 제공한다. 재시작 후 PROPOSED·TRANSFER_PENDING과 완료 확인을 이어 읽으며, 원 거래 reference/예금주명/전체 잔액은 포함하지 않는다. 담당자 변경 시 이전 담당자는 이 context를 읽지 못하고 새 현담당자가 기존 제안을 이어 처리한다. canMarkSent는 실제 송금 사실 기록 허용이며 canDeposit(신규 제안 가능 여부)와 구분한다.

SPEND/DISSOLUTION의 /execute는 보관 담당자의 실제 출금 확인이며 그때 잔액을 차감한다. 본인 요청도 실제 거래가 필요하다. REVERSAL의 /execute는 TRANSFER_PENDING으로 잔액만 차감하고, 당시 실제 수령 대상인 이벤트 담당자가 /confirm해야 COMPLETED와 source earmark 해제를 기록한다. 실제 수령 전 이벤트 현금을 늘리지 않는다. /cancel은 PROPOSED/REQUESTED만 허용한다.

보관 담당자가 모임을 나가도 기존 실제 계좌 의무를 처리할 접근을 유지한다. 보관 계좌 인계는 현재 보관 담당자가 적격 관리자 후보에게 제안·수락·실제 송금·새 계좌 검증/실수령 확인을 거친다. FUNDS_PENDING 동안 적립 총액은 보존하되 available=0이며 다른 신규 사용 요청을 막는다. 계좌 행 ID는 교체 후에도 같으므로 은행 계좌 identity로 간주하지 않는다.

## 이벤트 담당 인계

GET /events/{id}/handover-candidates는 현 담당자에게 [{id,nickname,departed}]를 반환한다. 활성 계정이고 현재 모임 관리자이거나 everConfirmed 참여 이력이 있는 후보만 허용하며 본인은 제외한다. 취소·탈퇴 참가자도 기존 금융 관계로 선택할 수 있고 개인 차단은 금융 권한을 없애지 않는다. 무관한 일반 부원은 제외한다.

POST /events/{id}/handovers에는 version(이벤트), bookVersion, candidateId, inventoryAmount, inventoryNote를 보낸다. 서버는 실제 현금, 이미 후보가 받은 현금, 미회수 선지출 채권자별 의무, 일반 환불, 추가 수금, 미확인 거래, 이의 상태를 명세로 생성한다. 입력 금액은 현재 담당자의 실제 cashHeld와 정확히 일치해야 한다. 음수 보관금·UNKNOWN·해당 적립 출처 부족은 새 인계를 막는다.

- 후보 /accept → 제안자 /sent → 후보 /confirm. 0원은 수락 후 명세·confirmedAmount=0의 명시 확인으로 완료한다.
- 권한은 실제 수령/0원 확인 뒤에만 이전한다. 후보는 이벤트 정산 권한만 받고 모임 관리권한은 받지 않는다.
- /decline은 PROPOSED 후보, /cancel은 PROPOSED/ACCEPTED 제안자만 가능하다. 이미 실제 송금한 FUNDS_PENDING은 취소로 지우지 않는다. 송금 전 오래된 제안은 거절/취소해 목록을 정리할 수 있다.
- 명세 이후 book 변경을 확인한다. 실제 송금 후 명세가 달라졌다면 /confirm은 RECEIVED_STALE로 실제 수령만 보존하고 권한은 이전하지 않는다. requiresReproposal=true와 양쪽 현재 보관금을 제공한다.
- 원담당자는 같은 후보에게 현재 남은 자기 현금만 새로 제안한다. 이전 실제 송금액을 다시 청구하지 않는다. 후보가 최신 전체 명세를 수락하고 추가 현금 실수령/0원 확인을 마치면 이전하며 과거 stale 기록은 SUPERSEDED로 남긴다.

handover.inventory는 디코딩된 객체다. 금액 원본은 보존하되 names와 proposerNickname/candidateNickname은 현재 모임/서비스 닉네임으로 표시한다. currentInventory는 현재 양쪽 cashHeld·ready·unbackedAmount이며, bookVersion은 후속 반환 업무에 사용하고 version은 인계 행 버전이다.

### 변경된 명세를 거절한 후보의 실제 반환

POST /handovers/{id}/returns {version:book,amount,reason}. RECEIVED_STALE 후보만 원래 실제 수령액에서 이미 반환 예약·송금한 액수를 뺀 한도와 현재 보관금 한도 안에서 요청한다. /returns/{returnId}/sent는 후보 실송금, /confirm은 원담당 실수령, /cancel은 후보의 REQUESTED 취소다. SENT는 후보 보관금만 차감하고 CONFIRMED 때 원담당 보관금을 늘린다. 전액 확인 뒤 RETURNED로 남긴다.

## 선지출 반환과 자기 회수

GET /events/{id}/advances는 version(book), responsibleId, ready, liabilities, custody, repayments, recoveries, names를 제공한다. 현 담당자/활성 부원은 공개 금융 내역을, 탈퇴자·비부원은 자기 관계의 내역만 읽는다. 사유·거래 식별은 해당 당사자/담당자에게만 제공한다.

| POST 경로 | 입력·권한 |
|---|---|
| /events/{id}/advances/self-recoveries | {version,amount,reason}. 현 담당자 본인의 actual cashHeld와 advanceDue 및 예약액 한도 내 명시적 SELF_RECOVERY |
| /events/{id}/advances/repayments | {version,creditorId,amount,reason}. 현 담당자가 순채권·실제 가용 현금 안에서 REQUESTED 생성. 본인은 SELF_RECOVERY 사용 |
| /events/{id}/advances/repayments/{id}/sent | {version,reference,actualAt}. 현 담당자의 실제 송금, 실제 payerId 보존 |
| 같은 경로 /confirm | 기존 채권자의 실제 수령 확인 |
| 같은 경로 /cancel | 현 담당자의 REQUESTED만 취소 |

SELF_RECOVERY는 비현금 회수 원장이며 은행 거래 식별을 만들지 않는다. 일반 환불 의무를 없애지 않는다. 실제 선지출 SENT는 송금자의 보관금과 경제 순채권에 반영하지만 채권자의 CONFIRMED 전까지 수령 확인 업무를 유지한다. 후속 수금·정정 후의 잔여 채권은 항상 canonical reconcile에서 다시 읽는다.

## 인계 완료 뒤 남은 보관금

과거 실제 입금 정정은 당시 processedBy의 cashHeld를 바꿀 수 있다. 이를 숨기거나 권한 인계를 반복하지 않는다.

GET/POST /events/{id}/custody-transfers는 기존 실제 이동 원장의 CUSTODY_TRANSFER다. POST {version:book,amount,reason}; 수령자는 서버가 현 responsibleId로 고정하며 이전 실제 보관자는 자기 보관금에서 이미 예약한 이체를 뺀 금액만 요청한다. /{transferId}/sent, /confirm, /cancel은 같은 실제 송금/수령 계약이다. responsibleId와 개인 선지출 회수 A는 바꾸지 않는다. GET은 당사자 범위의 transfers와 names를 제공한다.

## 정정·부족액·삭제·해산

- trusted FinancialChanged.FACT_CORRECTION은 실제 사실을 보존한다. 원래 실제 송금/지출을 삭제하거나 PERSONAL로 재분류해 부족을 숨기지 않는다. 적격 출처보다 적립 배정이 커지면 unbackedAmount를 표시하고 해결 전 신규 사용·해산·관련 인계를 막는다.
- 일반 ALLOCATION_CHANGE는 기존 source guard를 유지한다. 새 선택으로 이미 적립한 출처를 지우거나 일반 환불을 적립으로 바꾸지 못한다. 이미 발생한 실제 송금/수령 확인은 기록할 수 있다.
- 계정 삭제는 담당 업무·보관금·선지출 순채권·미확인 실제 수령이 남으면 거부한다. ACCEPTED/FUNDS_PENDING/RECEIVED_STALE 당사자와 미완 반환 당사자도 확인할 주체를 유지한다.
- ordinary refund REQUESTED/SENT 수령 당사자 삭제를 막고 CONFIRMED 뒤 해제한다. 미납 참가자 전체 삭제 금지·채권 포기·타인 수령 위임은 새로 확정한 정책이 아니다. 처리가 멈추면 기존 요청/상향 경로를 이용하며 가짜 완료로 우회하지 않는다.
- 모임장 승계는 후보 활성 부원 수락 뒤 완료한다. 이전 모임장이 보관 담당이면 기존 의무를 잃지 않게 ADMIN 역할을 유지한다.
- 해산 지급은 잔여 적립금 전체를 모임장 귀속 REQUESTED로 만든 뒤 실제 정리·확인을 남긴다. 잔액0·입출금 확인 완료·source earmark 이전 완료·계산 마감·담당자 유지가 필요하다. 남은 미납·환불·이의/선지출 의무와 기록은 유지하며 참가자 미지급 환불을 적립금으로 바꾸지 않는다.

## 버전·보안·검증 범위

금전 POST는 UUID Idempotency-Key를 사용한다. reserve 변경 version은 계좌 버전, advances/반환/공통 보관금 이체는 book 버전, handover 액션은 인계 버전이다. 실제14 이동은 book 버전도 갱신하여 이전 명세를 무효화한다. 잠금은 기존 계정→모임→이벤트→book→업무 행 순서를 따른다.

금액은 정수1..9007199254740991원, 인계 현금은0원도 허용한다. 사유/인계 note는1000자, 실제 거래 reference는200자, 미래 시각·수령이 송금보다 이른 시각은 거부한다. names는 허용된 당사자만 포함하고 일반 원장에 개인 계좌의 다른 거래·분쟁 증빙을 섞지 않는다. 페이지네이션은 기존 원장 전체 조회이며 별도 규모 검증은 미완료다.

현재 거래 중복은 공통 finance_bank_transaction의 ACTOR_FALLBACK scope+reference로 막는다. 동일 담당자의 서로 다른 실제 계좌가 같은 reference를 쓰는 경우를 분리하지 못한다. 공급자의 공식 은행코드/안정된 계좌 identity 계약이 없으므로 reserve 행 ID나 임의 문자열을 verified-bank namespace로 만들지 않는다. 기본 BankOwnershipVerifier는503이며 실제 공급자 어댑터·실계좌 검증은 남은 구현/환경 항목이다. 테스트의 검증 공급자는 명시적 테스트 대역이다.

## 검증 이력

- `movement-context-origin-green-01`: Reserve22/22·Community19/19·CommunityOrigin1/1·Bank2/2 실제 PG/HTTP/WebSocket 선택 회귀44/44 GREEN(실패0·오류0·스킵0). 탈퇴 현담당자의 재시작 적립 행/완료 확인, 정확 인계 안내의 역할·미수락·최신명세·은행미등록·송금후거부, 타참가자 입금→실제 현금 인계→선지출 일부 반환 안내, stale 인계 반환과 정정 후 보관금 추가 전달 안내를 포함한다. 이후 추가한 custodian/양쪽0원 안내/no-store·일반 계좌 비노출, 다른 이벤트의 deposit 미노출 및 공통 반환 SENT 안내 거부는 root 최종 통합 재실행 대상이며 이44개 성공에 포함하지 않는다.

- funding-reserve-red-02: 없는 현금 명세를 받아들이는 실제 HTTP RED. advance fixture는 이전 지급자 필수 조건에서 먼저 실패하여 다음 실행에서 명시 지급자로 수정했다.
- reserve-audit-red-03: 9개 중4개 RED. 신규 advance route 부재, 없는 현금 명세, 실제 보관 인계 중 available 재사용을 재현했다.
- contacts-file-green-reserve-stale-red: 실제 송금 뒤 명세 변경의 수령409 두 사례와 실제 입금 정정의 source guard409를 재현했다.
- bank-green-candidate-red: 정확 인계 후보 picker route 부재를 재현했다.
- finance-reserve-bank-integration-01: Finance27 통과, Reserve의 Spring proxy 필드 직접 참조 오류를 확인하여 ObjectMapper/EventService를 각 서비스에 직접 주입했다.
- funding-permissions-green-custody-file-red: 기본13 통과, 과거 수령 정정 후 추가 보관금 route 부재와 정확 일반 환불 수령자 삭제 허용을 재현했다.
- reserve-file-green-privacy-club-red: 기존15 통과, 일반 예금주명 노출과 탈퇴 담당자의 좁은 적립 맥락 부재를 재현했다.
- reserve-bank-green-review-red: Reserve17/17 통과.
- full-server-audit-red-01: 기존17 통과·독립 리뷰 신규3의 실제 RED를 확인했다.
- backend-review-green-profile-red: 독립 리뷰 회귀 포함 Reserve20/20 통과. 별도 도메인의 수정 후 root 최종 전체 build 결과를 함께 확인한다.

## 독립 리뷰 P2 보완

원래 17개 통과 뒤 독립 리뷰에서 다음 세 결함을 재현했다. full-server-audit-red-01의 Reserve20은 기존17 통과/추가3 실패/오류0였다. 수정 후 backend-review-green-profile-red에서 Reserve20/20 통과를 확인했다.

- REVERSAL/TRANSFER_PENDING의 실제 recipientId는 이후 이벤트 담당 인계로 바뀌지 않는다. 그 정확 수령자의 계정 삭제를 차단한다. 실수령 후 생긴 자기 보관금도 현담당자에게 실제 전달하여 정리해야 삭제할 수 있다.
- 정상 SPEND/DISSOLUTION /execute는 출처 부족 중 거부한다. 이미 발생한 실제 출금은 같은 보관 담당자만 /entries/{id}/record-actual로 기록할 수 있다. {version:reserve,reference,actualAt,actualRecordReason}을 요구하며, amount를 보내면 원 요청액과 정확히 같아야 한다. 실제 금액과 기존 purpose를 바꾸지 않고 동일 은행 식별 중복 가드를 적용한다. actualRecordReason, actualRecordedBy, actualRecordedAt, 기록 당시 unbackedAtActualRecord를 공개 원장에 남긴다. 이는 부족 상태에서 새 사용을 허용하거나 잘못된 사용을 정당화하는 절차가 아니다. REVERSAL은 부족 해소용으로 계속 처리한다.
- entries의 canExecute는 위 부족 검사를 반영하고 canRecordActual은 별도이다. 앱은 '이미 발생한 거래 기록'으로 표시하고 정상 실행 실패를 자동 우회하지 않는다.
- 입금 확인 reference는 교체 가능한 accountId가 아니라 불변 실제 confirmedBy(actor fallback)와 함께 고유해야 한다. 서로 다른 확인자의 같은 reference는 허용하고 같은 확인자의 재사용(앞뒤 공백 포함)은 거부한다. 공개 actualActor fallback의 여러 은행 계좌 구분 한계는 유지하며 client가 namespace를 정하지 못한다.
