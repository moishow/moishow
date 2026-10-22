"""Build current documentation, screen wrappers and flow board from reviewed sources."""
from pathlib import Path
import json
from html import escape

ROOT = Path(__file__).resolve().parents[1]

def write(path, content):
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content.strip() + '\n', encoding='utf-8')

def viewer(path, title, md):
    depth = len(Path(path).parts) - 1
    up = '../' * depth
    write(path, f'''<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{title} — 모이쇼</title><link rel="stylesheet" href="{up}design/system/tokens.css"><link rel="stylesheet" href="{up}assets/doc.css"></head><body><header class="doc-topbar"><a href="{up}index.html">모이쇼 설계 허브</a><span>{title}</span><a href="{md}">원본 문서</a></header><main class="doc-wrap"><div data-md-src="{md}"></div></main><script src="https://cdn.jsdelivr.net/npm/marked@15.0.12/marked.min.js"></script><script src="https://cdn.jsdelivr.net/npm/mermaid@11.17.2/dist/mermaid.min.js"></script><script src="{up}assets/doc.js"></script></body></html>''')

domain_docs = {
'홈': '''# 홈 도메인 — 현재 할 일과 일정
> 2026-10-22 · 정책 P02/P07/P11 · [정책 정본](../../product/POLICY.md)

## 목적과 진입
홈은 지금 할 정산 업무와 다가오는 정모·번개를 모은다. 과거 기록·모임 레벨·설정은 마이로 보낸다. 모임별 컨텍스트를 항상 표시한다.

## 시나리오
1. 홈 진입/복귀 → 할 일 조회 → 송금·입금 확인·환불 확인·이의·정정 요청 중 선택 → 공통 정산 상세 → 완료 후 갱신.
2. 일반 참가자는 자기 요청, 일반 부원 주최자도 자기 이벤트 운영 할 일을 본다. 모임장/관리자 역할만으로 필터링하지 않는다.
3. 날짜 스트립에서 날짜 선택 → 해당 날짜의 참여 일정 → 이벤트 상세. 마이에 캘린더를 중복 배치하지 않는다.
4. 모임·공개 번개 탐색/검색 → 모임 소개 또는 공개 이벤트 → 가입/참여. 팔로우만으로 내부 콘텐츠를 노출하지 않는다.
5. 홈 + → 생성 종류 → 소속 모임 선택 → 공통 정모/번개 작성. 모임 화면의 생성 버튼은 해당 모임을 사전 선택한다.
6. 홈 벨 → 공통 알림센터. 소셜은 묶고 정산 업무는 개별 표시. 푸시 off라도 목록에는 남긴다.

## 상태와 갱신
할 일은 미납/부분 납부/확인 대기/환불 대기/이의/인계 확인 등 업무 상태로 나눈다. 계산 마감 후 남은 일도 표시한다. 송금 성공은 외부 앱 복귀만으로 확정하지 않는다. 푸시 수신·포그라운드 복귀·당겨서 새로고침에 조회하고 상시 폴링은 기본으로 두지 않는다.

## 화면·인수 기준
[화면 목록](../../screens.md)의 HOME/TODO/SCHEDULE/EXPLORE/CREATE/NOTIFICATIONS를 사용한다. 빈 목록·오류·로딩·권한 상실·취소된 이벤트/만료 링크를 확인한다. 일반 부원 주최자에게 자신의 수금 확인이 보여야 한다. 날짜 선택이 마이로 이동하지 않아야 한다.''',
'회원': '''# 회원 도메인 — 계정·기록·레벨·소셜
> 2026-10-22 · 정책 P07/P09/P10/P11/P12 · [정책 정본](../../product/POLICY.md)

## 가입·계좌
소셜 로그인 → 신규면 SMS 인증 → 닉네임·관심사 → 홈. 기존 전화번호로 다른 소셜 가입은 차단하고 기존 로그인 안내. 자동 병합/연결하지 않는다. 예금주 확인은 계좌 등록에서 별도 수행하며 가입 실명/CI를 전제하지 않는다.

## 마이·기록
마이는 프로필·과거 정산 내역·모임 레벨·설정이다. 현재 돈 액션과 일정은 홈에만 둔다. 정산 내역은 같은 이벤트의 개인 단면을 조회하며 새 계산 사본을 만들지 않는다. 탈퇴자·공개 번개 비부원도 자기 참여 정산과 계산 근거·납부·환불 확인·이의 처리를 유지한다.

## 이름·레벨
정산/채팅은 닉네임, 송금에 필요한 예금주명은 별도. 변경 후 과거 화면도 현재 닉네임으로 표시하되 원래 사용자 ID·행위/금액은 보존한다. 탈퇴 후 마지막 닉네임+탈퇴한 멤버. 레벨은 50점 시작·0~100점, 같은 모임/이벤트 관계자만 열람. 납부/주최 이력, 시각·가점·보류는 정책 P12 그대로 적용한다.

## 채팅·차단·신고
개인 대화·모임 상시·이벤트방을 종류 구분해 최근 메시지순으로 통합한다. 개인 채팅의 모르는 상대 첫 메시지는 요청함을 사용한다. 차단은 피드/개인 채팅에 적용하고 정산 권한은 유지한다. 개인 글/사용자 신고는 운영자 처리. 모임장·관리자가 신고 대상인 건도 바로 운영자에게 보낸다.

## 설정·탈퇴
푸시는 모든 종류를 끌 수 있지만 인앱 알림함은 유지한다. 일반 모임 탈퇴와 서비스 계정 삭제를 구분한다. 주최자 계정 삭제는 담당 업무 완료 또는 수락한 인수자의 잔여금 실제 확인 후 허용한다. 개인의 미납만으로 모든 기록을 삭제하거나 주최자 의무를 없애지 않는다.

## 인수 기준
MY/HISTORY/LEVEL/PROFILE/SETTINGS/BANK/CHAT/REPORT/ACCOUNT 화면. 닉네임을 바꿔도 정산이 다른 사람에게 연결되지 않아야 하고, 차단/탈퇴로 자기 정산을 잃지 않아야 한다. 외부 인증은 공급자 연결 전 미연동 상태를 표시한다.''',
'모임': '''# 모임 도메인 — 참여·정산·적립금
> 2026-10-22 · 정책 P02~P08 · [정책 정본](../../product/POLICY.md)

## 관계와 역할
모임 ⊃ 정모/번개 ⊃ 차수. 정모=모임장/관리자, 번개=부원 누구나. 정산 담당은 주최 행위 또는 실제 인계 완료로 정하며 모임 운영 권한과 분리한다.

## 가입·운영
모임 미리보기 → 즉시 가입(닉네임 입력) 또는 승인제 폼 → 가입. 일반 초대는 승인 생략, 강퇴 이력은 초대여도 승인 필요, 블랙리스트는 가입·공개 번개·마감 후 합류 차단. 이력은 해당 모임에만 적용한다. 모임장 승계·관리자 지정·공지·초대·블랙리스트를 모임 운영에서 처리한다.

## 차수 신청·선납
차수 선택 → 정원 내 즉시 확정/초과 대기. 차수별 마감→해당 확정자 회비 요청. 사후 정산은 선납 요청 없이 종료 후 실제 지출을 요청한다. 미납 자동 참여 취소 없음. 마감 후 합류는 본인 요청→주최자 승인→해당자 요청만 생성한다. 주최자 임의 선정·탈락/세션 재오픈을 기본으로 삼지 않는다.

## 취소·변경
차수별 고지 취소 비용=노쇼 비용. 미설정은 0원. 납부자는 비용 차감 환불, 미납자는 비용만 요청. 주최자 취소/날짜 변경 불참은 전액 환불. 비용 변경은 재동의, 거부자는 무료 취소, 미응답 참여 유지·동의 대기·새 비용 미적용.

## 납부·정산
외부 송금→납부 신고→담당자 실제 확인. 부분 납부 인정·잔여 요청. 실입금 시각 미확인은 지연 판정 보류. 지출 항목명/금액/차수 필수·증빙 선택. 받은 취소 비용만 차수 지출에 보태 참석자 분담을 줄인다. 차수별 계산 뒤 이벤트 개인별 합산/기지급 환불 반영, 순차액만 추가 요청/환불한다.

## 0명·초과·지연 수금
0명도 정산 허용, 나누기만 생략. 고지 취소 비용을 넘는 부족분은 주최자 부담으로 표시한다. 취소 비용이 지출보다 많으면 납부 비율 환불, 원 단위 나머지만 적립. 나중에 받은 비용은 담당자가 추가 환불 또는 적립을 선택·알림한다.

## 계산 마감·정정·이의
종료 후 72시간 최초 등록. 미납/이의가 남아도 계산 마감 가능, 업무 기록과 요청 유지. 원본 보존·정정 기록 추가, 납부액 대비 순차액 재계산. 이의는 납부와 병행하며 필요 시 모임장→운영자로 상향한다. 실제 처리 담당자만 분쟁 증빙을 열람한다.

## 인계·해산
모임 탈퇴 후 주최 책임 유지. 인수자 수락→내역/금액→외부 송금→실입금 확인→권한 이전, 0원은 내역/0원 확인. 계정 삭제는 직접 업무 완료 또는 인계 완료 후 가능. 적립금 계좌 담당은 모임장/관리자 중 1명이며 사용 권한은 모임장/관리자만. 실제 입출금 확인 후 잔액 반영한다. 해산 잔액은 모임장 귀속 정리·확인 후 0원으로 만든다. 담당자 유지·계산 마감 시 미납/환불/이의가 남아도 해산 가능, 기록과 의무는 유지한다.

## 인수 기준
JOIN/EVENT/ROUND/JOIN_LATE/PAY/COLLECT/EXPENSE/SETTLE/REFUND/DISPUTE/CORRECTION/HANDOVER/RESERVE/DISSOLVE. 모든 금액은 원화 정수, 참가자 분담+비용 수령+주최 부담과 지출/환불이 보존되는 예제로 검증한다. 모임장 역할만으로 정산 인수를 자동 완료하지 않는다.''',
'피드': '''# 피드 도메인 — 콘텐츠와 공개 권한
> 2026-10-22 · 정책 P09/P10/P11 · [정책 정본](../../product/POLICY.md)

## F1 목록
내 모임 글·공지·이벤트 자동 모집 카드와 팔로우한 사람의 허용 콘텐츠를 모은다. 팔로우는 모임 멤버십을 대체하지 않는다. 비가입 모임의 내부 글·공지·내부 이벤트는 숨긴다. 공개 번개는 허용 정보만 표시한다. 차단 상대의 피드는 숨긴다.

## F2 상세·반응
목록→게시글/이벤트 상세→좋아요·댓글. 개인/모임 소속을 표시한다. 삭제·권한 상실은 안내 상태로 처리한다. 직접 URL 접근도 목록과 같은 권한을 검사한다.

## F3 작성·편집
홈 + 또는 게시판 진입→개인 글/모임 글 선택→본문/사진→미리보기→게시. 모임 글은 소속 확인, 공지는 모임장/관리자만. 모집 카드는 이벤트 개설로 생성하고 직접 중복 작성하지 않는다. 개인 글과 모임 내부 글의 노출 범위를 구분한다.

## F4 신고
모임 글·댓글→해당 모임 관리자 1차→미해결 운영자. 개인 글·사용자 신고는 운영자 직접. 모임장/관리자가 신고 대상이면 바로 운영자. 상세 증빙은 처리 담당자에게 한정하며 신고 결과를 기록한다. 정산 이의와 콘텐츠 신고를 혼합하지 않는다.

## 인수 기준
FEED/POST/COMPOSE/REPORT/MODERATION. 내부 글을 팔로우 경로·공유 링크·검색으로 우회 열람할 수 없어야 한다. 공개 번개 참여자가 모임 일반 게시판 권한까지 얻지 않아야 한다.'''
}
for name, body in domain_docs.items():
    write(f'docs/scenario/domains/{name}.md', body)
    viewer(f'docs/scenario/domains/{name}.html', f'{name} 시나리오', f'{name}.md')

