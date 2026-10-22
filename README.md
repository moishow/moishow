# 모이쇼 — 외부 송금 기반 모임 정산

> 2026-10-22 · main: 사용자 승인 기준 · develop: 개발 통합

모임·정모·번개의 차수별 회비 요청, 납부 신고·실입금 확인, 이벤트 단위 최종 정산을 연결한다. 앱은 자금을 직접 보관하지 않는다. 구 포인트·에스크로·강제 OCR 모델은 대체되었다.

## 바로 보기
- [제품 정책 정본](docs/product/POLICY.md)
- [현재 시나리오](docs/scenario/README.md)
- [전체 와이어플로우](docs/wireframe.html) · [화면·상태 명세](docs/screens.md)
- [체험 목업](design/system/screen_v1/HOME.html) · [JPEG 목업](design/system/mockups/index.html)
- [구현 로드맵](docs/implementation/ROADMAP.md)

```sh
python -m http.server 18765 --bind 127.0.0.1
# http://127.0.0.1:18765/
node scripts/check-handoff.mjs
```

현재 HTML57개와 JPEG57개는 개발 기준 목업이다. 실제 서버는 apps/api, 운영자 웹은 apps/admin, Flutter 앱은 apps/mobile에 있다. 서버 통합 검증과 실제 공급자/단말 검증은 구분한다. 디자인 tokens/components를 재사용하고, `scripts/build-handoff.py`는 문서·화면 래퍼·보드를 재생성한다. 화면 데이터는 `design/system/screen-catalog.json`, 렌더러는 `prototype.js`다.

## 브랜치

서버 스택은 [Spring Boot + Java25](docs/architecture/TECH-STACK.md)로 진행한다. [apps/api](apps/api/README.md)에서 Gradle Wrapper로 테스트·실행할 수 있다. PostgreSQL/JPA/Flyway와 db 프로필의 계정·모임·참가 API를 추가했다. [인증·권한·재시도 계약](docs/implementation/IDENTITY-API.md)을 따른다. 정산·인계·적립금·알림·채팅·파일·프로필 API를 구현했다. 실제 공급자/단말·앱 역할별 검증은 아래 상태를 따른다.
haechan의 시나리오를 main에 병합하고 2026-10-22 사용자 정책을 반영했다. 신규 dev 대신 기존 develop을 사용한다. dev/design·kyung·mypage의 기존 이력은 보존한다. 작업은 develop의 `issue/<번호>-<주제>`에서 시작하고 PR 대상도 develop이다. 과거 모델은 Git 이력에서 확인한다.


## 구현과 검증 상태

서버는 Java25/Gradle/Boot4.1.1, 실제 PostgreSQL17/Flyway V1~V11을 사용한다. 2026-10-22 전체 `build`에서 테스트168개가 실패·오류·생략 없이 통과했다. 임의 기본값/권한/예외는 [요구 대조 원장](docs/implementation/REQUIREMENTS-AUDIT.md)에 기록하고 원본 정책과 함께 검토한다.

- [납부·지출·정정·이의](docs/implementation/FINANCE-API.md): 원본 보존, 개인 지출 출처·선지출 회수, 실제 입금 시각, 비참가 주최자 부담.
- [인계·적립·해산](docs/implementation/RESERVE-API.md): 실제 수령 뒤 책임 이전, 반환 의무 인계, 출처 부족·기존 실거래 보존.
- [알림·레벨·운영](docs/implementation/PLATFORM-API.md): Quartz/outbox, FCM 어댑터, 정확한 사건 담당자 권한. 운영 웹은 React/TypeScript/Vite 검사·빌드 통과.
- [채팅·피드·홈](docs/implementation/COMMUNITY-API.md), [보호 파일](docs/implementation/FILES-API.md), [개인 계좌](docs/implementation/BANK-ACCOUNT-API.md).
- [Flutter 앱](docs/implementation/MOBILE-APP.md): 57화면 흐름·실제 서버 역할별 연동 검증 진행 중. 앱 배포/실기기 완료를 의미하지 않는다.

실제 소셜/SMS/FCM/S3 성공·실기기 수신·배포는 별도 환경 검증이다. 예금주 확인 공급자 어댑터는 계약 확인 전 미완료503이며, 키만 넣으면 성공하는 상태로 설명하지 않는다. 현재 실제 은행 거래 reference는 문서화된 ACTOR_FALLBACK 범위를 사용한다.
## 정책 계산 참고 예제 — 이슈 #11

```sh
npm test
npm run check:handoff
```

[실행 가능한 정산 계산기](examples/settlement.html)에서 같은 계산 모듈을 확인한다. [설계](docs/superpowers/specs/2026-10-22-settlement-core-design.md) · [실행 계획](docs/superpowers/plans/2026-10-22-settlement-core.md).

JavaScript 코어는 정책 산술과 정적 예제 검증용이다. 운영 서버는 Java25/Gradle의 Spring Boot이며, 실제 납부·환불·선지출·인계 상태 원장을 이 예제로 대신하지 않는다.
