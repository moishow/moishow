# CODEF (코드에프) — 1원 계좌인증 (샌드박스)

> 샌드박스 기준 · 2026-07-02 · 데모(`development.codef.io`)와 정식(`api.codef.io`)은 키·도메인이 분리됨. 근거: 공식 문서(하단 링크).

## 목적/역할

CODEF의 계좌 API 두 상품을 조합해 **"출금 계좌 소유주 확인 + 점유(실사용) 인증"**을 구현한다.

| 상품 | 역할 |
|---|---|
| **예금주명 인증(계좌 실명 인증)** | 계좌번호 + 실명확인번호(생년월일/사업자번호)가 **모두 일치**할 때만 예금주명 반환 → 출금 계좌 소유주(=예금주) 확인 |
| **계좌 인증(1원 이체)** | 계좌로 1원을 송금하며 입금자명 자리에 인증코드를 실어 보냄 → 사용자가 은행 앱/문자에서 코드 확인·입력 → 계좌 점유(실사용) 인증 |

두 API 모두 인증서/ID·PW 로그인 없이 **은행망 실시간 단건 조회**로 동작하며, 조회형이라 **connectedId·RSA 암호화가 필요 없다**(계정 등록류 API와의 차이점 — 아래 주의점).

## 샌드박스 준비물

| 구분 | 값 |
|---|---|
| 정식 base URL | `https://api.codef.io` |
| 데모(샌드박스) base URL | `https://development.codef.io` |
| OAuth 토큰 발급 | `https://oauth.codef.io/oauth/token` |

- CODEF 가입 후 **마이페이지 > 키 관리**에서 `clientId`·`clientSecret`·`publicKey` 확인(데모/정식 키 별도).
- 일부 3rd-party 문서에 `sandbox.codef.io`도 언급되나 공식 개발가이드는 데모 도메인을 `development.codef.io`로 명시 — **실제 배정 도메인은 콘솔에서 확인**.
- `publicKey`(RSA)는 계정 등록·빠른 거래내역 등 **로그인 자격 전송 상품**에서만 사용. 1원 계좌인증류에는 불필요.

## 호출 흐름 (단계별)

1. **OAuth2 토큰 발급** — `POST https://oauth.codef.io/oauth/token`, 인증 `Basic base64(clientId:clientSecret)`, body `grant_type=client_credentials&scope=read`. `accessToken`은 **1주일 유효** → 캐싱 재사용. ⚠️ 응답 바디가 **URL-encoded**로 내려오므로 디코딩 후 JSON 파싱.
2. **RSA 암호화** — 이 상품에는 해당 없음(비밀번호·인증서 필드 미전송).
3. **connectedId** — 이 상품에는 해당 없음(로그인 정보 없이 계좌번호로 직접 조회).
4. **예금주명 인증** (선택적 선행) — 계좌번호 + 실명확인번호 일치 시 예금주명 반환.
5. **1원 송금 → 사용자 입력값 대사 (2-step)** — (1) `transfer-authentication`으로 1원 송금 + `authCode` 발급받아 서버 임시 저장, (2) 사용자가 입금 내역에서 본 코드를 입력 → **서버가 저장한 authCode와 입력값을 직접 대사**(이 검증은 CODEF API가 아니라 **서비스 자체 로직**. 별도 검증 API 존재 여부는 콘솔/기술지원 확인).

## 핵심 엔드포인트

| 상품 | Method | URL (데모 / 정식) | 인증 | 주요 요청 필드 | 주요 응답 |
|---|---|---|---|---|---|
| 액세스 토큰 | POST | `https://oauth.codef.io/oauth/token` | Basic(clientId:clientSecret) | `grant_type=client_credentials`, `scope=read` | `access_token` (URL-encoded) |
| 계좌 인증(1원) | POST | `…/v1/kr/bank/a/account/transfer-authentication` (`development` 또는 `api`.codef.io) | Bearer accessToken | `organization`(기관코드,필수), `account`(계좌번호,'-' 없이,필수), `inPrintType`(기본 "0"), `inPrintContent`(조건부) | `authCode`(인증코드) |
| 예금주명 인증 | POST | `…/v1/kr/bank/a/account/holder-authentication` | Bearer accessToken | `organization`(필수), `account`(필수), `identity`(생년월일 6자리/사업자 10자리,필수) | `name`(일치 시에만) |

상품 경로는 `/v1/kr/bank/a/...`로 고정이나 파라미터가 수시 업데이트되므로 **호출 전 콘솔 최신 문서 재확인 권장**.

## 요청/응답 예시

**토큰 발급**
```bash
curl -X POST "https://oauth.codef.io/oauth/token" \
  -H "Authorization: Basic $(echo -n "$CLIENT_ID:$CLIENT_SECRET" | base64)" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&scope=read"
# 응답 바디는 URL-encoded → 디코딩 후 JSON 파싱
```

**1원 계좌인증(송금) — 데모**
```bash
curl -X POST "https://development.codef.io/v1/kr/bank/a/account/transfer-authentication" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json;charset=UTF-8" \
  -d '{ "organization": "0012", "account": "1002940540000", "inPrintType": "0", "inPrintContent": "" }'
```

응답(공통 envelope + 데이터, URL-decoding 필요):
```json
{
  "result": { "code": "CF-00000", "message": "성공", "transactionId": "f41d087dd6314" },
  "data": { "authCode": "5673" }
}
```

**예금주명 인증**
```bash
curl -X POST "https://development.codef.io/v1/kr/bank/a/account/holder-authentication" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json;charset=UTF-8" \
  -d '{ "organization": "0020", "account": "1002000111222", "identity": "900101" }'
# 응답 data: { "name": "홍길동" }
```

## 주의점

- **응답 URL-encoding**: OAuth 토큰 포함 CODEF 응답 바디는 URL-encoded 사례가 다수 → 파싱 전 반드시 디코딩(`URLDecoder.decode`/`decodeURIComponent`).
- **RSA 필드**: 위 두 상품은 RSA 암호화 대상 없음. `publicKey`/RSA는 계정 등록·빠른 거래내역 등 별도 상품에서만.
- **데모/운영 분리**: 데모는 **일 100건 무료**이나 실제 인증코드/예금주명이 아닌 **랜덤 성공/실패 테스트 데이터**만 반환 → 실계좌 QA는 정식 키 승인 후.
- **호출 제한**: 1원 이체 계좌인증은 **계좌번호당 1일 5회**.
- **은행망 의존**: 은행 점검 시간대 이용 불가.
- **교차검증 활용**: 예금주명 인증(소유주) + 1원 이체(점유)를 함께 쓰면 "명의 일치 + 실사용자 본인 확인" 이중 검증.
- **입력값 검증은 자체 로직**: 사용자 입력 코드와 `authCode` 대사는 서비스 서버가 수행(별도 검증 API 여부는 CODEF 기술문의 확인).

## 공식 문서

- [개발가이드 홈](https://developer.codef.io/) · [공통가이드(REST API/토큰)](https://developer.codef.io/common-guide/rest-api) · [커넥티드 아이디](https://developer.codef.io/common-guide/connected-id)
- [계좌 인증(1원 이체)](https://developer.codef.io/products/bank/common/etc/accountTransferAuthentication) · [예금주명 인증](https://developer.codef.io/products/bank/common/etc/accountHolderAuth)