write('docs/scenario/README.md', '''# 모이쇼 시나리오 — 현재 정본
> 2026-10-22 · 사용자 확정 정책 반영 · 구 에스크로 와이어플로우 대체

[정책 정본](../product/POLICY.md) · [화면 목록](../screens.md) · [와이어플로우](../wireframe.html) · [구현 로드맵](../implementation/ROADMAP.md)

모임의 회비를 외부 송금하고 기록·확인한다. 앱 내 포인트/에스크로는 없다. 기획 우선순위는 정책→도메인 시나리오→화면/상태→구현 계약이다.

| 도메인 | 소유·상세 |
|---|---|
| [홈](domains/홈.md) | 현재 할 일·일정·탐색·생성 진입 |
| [회원](domains/회원.md) | 가입·개인 기록·레벨·소셜·설정·채팅 목록 |
| [모임](domains/모임.md) | 가입·이벤트/차수·참여·정산·적립금·인계/해산 |
| [피드](domains/피드.md) | 게시글·반응·모집 카드 노출·콘텐츠 신고 |

알림센터는 공통 모듈이며 홈 벨에서 연다. 주최자 개인 역할과 모임 관리자 권한을 분리한다. 모든 작업 브랜치는 같은 정책 버전을 따른다. 현재 HTML/JPEG는 개발 기준 목업이며 인증·DB·외부 이체의 운영 구현이 아니다.''')

