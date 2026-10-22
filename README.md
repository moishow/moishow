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

현재 HTML은 개발 기준 목업이며 운영 앱이 아니다. 실제 인증·실계좌·DB·푸시·서버 권한 검증은 별도 이슈다. 디자인 tokens/components를 재사용하고, `scripts/build-handoff.py`는 문서·화면 래퍼·보드를 재생성한다. 화면 데이터는 `design/system/screen-catalog.json`, 렌더러는 `prototype.js`다.

## 브랜치

서버 스택은 [Spring Boot + Java25](docs/architecture/TECH-STACK.md)로 진행한다. [apps/api](apps/api/README.md)에서 Gradle Wrapper로 테스트·실행할 수 있다. DB·실인증·채팅은 후속 이슈이며 현재는 순수 정산·dev 미리보기 API가 구현 범위다.
haechan의 시나리오를 main에 병합하고 2026-10-22 사용자 정책을 반영했다. 신규 dev 대신 기존 develop을 사용한다. dev/design·kyung·mypage의 기존 이력은 보존한다. 작업은 develop의 `issue/<번호>-<주제>`에서 시작하고 PR 대상도 develop이다. 과거 모델은 Git 이력에서 확인한다.
