# 토스페이먼츠 (Toss Payments) — 샌드박스 결제 연동

> 샌드박스 기준 · 2026-07-02 · 운영 전환 시 키를 `live_...`로 교체·재검증. 근거: 공식 문서(하단 링크).

## 목적/역할

토스페이먼츠는 이 서비스에서 **카드·간편결제(네이버페이·카카오페이 등)를 처리하는 PG(전자결제대행사)** 역할을 한다. 브라우저에서 결제위젯 SDK로 결제창을 띄우고, 인증이 끝나면 서버가 승인(confirm) API를 호출해 실제 매입을 확정하는 구조다.

## 샌드박스 준비물

| 항목 | 내용 |
|---|---|
| 클라이언트 키 | `test_ck_...` (브라우저 SDK 초기화용) |
| 시크릿 키 | `test_sk_...` (서버 승인 API 인증용, 외부 노출 금지) |
| 사업자 없이 사용 | 가능 — 이메일·전화번호만으로 개발자센터 가입 시 테스트 키 발급. 회원가입 없이 쓰는 문서용 테스트 키도 있으나 카카오페이 등 일부 수단은 테스트 불가 |
| 환경 격리 | 테스트 키 결제는 실제 매입 없이 가상 처리되며 라이브와 완전 분리 |

## 호출 흐름 (단계별)

1. **SDK 로드**: `https://js.tosspayments.com/v2/standard` 스크립트 또는 npm `@tosspayments/tosspayments-sdk` → `TossPayments(clientKey)`로 초기화.
2. **결제 요청**: `tossPayments.widgets({ customerKey })` → `widgets.setAmount({ value, currency })` → `widgets.renderPaymentMethods({ selector })` → `widgets.requestPayment({ orderId, orderName, successUrl, failUrl, customerEmail, customerName })`로 결제창 오픈.
   - `orderId`: 영문 대소문자·숫자·`-`·`_`·`=` 6~64자, 상점이 생성하는 **멱등 키**
   - `orderName`: 최대 100자
3. **successUrl 리다이렉트**: 인증 완료 시 `successUrl`로 이동하며 쿼리로 `paymentKey`·`orderId`·`amount`가 자동으로 붙는다(실패 시 `failUrl`).
4. **서버 승인(confirm)**: 리다이렉트로 받은 세 값을 서버로 넘겨, 서버가 시크릿 키로 `POST /v1/payments/confirm` 호출 → 최종 승인. **인증 후 10분 이내 호출**해야 하며 넘기면 `EXPIRED`.
5. **웹훅 수신**: 개발자센터에서 웹훅 URL/이벤트(`PAYMENT_STATUS_CHANGED` 등) 등록 시 상태 변경마다 HTTP POST(JSON) 수신. 10초 내 200 응답 필요(미응답 시 지수 백오프 재전송).

## 핵심 엔드포인트

| Method | URL | 인증 | 주요 요청 필드 |
|---|---|---|---|
| POST | `https://api.tosspayments.com/v1/payments/confirm` | `Authorization: Basic base64("{secretKey}:")` (콜론 뒤 빈 비밀번호) | `paymentKey`(필수), `orderId`(필수, 6~64자), `amount`(필수, number) |
| GET | `https://api.tosspayments.com/v1/payments/{paymentKey}` | 동일(Basic) | Path: `paymentKey` |
| POST | `https://api.tosspayments.com/v1/payments/{paymentKey}/cancel` | 동일(Basic) | `cancelReason`(필수), `cancelAmount`(선택) |

## 요청/응답 예시

```bash
curl -X POST "https://api.tosspayments.com/v1/payments/confirm" \
  -u "test_sk_XXXXXXXXXXXXXXXXXXXXXXXX:" \
  -H "Content-Type: application/json" \
  -d '{
        "paymentKey": "5EnNZRJGvNZ1MyPjYellet6L2K0edvbNBpqAo5c",
        "orderId": "MC4yNzcxNTU4NTQ4NDUy",
        "amount": 15000
      }'
```

> `curl -u "{secretKey}:"`는 curl이 자동으로 `Basic base64(secretKey:)` 헤더를 만들어 준다.

성공(HTTP 200) 시 `Payment` 객체 주요 필드:

| 필드 | 설명 |
|---|---|
| `status` | `READY → IN_PROGRESS → DONE`(완료) / `CANCELED`·`PARTIAL_CANCELED`·`ABORTED`·`EXPIRED`(10분 초과)·`WAITING_FOR_DEPOSIT`(가상계좌) |
| `method` | `카드`·`가상계좌`·`간편결제`·`휴대폰`·`계좌이체` 등 |
| `totalAmount` / `balanceAmount` | 최초 결제 금액 / 취소 후 잔액 |
| `paymentKey`·`orderId`·`orderName`·`mId` | 결제·주문 식별자, 상점아이디 |
| `requestedAt`·`approvedAt` | ISO 8601 타임스탬프 |

## 주의점

- **금액 위변조 방지**: `successUrl`로 온 `amount`가 결제 요청 시 값과 일치하는지 서버에서 먼저 확인한 뒤 승인 API 호출(클라이언트 값만 믿지 말 것).
- **멱등성**: `orderId`는 주문마다 고유. 승인 재시도 시 상태를 먼저 조회해 중복 승인 방지.
- **웹훅 신뢰 검증**: 웹훅 payload만으로 확정하지 말고 `GET /v1/payments/{paymentKey}`로 재조회. `payout.changed`/`seller.changed`에는 `tosspayments-webhook-signature`(HMAC) 헤더 포함.
- **시크릿 키 보호**: `test_sk_`/`live_sk_`는 서버에서만 사용.

## 공식 문서

- [결제 흐름 이해하기](https://docs.tosspayments.com/guides/v2/get-started/payment-flow)
- [JavaScript SDK 레퍼런스](https://docs.tosspayments.com/sdk/v2/js)
- [코어 API 레퍼런스(승인 등)](https://docs.tosspayments.com/reference)
- [API 키](https://docs.tosspayments.com/reference/using-api/api-keys) · [인증 헤더](https://docs.tosspayments.com/reference/using-api/authorization)
- [웹훅 연결하기](https://docs.tosspayments.com/guides/v2/webhook)
- [회원가입/사업자번호 없이 테스트](https://docs.tosspayments.com/blog/how-to-test-toss-payments)