write('docs/problem.md', '''# 모이쇼가 푸는 문제
> 2026-10-22 · 현재 모델: 외부 송금·기록·확인

회비를 단톡방과 개인 계좌로만 관리하면 누가 얼마를 냈고, 어떤 지출과 환불이 남았는지 추적하기 어렵다. 모이쇼는 돈을 직접 보관하는 대신 참여·요청·실입금 확인·증빙·이의·정정 이력을 한곳에 연결한다.

| 사용자 | 필요한 것 | 검증할 결과 |
|---|---|---|
| 참가자 | 납부할 금액·실확인·환불·이의 | 내 차수의 계산 근거와 잔여 의무를 볼 수 있음 |
| 주최자 | 명단·부분 납부·지출·인계 | 실제 받은 돈과 지급액을 중복 없이 관리 |
| 모임장/관리자 | 공동 적립금·신고·대리 처리 | 계좌 담당·사용 권한·기록 열람 분리 |
| 운영자 | 무응답·콘텐츠/분쟁 처리 | 필요한 증빙만 조회하고 조치 근거 보존 |

‘기록이 있다’는 것이 실이체·증빙 진실성을 자동 보장하지는 않는다. 주최자 실제 확인과 이의/정정 경로를 제공한다. 등록 유예나 PG 사용만으로 법적 적합성이 보장된다고 주장하지 않는다.

범위·규칙은 [정책 정본](product/POLICY.md), 동작은 [시나리오](scenario/README.md)를 따른다. 구 포인트·에스크로 설계는 Git 이력에만 남긴다.''')
write('docs/journey-map.md', '''# 고객여정 — 외부 송금과 확인
> 2026-10-22 · [정책 정본](product/POLICY.md)

| 단계 | 참가자 | 주최자/담당자 | 상태와 실패 경로 |
|---|---|---|---|
| 가입 | 소셜·SMS·닉네임 | 모임 생성/역할 확인 | 중복 번호는 기존 로그인 안내 |
| 신청 | 차수 선택·즉시 확정/대기 | 마감 시 확정자 회비 요청 | 마감 후 합류 요청·승인 |
| 납부 | 외부 송금·신고 | 실제 입금액/시각 확인 | 부분 납부·확인 대기·미납 유지 |
| 지출 | 근거 열람 | 항목명·금액 입력·증빙 선택 | 증빙 없음 표시·이의 가능 |
| 정산 | 이벤트 합산 순차액 확인 | 72시간 내 최초 등록 | 미납/이의 있어도 계산 마감 |
| 환불/정정 | 수령 확인·이의 | 실제 송금·append 정정 | 원본 보존·잔여 요청 유지 |
| 이관/종료 | 자기 기록 계속 열람 | 실제 인계 확인·권한 이전 | 해산 후도 의무 유지 |

```mermaid
flowchart LR
 A[차수 신청] --> B[확정 / 대기]
 B --> C[차수 마감과 회비 요청]
 C --> D[외부 송금과 납부 신고]
 D --> E[담당자 실제 입금 확인]
 E --> F[지출 등록과 이벤트 합산]
 F --> G[순차액 요청 / 환불]
 G --> H[계산 마감과 기록 보존]
 H --> I[미납 추적 / 이의 / 정정]
```

실제 사용자 조사로 검증되지 않은 감정 점수는 현재 여정에서 제거했다. 전환·지연·분쟁 지표는 구현 후 실측한다.''')
write('docs/payment-model-comparison.md', '''# 자금 모델 결정
> 2026-10-22 · 결정 완료 · 구 A/B 비교 초안 대체

채택: **외부 P2P 송금 + 앱 요청/신고/실제 확인/정산 기록**. 앱 포인트·에스크로·충전·현금화는 사용하지 않는다. PG 결제 승인을 회비 송금 검증으로 대체하지 않는다.

계좌 등록 시 예금주 확인은 별도 연동 대상이다. 소셜/SMS와 계좌 신원을 자동 동일시하지 않는다. 공급자 계약/API 검증·개인정보 처리·법률 검토는 운영 전 과제이며 특정 연동만으로 적합성을 단정하지 않는다.

구 결제 API 문서는 [외부 연동 참고](external/README.md)로 한정한다. 개발 기준은 [정책](product/POLICY.md), [로드맵](implementation/ROADMAP.md)이다.''')

