# 구현 이슈와 브랜치

> 2026-10-22 · 개발 통합 develop · 정책 v1.0

| 순서 | 이슈 | 작업 브랜치 |
|---|---|---|
| 서버 기반 | [#18 Spring Boot 기반과 Java 정산 정책 코어](https://github.com/moishow/moishow/issues/18) | `issue/18-spring-bootstrap` |
| 1 | [#11 정산 계산 코어와 정책 예제 테스트](https://github.com/moishow/moishow/issues/11) | `issue/11-core` |
| 2 | [#12 계정·모임·차수 참가와 서버 권한 계약](https://github.com/moishow/moishow/issues/12) | `issue/12-identity` |
| 3 | [#13 납부 확인·계산 마감·정정·이의의 영속 상태](https://github.com/moishow/moishow/issues/13) | `issue/13-settlement` |
| 4 | [#14 정산 인계·모임 적립금·해산 흐름](https://github.com/moishow/moishow/issues/14) | `issue/14-reserve` |
| 5 | [#15 알림·모임 레벨·무응답·신고 처리 큐](https://github.com/moishow/moishow/issues/15) | `issue/15-platform` |
| 6 | [#16 정책 v1 화면을 모바일 앱과 실연동으로 구현](https://github.com/moishow/moishow/issues/16) | `issue/16-mobile` |

서버 스택은 Spring Boot로 확정했다. #11/PR #17의 JavaScript는 참고 예제로 보존하고, 실제 서버 시작은 #18을 기준으로 한다. #12~#16의 서버 구현도 Java/JPA/Spring Security/STOMP/Quartz 기준이다.

PR19·20·17·21·22에서 서버/Flutter 구현을 통합했다. 서버13/14/15와16의 초기 서버 계약은 실제 교차 회귀 때문에 PR21에서 통합했으며 계획 브랜치14/15를 따로 생성·완료한 것으로 주장하지 않는다. 후속 V11/정확 송금·거절/이력 계약과 앱은 PR22다. 서버168개 전체·후속 표시 DTO5개, Flutter86개·분석/웹/debugAPK 및 정확 PR HEAD의 CI8개가 통과했다. 앱은57화면/12흐름 기준 구현이며 실제 공급자/실기기 수락은 별도다. main은 검증된 통합과 승인 정책, develop은 후속 개발 통합으로 관리하고 실제 머지 상태는 각 PR 기록을 따른다. [진행 계획](REMAINING-EXECUTION.md), [앱 인수표](MOBILE-APP.md), [요구 대조 원장](REQUIREMENTS-AUDIT.md)을 따른다.

기존 #4/#10의 포인트/에스크로·10분동의노쇼·무소속번개 등은 POLICY 확정 모델로 대체됐다. #3의 PASS/토스/CODEF는 옛 후보이며 현재 소셜로그인+SMS·별도계좌예금주확인 및 외부P2P 기록 기준으로 재대조한다. 실제 은행 공급자 어댑터/계약은 미확정503이다. #5는 그룹DM 사용자 확정·구현, 무료0원 기록 가능과 별도‘무료약속’플래그 채택은 구별하며 모임 공개/비공개 검색 정책 답변을 기다린다. 미확정 항목이 있는 이슈를 전부 닫은 것으로 표시하지 않는다.
