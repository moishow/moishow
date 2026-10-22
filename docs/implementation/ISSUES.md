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

PR19는 develop71251b3에 병합됐다. 현재12는 [DB·계정·모임·참가 계약](IDENTITY-API.md), [진행 계획](IDENTITY-DB-PLAN.md)을 기준으로 한다.