for p in ('toss-payments.md', 'codef.md', 'portone-identity.md'):
    path = ROOT / 'docs/external' / p
    text = path.read_text(encoding='utf-8')
    if not text.startswith('> 참고 자료'):
        text = '> 참고 자료 · 구 결제모델 연동 조사. 현재 구현 계약이 아니며 호출 예제는 공급자 최신 문서로 재검증해야 한다. 현재 가입은 소셜+SMS, 예금주 확인은 별도이며 앱은 자금을 보관하지 않는다.\n\n' + text
    if p == 'toss-payments.md':
        text = text.replace('test_ck_', 'test_gck_').replace('test_sk_', 'test_gsk_').replace('live_sk_', 'live_gsk_')
    path.write_text(text, encoding='utf-8')
write('docs/external/README.md', '''# 외부 연동 참고와 실제 구현 경계
> 2026-10-22

현재 모델은 소셜 로그인+SMS, 외부 송금, 계좌 등록 시 별도 예금주 확인이다. 아래 문서는 이전 조사 자료이며 운영 연동이 완료된 것이 아니다.

| 참고 | 현재 관계 |
|---|---|
| [토스페이먼츠](toss-payments.md) | 플랫폼 PG/충전을 현재 회비 흐름으로 채택하지 않음 |
| [CODEF](codef.md) | 계좌 확인 공급자 후보, 실제 계약/스키마/오류/제한 검증 필요 |
| [PortOne](portone-identity.md) | 가입 실명/CI를 필수로 채택하지 않음 |

서버 측 사용자 귀속, 시크릿 분리, 재시도/레이트리밋, 개인정보 보관을 실제 연동 이슈에서 검증한다. 목업 버튼은 실이체를 실행하지 않는다.''')

