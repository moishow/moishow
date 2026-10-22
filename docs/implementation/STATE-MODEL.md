# 상태·권한 계약

> 2026-10-22 · 구현 전 계약 · [정책](../product/POLICY.md)

## 식별자·원장 경계

`userId`, `clubId`, `eventId`, `roundId`, `participationId`, `requestId`, `paymentId`, `refundId`, `settlementId`, `revisionId`, `caseId`, `handoverId`, `reserveEntryId`는 별개 ID다. 금융 원장을 운영한다는 주장이 아니라 앱의 확인/정정 이력을 보존하는 데이터 계약이다. 닉네임으로 데이터를 연결하지 않는다.

| 엔티티 | 상태 | 핵심 전이·금지 |
|---|---|---|
| 차수 참여 | confirmed / waitlisted / late_requested / rejected / cancelled / no_show | 정원 내 즉시 확정, 미납 자동 취소 금지, late 요청 승인 전 회비 생성 금지, 거절은 미확정 late 요청만·비용/점수 없음 |
| 납부 요청 | unpaid / pending_verification / partial / paid | 신고와 실확인 분리, 확인 입금 중복 금지, 잔여액은 실제 확인액 기준 |
| 환불 | requested / sent / received | 실제 외부 송금·수령 확인, 계산 마감으로 미수령 소멸 금지 |
| 정산 계산 | draft / registered / closed | 72시간 최초 등록, closed 원본 수정 금지, revision 추가 |
| 이의 | open / reviewing / accepted / rejected / withdrawn | 정산 마감과 별개, 당사자/처리자만 증빙 |
| 인계 | proposed / accepted / funds_pending / completed | 실제 입금/0원 확인 후에만 정산 권한 이전 |
| 적립 입금 | proposed / transfer_pending / confirmed | confirmed 전 잔액 미반영 |
| 적립 사용 | requested / executing / completed / cancelled | 목적/금액 등록만으로 잔액 차감 금지 |
| 모임 | active / dissolving / dissolved | 잔액0·입출금확인·계산마감·담당유지, 과거 처리 의무 보존 |

## 역할 권한

| 행위 | 참가자 | 이벤트 담당 | 모임장/관리자 | 계좌 확인 담당 | 운영자 |
|---|---|---|---|---|---|
| 자기 요청 납부 신고·환불 수령·이의 | 가능 | 자기 몫 가능 | 자기 몫 가능 | 자기 몫 가능 | 임의 대신 확인 불가 |
| 해당 이벤트 실제 입금 확인·정정 | 불가 | 가능 | 역할만으로 자동 부여 안 함 | 적립금에 한함 | 대리 처리 범위·증빙 필요 |
| 인계 인수 | 해당 이벤트 참여자 수락 | 제안 가능 | 수락 가능 | 역할만으로 자동 인수 안 함 | 실제 돈 인계 위조 불가 |
| 적립금 사용 요청 | 불가 | 주최 역할만으론 불가 | 가능 | 모임장/관리자 자격으로 가능 | 임의 사용 불가 |
| 적립 입금/사용 완료 확인 | 불가 | 불가 | 지정 확인 담당만 | 실제 거래 후 가능 | 임의 확인 불가 |
| 분쟁 증빙 열람 | 당사자일 때 | 해당 건 처리자일 때 | 해당 건 대리 처리자일 때 | 해당 건 당사자일 때 | 담당 건 필요한 범위 |

## 중복·동시성·정정

서버는 모든 쓰기에 요청 식별자와 리소스 버전을 사용한다. 입금 ID는 확인 누적에 한 번만 포함한다. 재시도는 같은 결과를 반환하고 중복 입금·점수 이벤트를 생성하지 않는다. 인계 완료 직전 새 입금/환불이 발생하면 금액 버전을 다시 확인하고 일치 전 권한 이전을 막는다. 영속 저장과 동시성 검증은 후속 서버 이슈의 필수 인수 기준이다.

## API 작업 단위

- 참여: create participation / request late join / approve late join / cancel participation.
- 회비: create round request / report payment / verify payment(amount, actualReceivedAt) / extend deadline.
- 정산: register expenses / preview settlement / register first settlement / close calculation / append revision.
- 환불/이의: request refund / mark sent / confirm received / create case / resolve case / escalate.
- 인계: propose / accept / publish inventory / confirm funds and transfer role.
- 적립금: designate account/custodian / propose deposit / verify deposit / request spend / confirm spend / finalize dissolution transfer.

이 문서는 API 작업 경계이며 실제 엔드포인트·DB·인증 서버가 배포된 것은 아니다. 모든 공급자 호출·권한은 후속 이슈에서 서버 계약으로 검증한다.

## 앱16 신청 결정 개인정보 경계

가입 PENDING → ACTIVE(승인) 또는 REJECTED(거절). 기존 가입 재신청·초대·강퇴 이력·블랙리스트 우선순위는 유지한다. 합류 LATE_REQUESTED && everConfirmed=false → REJECTED는 현재 활성 원주최자만 가능하며 정산 인계로 운영권을 넘기지 않는다. 거절 사유·신청 메모는 본인/해당 현재 처리 담당자만, 일반 소개·다른 부원·정산담당자 일반 참가목록에서는 비공개다. 신청·승인·거절은 별도 이력이며 기존 확정 참가를 거절·비용·노쇼로 변환하지 않는다.
