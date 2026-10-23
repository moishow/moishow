# 개인 계좌 등록 계약

정책 P09/P10, [구현 대조](BANK-ACCOUNT-PLAN.md). db 프로필·ACTIVE bearer 세션만 허용한다. 전체 계좌번호·예금주 원문을 타인 조회 목록에 제공하지 않는다.

| 경로 | 계약 |
|---|---|
| GET /api/v1/me/bank-account | 미등록 `{registered:false,version:0}` 또는 본인 계좌의 id/version/bankName/accountMasked/holderMasked/verifiedAt |
| POST /api/v1/me/bank-account | `{version,bankName,accountNumber,holderName,verificationId}`와 UUID Idempotency-Key. CODEF VERIFIED 증명을 같은 쓰기 트랜잭션에서 일회 소비 후 등록·교체 |

최초 제출 version=0, 이후 응답 version을 사용한다. 동일 key/본문 재시도는 같은 응답, 동일 key/다른 본문 또는 오래된 version은409다. 본인 계정 잠금으로 교체를 직렬화한다. 계좌번호의 공백·하이픈을 제거한6..30자리 숫자, 은행/예금주는1..100자를 사용한다. 이는 입력 형식 제한이며 해당 은행의 실제 계좌 유효성 검증을 대신하지 않는다. 인증 시작/조회/코드 확인은 [BANK-VERIFICATION](BANK-VERIFICATION.md)을 따른다. 증명은 PERSONAL/null context와 본인·은행·정규화 번호·예금주가 모두 일치해야 한다. 오래된 version이나 저장 실패는 증명 소비도 롤백하며 기존 계좌를 보존한다. 원문 생년월일/코드는 이 최종 POST에 보내지 않는다.

V8은 검증된 계좌 이력을 보존하며 사용자당 current 한 건만 둔다. 원문 계좌·예금주는 `BANK_DATA_KEY_BASE64`의32바이트 키와 매번 새로운 nonce의 AES256-GCM으로 저장한다. 검증/암호화 실패 때 기존 current·version·이력은 변경하지 않는다. 과거 계좌 수정으로 기존 지급 사실을 다시 쓰지 않는다. API 응답과 멱등 응답에는 마스킹만 저장하고 공급자의 검증 참조도 공개하지 않는다.

기존 통합3aee1d5의 기본 BankOwnershipVerifier는503 BANK_PROVIDER_NOT_CONFIGURED다. 해찬 문서에 CODEF 예금주+1원 인증 설계가 존재함을 재확인했으며 [계좌 인증 계약](BANK-VERIFICATION.md)에 따라 후속 issue/3-codef-bank-verification에서 단계별 인증/일회증명을 구현하고 실제PG/HTTP 회귀로 검증했다. 공급자 선정을 새로 기다리는 상태가 아니며 실제 상품 승인/키/은행별 기관코드/운영 호출은 별도다. BankApiTest는 test-only verifier로 DB·HTTP·암호화·권한·실패 보존만 검증하며 실계좌 인증 성공을 의미하지 않는다.

납부/환불/선지출 반환 화면의 전체 송금 정보는 정확한 업무와 송금 주체 검사 후 별도 연결한다. 계좌 등록 완료만으로 외부 송금이나 수령이 완료되지 않는다. 일반 모임 부원에게 전체 계좌를 공개하거나 마스킹된 번호로 송금을 유도하지 않는다.

## 정확한 송금 안내