for path, title, md in [
 ('docs/product/index.html','제품 정책','POLICY.md'),
 ('docs/scenario/index.html','시나리오 개요','README.md'),
 ('docs/implementation/index.html','개발 로드맵','ROADMAP.md'),
 ('docs/problem.html','문제 정의','problem.md'),
 ('docs/journey-map.html','고객여정','journey-map.md'),
 ('docs/payment-model-comparison.html','자금 모델 결정','payment-model-comparison.md'),
 ('docs/screens.html','화면과 상태','screens.md'),
 ('docs/external/index.html','외부 연동 참고','README.md')]:
    viewer(path, title, md)

catalog = json.loads((ROOT / 'design/system/screen-catalog.json').read_text(encoding='utf-8'))
rows = ['# 화면·상태 인수 목록', '> 2026-10-22 · 모든 화면은 정책 v1.0 기준. 외부 인증/이체/DB는 미연동 목업.', '', '| ID | 화면 | 도메인 | 주요 상태·인수 기준 |', '|---|---|---|---|']
for s in catalog:
    rows.append(f'| {s["id"]} | [{s["title"]}](../design/system/screen_v1/{s["id"]}.html) | {s["group"]} | {s["note"]} |')
write('docs/screens.md', '\n'.join(rows))

for s in catalog:
    page = f'''<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{escape(s['title'])} — 모이쇼</title><link rel="stylesheet" href="../tokens.css"><link rel="stylesheet" href="../components.css"></head><body class="prototype-page"><main id="app" data-screen="{s['id']}" class="phone"><div class="screen surface-{s['surface']}"><p>화면을 불러오는 중입니다.</p></div></main><script type="module" src="../prototype.js"></script></body></html>'''
    write(f'design/system/screen_v1/{s["id"]}.html', page)

