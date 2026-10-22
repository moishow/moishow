# 정산 계산 코어 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. User requested implementation in this session; execute inline.

**Goal:** 이슈 #11의 확정 금액 정책을 실행 가능한 순수 계산·테스트·브라우저 예제로 제공한다.

**Architecture:** 원 단위 배분은 money.mjs, 차수/이벤트 계산은 settlement.mjs에 둔다. 서버와 무관한 ESM을 브라우저 계산기에서도 사용한다.

**Tech Stack:** Node >=22, built-in node:test, native ESM, HTML/CSS.

**Spec:** ../specs/2026-10-22-settlement-core-design.md

## Global Constraints

- 정책 정본 docs/product/POLICY.md v1.0. 안전 정수 원화, 비례 곱셈 BigInt.
- 외부 의존성 없음. review/ 접근 금지. develop 대상 issue/11-core 작업.
- 입력 불변·실확인만 반영·0명/부분납부/기지급환불·ID중복 검증.

## Review Focus

- 큰 정수의 비례 곱셈은 정확히 배분하고 합계 안전 범위 초과는 거부: Task1 큰 수/누적 오류 테스트.
- 수령하지 않은 취소 비용은 차감하지 않으면서 의무는 남겨야 함: Task2 pending cancellation 테스트.
- 참석0명 또는 지출0원에서도 금액 보존: Task2 zero attendance/zero expense 테스트.
- 확인 대기·중복 입금·기지급 환불 때문에 이중 환불하면 안 됨: Task2 ledger 테스트.
- 여러 차수의 같은 사용자와 서로 다른 사용자 합산: Task2 overlap/disjoint 테스트.

## Task 1: 원 단위 금액 검증·배분

Files: src/domain/money.mjs, src/domain/settlement.test.mjs, package.json

Interfaces: splitEven(amount, userIds), splitProportionally(amount, weights), assertMoney(value,name), sumMoney(values).

- [x] 테스트 작성: 100/3 → 34/33/33; 10000을 동일비율3명 →3333×3+remainder1; 음수/소수/NaN/중복ID/안전범위초과 오류.
- [x] `node --test src/domain/settlement.test.mjs` 실행. 모듈 부재 또는 assertion 실패를 확인한다.
- [x] 입력 검증과 BigInt 비례 배분을 구현한다.
- [x] 테스트 재실행, 테스트가 실제 정책 값을 확인하는지 검토한다.

## Task 2: 차수·이벤트 순차액 계산

Files: src/domain/settlement.mjs, src/domain/settlement.test.mjs

Interfaces: calculateCancellation(input), settleRound(input), settleEvent(input) — spec의 입력/출력 필드 그대로.

- [x] 취소·미납·0명·초과 취소비·미수령 비용·이벤트 상계·부분입금·확인대기·중복ID·이미환불의 기대 금액 테스트 추가.
- [x] 실패 확인 후 구현한다. 합계 보존을 범위 반복 예제로 검증한다.
- [x] `npm test` 전체 통과, 구 인계/외부거래가 구현된 것처럼 표현하지 않았는지 확인한다.

## Task 3: 계산기·CI·인수 기록

Files: examples/settlement.html, examples/settlement-demo.mjs, .github/workflows/checks.yml, docs/implementation/ISSUES.md

- [x] 100000/20000/4명 예제와 2차40000·납부40000 → 개인 환불10000을 같은 모듈로 브라우저 표시.
- [x] 음수·참석0명·비용초과·기납부 변경 시 계산 결과/오류 메시지 확인. 외부 이체는 실행하지 않는다.
- [x] CI에서 node22 `npm test` 및 `node scripts/check-handoff.mjs` 실행.
- [x] 완료한 체크박스와 검증 수를 기록하고 커밋, push, develop 대상 PR 생성. 해당 이슈는 PR 병합으로 닫도록 연결.

## 실행 결과

2026-10-22 inline 실행. 최초 모듈 부재 실패, 이후 취소 비용 수령 근거/중복 충당 테스트 실패를 확인한 뒤 수정했다. 현재 21개 테스트 통과. 브라우저에서 기본 환불10,000원·기지급 환불 후0원·0명 주최 미충당액을 확인했다. 외부거래·DB는 미구현이며 PR/CI 최종 결과는 브랜치 검증 기록에 기록한다.
