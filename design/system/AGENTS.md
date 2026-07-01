# AGENTS.md — 모이쇼 디자인시스템 사용 규칙 (에이전트용)

> 이 폴더(`design/system/`)에서 화면/컴포넌트를 만들 때 **반드시** 따른다.
> 사람용 설계 근거는 [`DESIGN.md`](DESIGN.md), 기준화면은 [`meeting-detail.html`](meeting-detail.html).
> 충돌 시 우선순위: `tokens.css`·`components.css` > 이 문서 > 임의 판단.

## 0. 새 페이지를 만들 때

1. [`template.html`](template.html)을 복사해서 시작한다.
2. `<head>`에 **항상 두 CSS를 모두** 링크: `tokens.css` 다음에 `components.css`.
3. 화면 루트 `.screen`에 색 권한 클래스를 건다 (1번 규칙).

## 1. 색 출입 권한 (가장 중요)

화면 루트에 다음 중 하나를 **반드시** 부여한다:

- `class="screen surface-money"` — 정산·금액·출금·현금화·잔액 화면.
  **코랄(`--color-warm`)·크림슨 사용 금지.** 액센트·CTA는 전부 블루.
- `class="screen surface-community"` — 모임·온보딩·소셜·가입 화면.
  코랄 액센트 허용.

세부 규칙:
- 돈을 움직이는 버튼(예치/출금/현금화/정산/송금없음)은 **항상 `.btn--primary`(블루)**. 코랄·잉크 단독 CTA 금지.
- 코랄과 크림슨을 같은 화면에서 의미 충돌하게 쓰지 않는다(온기 vs 위험).
- money 화면에서도 상단 "모임 정체성 행"(`.identity`)만은 코랄 국소 허용 — 기준화면 참고.

## 2. 컴포넌트는 직접 CSS 짜지 말 것

`components.css` 클래스를 조합한다. 새 스타일이 필요하면 **먼저 components.css에 클래스를 추가**하고 쓴다(인라인 CSS로 복제 금지).

| 용도 | 클래스 |
|---|---|
| 프레임/헤더/탭바/CTA | `.phone` `.screen` `.appbar` `.tabbar` `.cta-bar` |
| 헤드라인/메타/정체성 | `.headline` `.meta` `.identity` |
| 카드/슬랩 | `.card` `.slab` |
| 버튼 | `.btn` + `.btn--primary/--warm/--secondary/--ghost/--sns` (+`--block/--lg/--sm`) |
| 배지/칩 | `.badge--progress/--done/--ended/--waiting/--danger` `.chip` |
| 스테퍼 | `.stepper .step` (+`.is-done/.is-current`) |
| 체크리스트 | `.checklist .check-row` (+`.is-checked`) |
| 아바타 | `.avatars .avatars__item` |
| 폼 | `.field .field__input` `.field--amount` `.select` `.toggle` `.checkbox` `.radio` |
| 리스트 | `.list .list-row` |
| 바텀시트/빈상태/로딩 | `.sheet` `.empty` `.skeleton` |

전체 예시는 [`components.html`](components.html) 갤러리에서 확인.

## 3. 토큰만 사용 (값 발명 금지)

색·간격·라운드·그림자·폰트는 **반드시 `tokens.css` 변수**. 새 hex·px 발명 금지.
- 색: `var(--color-primary)` 등. 생 hex 쓰지 않는다(슬랩 내부 보조색 `#CBD6FF`/`#DCE4FF`는 components.css에만 존재하는 예외).
- 간격: `var(--space-*)`, 화면 여백 20, 카드 패딩 20.
- 금액·인원·달성률 텍스트엔 **`class="num"`** (tabular numerals) 필수.

## 4. 아이콘 — 이모지 절대 금지

- 모든 글리프는 [`icons.svg`](icons.svg)의 symbol을 쓴다. 이름: chevron-left/right/down, close, dots, search, check, plus, calendar, clock, pin, lock, upload, download, edit, trash, filter, info, bell, home, list, user, users, wallet, shield-check, receipt.
- 사용법: `<svg class="icon"><use href="icons.svg#calendar"/></svg>`. `file://`로 열어 렌더가 안 되면 해당 symbol의 `path`를 **인라인 복사**한다(기준화면 방식). `.icon`/`.icon--sm`/`.icon--lg`로 크기 조절, 색은 `currentColor` 상속.
- 그림문자(웃는 얼굴·달력·체크표 같은 유니코드 이모지)를 텍스트로 넣지 않는다. 코드 주석에도 금지.

## 5. 마스코트

- 정식 마스코트는 flat 벡터 [`mascots.svg`](mascots.svg). 래스터 원본은 `assets/mascots/*.png`.
- **등장 허용**: 온보딩 · 빈 상태(`.empty`) · 정산 완료 축하. **금지**: 그 외 정산/금액 화면.

## 6. 체크리스트 (페이지 완료 전)

- [ ] `tokens.css` + `components.css` 둘 다 링크했는가
- [ ] `.screen`에 `surface-money` 또는 `surface-community` 를 걸었는가
- [ ] 돈 CTA가 블루(`.btn--primary`)인가 / money 화면에 코랄이 없는가
- [ ] 금액·숫자에 `class="num"` 을 넣었는가
- [ ] 이모지 0개 / 아이콘은 icons.svg 인가
- [ ] 새 색·간격을 발명하지 않고 토큰만 썼는가
- [ ] 인라인 컴포넌트 CSS를 복제하지 않고 클래스를 썼는가