# Existing W URLs stay valid and open the current replacement with an explicit mapping.
mapping = {'01':'LOGIN','02':'PROFILE','03':'SMS','04':'ONBOARD','05':'HOME','06':'EXPLORE','07':'CLUB_PREVIEW','08':'JOIN','09':'JOIN_REVIEW','10':'CREATE','11':'EVENT','12':'PAY','13':'PAY','14':'PAY_PENDING','15':'CANCEL','16':'ROUND','17':'ATTENDANCE','18':'COLLECT','19':'EXPENSE','20':'CLUB_CREATE','21':'SETTLE','22':'PAY','23':'CLOSED','24':'REFUND','25':'MY','26':'NOTIFICATIONS','27':'FEED','28':'COMPOSE','29':'CHAT','30':'CHAT_ROOM','31':'REPORT','32':'DISPUTE','33':'POST','40':'OPS','41':'MODERATION','42':'SETTLE','43':'COLLECT','44':'MODERATION','45':'DISPUTE_REVIEW','46':'NOTIFICATIONS','47':'OPS','TR':'COLLECT'}
for old, new in mapping.items():
    write(f'design/system/screens/W-{old}.html', f'''<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta http-equiv="refresh" content="0;url=../screen_v1/{new}.html"><title>현재 화면으로 이동 — 모이쇼</title></head><body><p>구 W-{old} 화면은 정책 v1.0의 <a href="../screen_v1/{new}.html">{new}</a>로 대체되었습니다.</p></body></html>''')

groups = {}
for s in catalog:
    groups.setdefault(s['group'], []).append(s)
flows = [
 ('F01 가입과 모임', ['LOGIN','SMS','ONBOARD','HOME','EXPLORE','CLUB_PREVIEW','JOIN','CLUB']),
 ('F02 차수 신청과 납부', ['EVENT','ROUND','PAY','PAY_PENDING','COLLECT']),
 ('F03 마감 후 합류', ['EVENT','JOIN_LATE','PAY_PENDING','PAY']),
 ('F04 취소와 조건 변경', ['EVENT','CONSENT','CANCEL','REFUND']),
 ('F05 지출과 최종 합산', ['ATTENDANCE','EXPENSE','SETTLE','REFUND','CLOSED']),
 ('F06 마감 후 이의·정정', ['CLOSED','DISPUTE','DISPUTE_REVIEW','CORRECTION','HISTORY']),
 ('F07 실제 인계와 계정 종료', ['COLLECT','HANDOVER','ACCOUNT']),
 ('F08 적립금과 해산', ['RESERVE_ADD','RESERVE','RESERVE_USE','DISSOLVE']),
 ('F09 소셜과 안전', ['FEED','POST','REPORT','MODERATION','OPS']),
 ('F10 개인 기록과 알림', ['HOME','MY','HISTORY','LEVEL','SETTINGS','NOTIFICATIONS','CHAT'])
]
sections = '<section><h2>시나리오별 화면 전환</h2>'
for name, route in flows:
    sections += '<article class="flow-lane"><h3>'+name+'</h3><div class="flow-path">'+'<span aria-hidden="true">→</span>'.join(f'<a href="../design/system/screen_v1/{id}.html">{id}</a>' for id in route)+'</div></article>'
