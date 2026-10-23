# 남은 이슈 연속 실행 — 2026-10-22

사용자: 검증되면 PR을 모두 머지하고 나머지 이슈를 계속 구현. PR20은 develop bc32bb6에 머지했다. Java25/Gradle/Boot4.1.1, PostgreSQL17 유지. review/ 금지, 외부키 없는 성공 가장 금지. 서버 통합 PR21은 전체158개 테스트·CI6개·독립 검토 후 develop743478a에 머지했다. 앱/후속 계약 PR22는 CI8개 확인 후 develop e84f1f1에 통합했다. main 통합 PR23도 exact HEAD CI8개 확인 후 병합하여 main/develop은3aee1d5로 일치한다. 후속 CODEF는 issue/3-codef-bank-verification에서 진행한다. 소유 파일만 선택 커밋/PR/검증 후 develop에 머지한다. 여러 작업 파일이 공존하므로 git add -A와 타 작업 파일 삭제/덮어쓰기를 금지한다.

## 작업과 파일 경계

-13: FinanceModels/FinanceService/FinanceController, V2__finance.sql, FinanceApiTest, FINANCE-API.md. 신고/확인 분리, 원본 보존 정정, 이의 접근, 순차액·환불 이력, 멱등·버전·동시성.
-14(root): ReserveModels/ReserveService/ReserveController, V3__reserve.sql, ReserveApiTest, RESERVE-API.md. 실제 인계/0원 확인 후 담당이전, 적립/사용 실확인, 잔액0/입출금 확인 후 모임장 귀속 해산, 기존 의무 유지.
-15: PlatformModels/PlatformService/PlatformController/PlatformJobs, V4__platform.sql, PlatformApiTest, PLATFORM-API.md 및 apps/admin. 인앱/푸시 분리, 묶기, 점수 중복·보류·회복·정정,24/72h 큐, 관리자 자기신고 방지. Quartz JDBC와 outbox 재시작 보존.
-16: apps/mobile 전용 Flutter 실제 앱(홈/피드/중앙 만들기/채팅/마이·57 화면 흐름), 앱 SDK 설치/테스트/빌드. identity/finance/platform REST 계약 사용, STOMP 혼용 금지. 환경/키/실기기 검증 한계 기록.

## 공통 인터페이스·잠금

새 서버 기능은 package com.moishow.identity에서 Store/Commands/Models를 사용한다(기존 파일 수정은 root에게 요청). Actor는 서비스 세션 주체. 업무 POST는 Commands.run(actor,operation,key,body,action) 사용. 잠금 순서 account→club→event→book/reserve→child, 타 사용자 account 잠금 금지. 조회는 트랜잭션 및 관계 검사. 상태·민감 증빙 DTO를 분리하고 회원·담당·본인 권한을 매번검사한다.

Finance book 계약: settlement_book(id uuid,event_id uuid unique,version bigint,status varchar,first_registered_at timestamptz), 엔티티 FinanceModels.Book. 모든 financial mutation은 book.version 증가. root 인계는 book version을 inventory에 저장하고 최신 버전과 일치/수령 확인 후 responsibleId만 변경한다. 금액 계산 Java SettlementCalculator 재사용, 실제 받은 비용만 반영. 서버 내부 신뢰할 수 있는 스케줄링 외 쓰기 사용자권한 생략 금지.

API 공통 /api/v1, 오류400/401/403/404/409/429/503. 테스트는 실제 PostgreSQL Testcontainers. 테스트 대역은 테스트 소스에만, Docker 없으면 조용히skip 금지. 외부 이체/인증/푸시를 미연결인데 완료로표시하지 않는다.

## 진행

- [x] PR20 머지.
- [x] 서버13/14/15와 앱16 서버 계약 구현·전체158개 테스트·독립 검토(PR21).
- [x] 앱16 코드/후속 서버 계약,86개 회귀·분석/웹/debugAPK·대표 실제 역할 GUI 검증. 외부 수락은 별도.
- [x] 참고 PR17 충돌 해결·22개 Node 테스트/CI 후 develop 머지. 서버 PR21 CI/머지.
- [x] 앱16 PR22/CI8개/독립 검토 후 develop e84f1f1 머지.
- [x] 기존3/4/5/10의 정책 대체/미결 근거를 ISSUES·감사 원장에 기록. 계좌 연동3/공개범위5는 OPEN 유지. CODEF는 해찬 설계에 명시된 공급자이며 선정 미정이라는 이전 설명을 정정했다.
- [x] 서버168·Flutter86·운영웹/모바일 빌드와 대표 실제 PG/GUI 권한 검증. 전체 실단말/공급자 수락은16에 유지.
- main 통합은 해당 PR의 CI·merge 기록으로 판정하고, 실제 main/develop SHA와 남은 외부 수락을 vault에 기록한다.

공급자 실제키·사용자 SMS/푸시 수신·실계좌·서명키·실기기/스토어 배포는 외부 환경이 필요한 검증이며 코드완성과 구분한다. 해당 제한은추적이슈로 유지하며 미검증범위를 지워서 모두완료로 보이게하지 않는다.

## 사용자 감사 지시 반영

새 구현/머지 전 REQUIREMENTS-AUDIT.md를 우선한다. 기존 구현에서 발견한 원요구 이탈을 먼저 수정하며, 누락 요구를 임의로 후속 제외하지 않는다. 서버13은 PR21의 전체검증·검토 근거로 통합됐고, 앱16 코드는 PR22/23으로 통합됐고 실제 공급자/단말 수락은 OPEN이다. 57행/도메인별 증거를 채운 뒤 단계별 검증/머지한다.

## 통합 PR 경계 조정

후속 요구 대조와 실제 회귀에서 정산13의 선지출·HOST_CONTRIBUTION·시각 점수, 인계14의 실제 현금/반환 원장, 운영15의 신뢰할 수 있는 점수 이벤트, 앱16의 파일/채팅/송금 정보가 교차하는 것을 확인했다. 도메인별 소유 파일·커밋·이슈 인수기준은 유지하되 **서버 변경은 하나의 통합 PR에서 실제 전체 테스트와 독립 도메인 검토 후 병합**한다. 부분 서버에서 교차 회귀를 가짜 공급자/DB 수정으로 대체해 각 PR만 통과시키지 않는다. 서버 통합 PR21에서13/14/15와16의 서버 계약을 명시했고, Flutter 앱16은 별도 앱 PR과 실제 역할별 검증으로 완료한다. 16은 서버 계약만으로 닫지 않는다. main 통합은 전체 확인 뒤 진행하고 기존 브랜치는 보존한다.
