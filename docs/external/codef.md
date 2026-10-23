# CODEF — 예금주 확인과 1원 계좌 인증

해찬 브랜치에서 2026-07-02 작성한 CODEF 연동 설계를 계승한다. 2026-10-23 원문과 공식 상품 문서·Java SDK를 다시 대조했다. **CODEF는 기존 설계에 명시된 공급자**이며 새로 선정할 후보로 되돌리지 않는다. 실제 상품 계약·운영 키·기관별 사용 승인·실계좌 호출 완료는 별도다.

현재 정책과 구현 계약은 [POLICY](../product/POLICY.md), [계좌 인증 API/수명](../implementation/BANK-VERIFICATION.md)을 따른다. 가입은 소셜 로그인+SMS다. 구 설계의 PASS CI/가입 실명 교차검증은 채택하지 않으며 은행 인증 성공을 가입 실명 인증이나 회비 송금 성공으로 표시하지 않는다.

## 기존 설계에서 유지하는 흐름

1. 사용자가 은행·계좌번호·예금주·생년월일(YYMMDD)을 입력한다. 생년월일은 은행 확인을 위한 일시 입력이며 가입 요구사항으로 확대하지 않는다.
2. 서버가 CODEF 예금주명 인증으로 계좌/identity에 대한 반환 예금주를 확인한다.
3. 서버가 CODEF 1원 이체를 요청한다. 사용자가 은행 앱에서 입금 표시의 코드를 확인한다.
4. 사용자 코드와 CODEF 응답 authCode를 **서비스 서버가 비교**한다. 별도 CODEF 코드 검증 API가 있다고 가정하지 않는다.
5. 유효한 인증 증명을 정확 계좌 등록 목적에 1회 소비한다. 기존 계좌 교체/적립금 등록/실제 인계의 기존 권한·버전·수령 확인도 모두 충족해야 한다.

앱에는 authCode를 반환하지 않는다. 전송 후 결과 불명/timeout은 자동 재전송하지 않는다. 인증이 완료되기 전에는 확인 계좌를 만들거나 기존 계좌를 교체하지 않는다.

## 공식 프로토콜 대조

| 항목 | 확인한 계약 |
|---|---|
| OAuth | `https://oauth.codef.io/oauth/token`, Basic(clientId:clientSecret), form `grant_type=client_credentials&scope=read`; 토큰 유효기간 내 재사용 |
| 예금주명 인증 | `/v1/kr/bank/a/account/holder-authentication`, organization/account/identity 필수, 성공 data.name |
| 1원 이체 | `/v1/kr/bank/a/account/transfer-authentication`, organization/account/**inPrintType 필수**. type0 random4자리, 성공 data.authCode |
| 요청 encoding | 공식 Java connector는 **JSON 문자열 전체를 UTF-8 URL encode**하여 POST. 기존 raw JSON curl 예시는 구현 기준에서 제외 |
| 응답 encoding | 전체 URL encoded인 경우 한 번 decode 후 JSON parse. 이미 raw JSON의 `+`를 공백으로 바꾸지 않음 |
| 성공 판정 | HTTP200뿐 아니라 `result.code=CF-00000` 및 해당 필수 data 검사 |
| timeout | 상품 문서30초. 1원 전송 자동 retry 금지 |
| 이름 비교 | 은행별 이름 바이트 제한은 문서에 존재. 임의 자르기/유사 매칭으로 동일인 판정하지 않음 |

정식 `https://api.codef.io`, 데모 `https://development.codef.io`는 구분한다. 공식 SDK에는 `https://sandbox.codef.io`도 별도 상수로 존재하므로 단순 제3자 언급이라고 기록한 구 문구를 정정한다. 이 두 상품의 실제 지원 도메인·사용 권한은 콘솔에서 확인해야 한다. **데모는 랜덤 성공/실패 데이터이므로 실제 확인 계좌로 등록하지 않는다.** 상품 문서상 데모 일100건, 계좌당1원 인증 일5회 제한이 있다.

두 상품 모두 계정 로그인 자격을 보내는 상품과 다르다. 해당 상품 요청에 connectedId/은행 비밀번호/인증서·RSA publicKey를 임의 추가하지 않는다. 비밀키는 서버 환경 설정으로만 전달한다.

## 은행 기관코드

공식 상품 문서가 연결한 기관표는 상품별 코드 체계가 다르다. 예: 국민 holder0004/transfer004, 우리0020/020, 신한0088/088, 카카오0090/090. 이 예시를 전체 기관의 자동 패딩 규칙으로 일반화하지 않는다. 예금주 가능하지만 1원 이체 미제공인 기관도 있다(SC/토스는 확인한 표 기준). 실제 사용 은행은 **두 상품 기관코드와 지원 상태를 각각 확인**하여 서버 catalog에 설정한다. 공식 예금주 문서의 [기관표](https://docs.google.com/spreadsheets/d/1tIIV4x_a8q5Uiawoz75CjG4fgIPj03sgddOcn9WODuQ/edit?gid=1308271166#gid=1308271166)와 1원 문서의 [기관표 원본 xlsx](https://drive.google.com/file/d/1DInPErDW369UujQPAcCKVoQTusJ5JwVH/view)를 읽어 대조했다(후자는 문서 내 최종2025-07-15이므로 현재 콘솔 재확인 필요). 최신 계약/콘솔 확인 전 기본 catalog는 비워두며 임의 은행을 인증 가능으로 노출하지 않는다.

## 남은 운영 확인

- CODEF 상품 계약·정식 키·상품 사용 승인과 현재 지원 은행 기관표.
- 실제 예금주 이름 반환·점검/거절/한도 오류·실계좌1원 코드의 운영 수락.
- 이 문서의 프로토콜 대역 테스트는 위 운영 확인을 대신하지 않는다.

## 출처

- [공식 예금주명 인증](https://developer.codef.io/products/bank/common/etc/accountHolderAuth)
- [공식 계좌 인증(1원 이체)](https://developer.codef.io/products/bank/common/etc/accountTransferAuthentication)
- [REST 가이드](https://developer.codef.io/common-guide/rest-api), [공식 Java connector](https://github.com/codef-io/easycodef-java/blob/master/src/main/java/io/codef/api/EasyCodefConnector.java), [공식 도메인 상수](https://github.com/codef-io/easycodef-java/blob/master/src/main/java/io/codef/api/EasyCodefConstant.java)
- 저장소 이력: `origin/haechan:docs/external/codef.md`(초기87695c2, 도식1ea252e), `docs/scenario/회원.md`의 계좌등록·인증 설계. 현재 가입 정책은 후속 사용자 확정 사항이 우선한다.