sections += '</section>'
for group, screens in groups.items():
    cards = ''.join(f'<a class="flow-card" href="../design/system/screen_v1/{s["id"]}.html"><span>{s["id"]}</span><h3>{escape(s["title"])}</h3><p>{escape(s["note"])}</p><b>화면 열기 →</b></a>' for s in screens)
    sections += f'<section><h2>{group}</h2><div class="flow-grid">{cards}</div></section>'
write('docs/wireframe.html', f'''<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>현재 와이어플로우 — 모이쇼</title><link rel="stylesheet" href="../design/system/tokens.css"><link rel="stylesheet" href="../assets/hub.css"></head><body><main class="hub"><a href="../index.html">모이쇼 설계 허브</a><header><p class="eyebrow">POLICY v1.0 · 2026.10.22</p><h1>화면에서 구현까지.</h1><p>각 카드는 실제 HTML 목업으로 연결됩니다. 목업은 실이체·인증을 수행하지 않습니다.</p><nav><a href="journey-map.html">사용자 여정</a><a href="screens.html">화면·상태 명세</a><a href="product/index.html">정책</a><a href="../design/system/mockups/index.html">JPEG 목업</a></nav></header><section><h2>핵심 흐름</h2><p>차수 신청 → 확정/대기 → 차수 마감·회비 요청 → 외부 송금·신고 → 실제 확인 → 지출 → 이벤트 합산 → 순차액 → 계산 마감</p><p>마감 후에도 미납 추적·환불·이의·정정은 계속됩니다. 인계는 실제 입금 확인 후, 모임 해산 잔여 적립금은 모임장 귀속입니다.</p></section>{sections}</main></body></html>''')
write('index.html', '''<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>모이쇼 — 개발 기준 허브</title><link rel="stylesheet" href="design/system/tokens.css"><link rel="stylesheet" href="assets/hub.css"></head><body><main class="hub"><header><p class="eyebrow">MOISHO · POLICY v1.0 · 2026.10.22</p><h1>함께 모이고,<br>분명하게 정산해요.</h1><p>외부 송금과 실제 입금 확인을 연결하는 모임 앱.<br>확정 정책·시나리오·화면·개발 이슈의 기준을 한곳에 모았습니다.</p><nav><a class="primary" href="design/system/screen_v1/HOME.html">화면 체험</a><a href="docs/product/index.html">정책 정본</a><a href="docs/wireframe.html">전체 화면</a></nav></header><section><h2>현재 개발 기준</h2><div class="flow-grid"><a class="flow-card" href="docs/product/index.html"><span>01 · POLICY</span><h3>확정 정책</h3><p>차수별 회비, 이벤트 합산, 취소·노쇼, 정정·이관·적립금.</p></a><a class="flow-card" href="docs/scenario/index.html"><span>02 · SCENARIO</span><h3>도메인 시나리오</h3><p>홈·회원·모임·피드와 공통 알림/운영 흐름.</p></a><a class="flow-card" href="docs/screens.html"><span>03 · HANDOFF</span><h3>화면·상태 명세</h3><p>정상·대기·오류·권한·확인 상태를 개발 인수 기준으로 연결.</p></a><a class="flow-card" href="design/system/mockups/index.html"><span>04 · MOCKUP</span><h3>JPEG 목업</h3><p>현재 HTML을 렌더링한 이미지. 화면 소스와 동일한 금액·문구.</p></a><a class="flow-card" href="docs/implementation/index.html"><span>05 · BUILD</span><h3>구현 순서</h3><p>main 기준 → develop 통합 → issue 브랜치·테스트·PR.</p></a><a class="flow-card" href="docs/journey-map.html"><span>06 · JOURNEY</span><h3>전체 사용자 여정</h3><p>신청부터 부분입금·최종 정산·마감 후 처리까지.</p></a></div></section><footer>현재 화면은 개발 기준 목업입니다. 소셜/SMS·실이체·DB·푸시는 아직 미연동입니다. 구 W URL은 현재 화면으로 연결됩니다.</footer></main></body></html>''')
write('README.md', '''# 모이쇼 — 외부 송금 기반 모임 정산

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
haechan의 시나리오를 main에 병합하고 2026-10-22 사용자 정책을 반영했다. 신규 dev 대신 기존 develop을 사용한다. dev/design·kyung·mypage의 기존 이력은 보존한다. 작업은 develop의 `issue/<번호>-<주제>`에서 시작하고 PR 대상도 develop이다. 과거 모델은 Git 이력에서 확인한다.
''')
if (ROOT / 'examples/settlement.html').exists():
    readme = (ROOT / 'README.md').read_text(encoding='utf-8')
    write('README.md', readme + '\n## 정책 계산 참고 예제 — 이슈 #11\n\n`npm test` · `npm run check:handoff`\n\n[실행 가능한 정산 계산기](examples/settlement.html) · [설계](docs/superpowers/specs/2026-10-22-settlement-core-design.md) · [실행 계획](docs/superpowers/plans/2026-10-22-settlement-core.md).')
    hub = (ROOT / 'index.html').read_text(encoding='utf-8')
    write('index.html', hub.replace('<a href="docs/wireframe.html">전체 화면</a>', '<a href="docs/wireframe.html">전체 화면</a><a href="examples/settlement.html">실행 정산 계산기</a>'))
