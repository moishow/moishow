# 모이쇼 작업 지침

1. 현재 정책 정본은 `docs/product/POLICY.md`다. `docs/scenario/`와 화면은 이를 따른다. 2026-10-22 이전 포인트/에스크로/강제 OCR 문구는 현재 요구사항이 아니다.
2. `review/`는 AI 열람·수정 금지다. `.claude/settings.json`의 제한을 유지한다.
3. main은 승인 정책/기준, develop은 개발 통합, 작업은 `issue/<번호>-<주제>`에서 한다. 사용자 요청 없이 기존 브랜치를 삭제·재작성하지 않는다.
4. 디자인은 `design/system/AGENTS.md`·tokens·components를 따른다. 현재 화면은 `design/system/screen_v1/`, 데이터는 `design/system/screen-catalog.json`이다. 생성 파일은 해당 생성기를 수정해 재생성한다.
5. 원화는 정수이며 허용 범위·잔여 분배·금액 보존을 테스트한다. 앱은 외부 송금 성공을 가장하지 않는다. 실제 API가 없는 목업은 화면에 목업임을 표시한다.
6. 관련 이슈·명세·테스트와 함께 작업한다. 기술 기준은 `docs/architecture/TECH-STACK.md`다. Java 서버는 `apps/api`에서 Java25/Gradle Wrapper test/build, 화면은 `node scripts/check-handoff.mjs`로 검증한다. JS 계산 코어는 별도 참고 PR이며 Node를 운영 서버로 채택하지 않는다. 외부 DB/인증/실계좌가 없으면 한계를 보고한다.

7. 사용자 추가 지시(2026-10-22): **모든 구현 전에 원래 요구사항(POLICY/시나리오)·해당 이슈·구현계획을 비교해 불일치를 확인한다.** 작업 중 임의로 정한 기본값·권한·전이·예외·범위 축소는 중앙 결정 원장에 빠짐없이 모으고 서로/정본과 충돌을 재검토한다. 기존 구현이 요구사항과 다르면 요구사항에 맞게 수정하고 회귀 테스트로 검증한 뒤 머지한다. 테스트 통과만으로 요구사항 일치를 대신하지 않는다. 대조표/결정 원장은 `docs/implementation/REQUIREMENTS-AUDIT.md`를 사용한다.