- GET /events/{eventId}/finance/requests/{requestId}/transfer-instructions: 해당 미완료 ACTIVE 요청의 납부자 본인만 현재 정산 담당자의 검증 계좌를 읽는다. 금액은 Finance.requestView.remaining이고 pendingVerification=true이면 확인 전 입금이 남았다는 뜻이다. 추가 미납으로 단정하거나 중복 송금을 유도하지 않는다.
- GET /events/{eventId}/finance/refunds/{refundId}/transfer-instructions: 현재 정산 담당자만 정확 REQUESTED 환불 수령자의 검증 계좌를 읽는다. 현재 환불 의무보다 큰 요청은 안내하지 않는다.
- GET /handovers/{id}/transfer-instructions: ACCEPTED·양수·최신 book 명세의 현재 제안자만 후보의 검증 개인 계좌를 읽는다. 현재 책임·후보 적격·실제 보관금도 다시 확인한다.
- GET /custodian-handovers/{id}/transfer-instructions: ACCEPTED·양수·최신 reserve 명세의 현 보관 담당자만 후보의 검증 개인 계좌를 읽는다. 모임 보관 계좌 등록을 개인 계좌로 추정하지 않는다.
- GET /events/{eventId}/advances/repayments/{repaymentId}/transfer-instructions: 현 담당자만 정확 REQUESTED 반환 채권자의 검증 계좌를 읽는다. canonical advanceDue·cashHeld와 다른 예약액을 다시 확인하며 해당 건의 자기 예약액은 중복 차감하지 않는다.
- GET /events/{eventId}/custody-transfers/{transferId}/transfer-instructions 및 /handovers/{handoverId}/returns/{returnId}/transfer-instructions: 정확 REQUESTED 송금자만 불변 recipientId의 검증 계좌를 읽는다. 현 보관금·다른 반환 예약액을 다시 확인하며 담당 변경으로 수령자를 바꾸지 않는다.

위 인계/선지출/반환 안내는 purpose/sourceId/amount/bookVersion과 정확 수령 계좌를 반환한다. 보관 담당 인계는 eventId/bookVersion 대신 clubId/reserveVersion이다. 0원 인계는409 EXTERNAL_TRANSFER_NOT_REQUIRED로 안내하고 별도 명세·0원 확인 절차를 따른다. SENT/FUNDS_PENDING/완료 건은 새 송금 안내를 거부한다. 모든 안내는 Cache-Control:no-store이며 GET은 상태·이동·실수령 기록을 만들지 않는다.

응답은 recipientId/accountId/accountVersion/bankName/accountNumber/holderName/verifiedAt/purpose/eventId/해당 업무ID/amount/bookVersion이며 Cache-Control:no-store다. 현재 검증 계좌 미등록은409 RECIPIENT_BANK_ACCOUNT_REQUIRED, 완료/대체/실송금된 업무는409다. 이 조회는 실제 송금·수령 기록을 만들지 않는다. 탈퇴 후에도 정확한 기존 납부 당사자는 읽고, 인계 후 이전 담당자는 신규 환불 송금 안내를 읽지 못한다.

accountId는 안내 수령자의 내부 검증 계좌 이력 ID다. 공급자 canonical 은행 계좌 namespace가 없는 현재, 이 ID를 client가 금융 명령의 cashAccountId에 그대로 넣어 중복 거래 scope를 만들면 안 된다. 실제 거래 claim은 문서화된 actualActor fallback을 사용한다. 같은 actor의 다른 실제 계좌 reference 충돌 구분은 공급자 identity 계약 확인 후 연결한다.

현재 BankApiTest2개는 reserve-bank-green-review-red에서 실제 HTTP/PG 통과했다. 등록·거절 후 기존 계좌 보존·암호화·버전·멱등 및 송금 맥락·탈퇴·담당 변경·종료 업무·모임 상태 DTO를 포함한다. 실제 공급자 성공과 실송금은 검증하지 않았다.


## 2026-10-23 CODEF 검증 근거

Gateway13·BankVerification15를 포함한 전체Java25 Gradle build196개 실패/오류/skip0. 공급자wire대역과실제PG/HTTP를구분한다. Flutter101회귀/분석·TEST/운영web·debugAPK도통과했다. 최신101 TEST GUI에서기존요청복구→정답코드→원번호/예금주재입력→최종등록을수행하고별도실API조회로proof CONSUMED/registered=true/version1/미소비목록0을확인했다. 그전미등록/AWAITING_CODE4회/요청1건상태와대조해재진입에새요청이없음을확인했다. 공급자만test-source transport대역이며운영verifier/코드검사/일회소비는실제서비스다. 실제CODEF·실은행1원송금은하지않았다.