if (ROOT / 'apps/api/build.gradle').exists():
    readme=(ROOT/'README.md').read_text(encoding='utf-8')
    write('README.md', readme+'\n## Spring 서버 기반\n\n서버는 [Spring Boot + Java25](docs/architecture/TECH-STACK.md)로 진행한다. [apps/api 실행/검증](apps/api/README.md). 순수 정산·dev 미리보기와 db 프로필의 PostgreSQL 계정·모임·참가 API를 구현했다. [권한 계약](docs/implementation/IDENTITY-API.md). 소셜/SMS 실제 자격·수신 검증과 채팅·금액 원장은 후속이다.')
    roadmap=(ROOT/'docs/implementation/ROADMAP.md').read_text(encoding='utf-8')
    old='첫 구현은 ESM JavaScript 순수 정산 모듈과 Node 내장 테스트를 사용한다. 저장소의 정적 HTML에서 같은 모듈을 실행해 정책 예제를 검증할 수 있고 서버/모바일 기술 스택을 확정하기 전에 계산 규칙을 분리할 수 있다. Flutter 테마 파일은 디자인 참고이며 Flutter 앱이 생성된 것은 아니다. 후속 서버·모바일 기술 선정은 이슈별 설계로 명시한다.'
    new='서버는 사용자 선택에 따라 Spring Boot/Java로 진행한다. [기술 기준](../architecture/TECH-STACK.md)과 [Spring 실행 계획](SPRING-BOOT-PLAN.md)을 따른다. 기존 PR #17의 JS 코어는 정책 대조용으로 보존하며 실제 서버 계산은 #18에서 Java로 이식한다. DB·인증·채팅·모바일은 후속 이슈에서 연결한다.'
    write('docs/implementation/ROADMAP.md',roadmap.replace(old,new))

print(f'Built documentation and {len(catalog)} current screens; {len(mapping)} legacy routes mapped.')
