# 모이쇼 디자인시스템 v2

> 정본 문서. 토큰 값은 [`tokens.css`](tokens.css)가 단일 출처(SoT)이고, 디자인 기준화면은 [`screens_v0/meeting-detail.html`](screens_v0/meeting-detail.html)이다.
> 충돌 시 우선순위: **tokens.css > 이 문서 > 개별 화면**.

---

## 1. 컨셉

**"신뢰는 구조로, 친근함은 표면으로"**

모이쇼는 동아리·소모임의 회비를 모으고 투명하게 정산하는 핀테크다. "모임의 친근함"과 "정산의 신뢰"라는 상반된 두 정서를 **평균내지 않고**, **같은 팔레트에 화면별 색 사용권을 다르게 부여**해 양립시킨다.

- **기억점(the one thing): "총무를 안 믿어도 되네."** — 에스크로 구조가 신뢰를 *증명*한다. 디자인은 이 구조를 숨기지 않고 드러낸다(5단계 스테퍼, 블루 슬랩의 패널티 경고).
- **잉크 에디토리얼 헤드라인이 전체를 묶는 앵커.** 친근한 화면이든 정산 화면이든 Pretendard 800 잉크 타이틀이 "핀테크답게 신뢰 가는" 무게중심을 잡는다.
- **마스코트는 감정 모먼트에만.** 온보딩·빈상태·완료 축하에서만 등장하고, 돈을 다루는 화면에는 들어오지 않는다.

---

## 2. 색 출입 권한 규칙 (Color Permission) — 시스템의 핵심

같은 팔레트를 쓰되, **화면 종류가 어떤 색을 쓸 수 있는지를 통제**한다. `tokens.css`의 `.surface-money` / `.surface-community` 컨벤션 클래스로 강제한다.

| 색                   | money 화면 (정산·금액·출금·현금화) | community 화면 (모임·온보딩·소셜)         |
| -------------------- | ---------------------------------- | ----------------------------------------- |
| **블루 `#3B5CFF`**   | 액센트·CTA·강조 = 전부 블루        | 보조 액션(둘러보기 등)                    |
| **잉크 `#161A24`**   | 금액·헤드라인 (앵커)               | 헤드라인                                  |
| **민트 `#00C781`**   | 완료·증빙 OK                       | 완료                                      |
| **코랄 `#FF6B5C`**   | **출입 금지**                      | 메인 액센트·가입 CTA·칩·마스코트 (풀가동) |
| **크림슨 `#F0384B`** | 파괴적 액션·패널티만 (절제)        | 위험 알림만                               |

**철칙**

- 돈을 움직이는 CTA(예치·출금·현금화·정산)는 **항상 블루**. 코랄·잉크 단독 CTA 금지.
- 코랄과 크림슨을 **같은 화면에서 의미 충돌하게 쓰지 않는다** (온기 vs 위험 분리).
- 기준화면([`screens_v0/meeting-detail.html`](screens_v0/meeting-detail.html))이 살아있는 예시다: 루트는 `.surface-money`, 상단 모임 정체성 행만 코랄을 국소 허용.

---

## 3. v1 → v2 변경 요약 (팀원 공유용)

| 항목      | v1 (구버전)         | v2 (현재)                                | 이유                                   |
| --------- | ------------------- | ---------------------------------------- | -------------------------------------- |
| 액센트    | 네온 퍼플 `#8C52FF` | **폐기**                                 | '파티 앱' 신호 → 핀테크 신뢰 잠식      |
| 모임 온기 | (없음)              | **코랄 `#FF6B5C`** 신설 (`--color-warm`) | 신뢰를 안 깎는 절제된 따뜻함           |
| 위험색    | 코랄 `#FF4B4B`      | **크림슨 `#F0384B`**로 분리              | 온기(코랄)와 위험(빨강) 의미 충돌 제거 |
| 색 사용   | 화면 무관 자유      | **색 출입 권한 규칙** 도입               | 친근함·신뢰 양립의 구조적 장치         |
| 헤드라인  | bold 700            | **extrabold 800 에디토리얼** 앵커        | 전 화면 신뢰 무게중심                  |
| 아이콘    | 이모지 혼용         | **이모지 금지 → lucide inline SVG**      | 톤 일관성·핀테크 정제                  |

구버전 토큰(`design/tokens/*.css`·`design/design-tokens.md`)은 **제거됨**. 정본은 이 폴더(`design/system/`)의 자립형 `tokens.css`다.

---

## 4. 토큰 레퍼런스

값의 단일 출처는 [`tokens.css`](tokens.css). 아래는 요약.

### 컬러

| 시맨틱 토큰                                 | 값                    | 용도                               |
| ------------------------------------------- | --------------------- | ---------------------------------- |
| `--color-primary`                           | `#3B5CFF`             | 신뢰·정산 액센트, CTA              |
| `--color-warm`                              | `#FF6B5C`             | 모임 온기 (community 전용)         |
| `--color-warm-soft` / `--color-warm-strong` | `#FFF0EE` / `#E0513F` | 코랄 칩 배경 / 그 위 텍스트        |
| `--color-success`                           | `#00C781`             | 정산 완료·증빙 OK                  |
| `--color-danger`                            | `#F0384B`             | 패널티·위험 (크림슨)               |
| `--color-warning`                           | `#FFA722`             | 마감 임박 주의                     |
| `--text-strong` (Ink)                       | `#161A24`             | 금액·헤드라인                      |
| `--surface-sunken`                          | `#F4F6FA`             | 수치 카드 배경                     |
| `--jelly-yellow`                            | `#FFC83D`             | 마스코트 장식 전용(UI 시맨틱 아님) |

### 타이포 — Pretendard

| 토큰                                   | 크기/굵기       | 용도                     |
| -------------------------------------- | --------------- | ------------------------ |
| `--text-editorial`                     | 30 / 800 / 1.18 | 에디토리얼 헤드라인 앵커 |
| `--text-display-lg` / `--text-display` | 34·28 / 700     | 펀딩 총액 / 금액         |
| `--text-heading`                       | 22 / 700        | 화면 제목                |
| `--text-title-1`                       | 18 / 700        | 모임명·카드 타이틀       |
| `--text-body-1`                        | 14 / 400        | 본문                     |
| `--text-caption-1`                     | 12 / 500        | 계좌·시간                |

- 자간: 헤드라인·금액 `-0.02em`. **금액·인원·달성률은 tabular numerals**(`.num` 클래스 → `font-feature-settings: "tnum" 1`).

### 간격 (4px base)

`4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48 · 64` — 화면 좌우 여백 `--pad-screen: 20`, 카드 내부 `--pad-card: 20`, 리스트 간격 `--gap-list: 12`.

### 라운드

`mini 6 · sm 8 · md 12 · lg 16 · xl 20 (카드) · 2xl 24 (메인 보드) · 3xl 36 (폰 프레임) · pill 999`.

### 그림자

| 토큰            | 용도                    |
| --------------- | ----------------------- |
| `--shadow-card` | 카드 기본 (파란 기운)   |
| `--shadow-pop`  | 모달·바텀시트·폰 프레임 |
| `--glow-blue`   | money CTA 강조          |
| `--glow-slab`   | 블루 슬랩               |
| `--glow-warm`   | community 코랄 액센트   |

### 모션 — "또로롱"

`--ease-spring cubic-bezier(0.34,1.56,0.64,1)` · `--dur-base 200ms`. 가볍게 통통 튀되 과하지 않게.

---

## 5. 컴포넌트 스펙

기준화면에서 추출. variants/states는 표 형식.

### Button

| Variant   | 배경                                                       | 텍스트            | 용도                               | 화면         |
| --------- | ---------------------------------------------------------- | ----------------- | ---------------------------------- | ------------ |
| Primary   | `--color-primary` + `--glow-blue`                          | white             | 돈 이동 CTA(예치·출금·현금화·정산) | money + 공통 |
| Warm      | `--color-warm` + `--glow-warm`                             | white             | 가입 신청 등 모임 액션             | community    |
| Secondary | `--color-primary-soft`                                     | `--color-primary` | 보조(둘러보기·자세히)              | 공통         |
| SNS       | 카카오 `#FEE500`·black / Apple black / Google white+border | —                 | 소셜 로그인                        | 온보딩       |

States: default → hover(`-hover` 토큰) → press(`-press`) → disabled(`--text-disabled`, non-interactive) → loading(스피너, 라벨 유지). 라운드 `--radius-md`.

### Badge

| 종류     | 예시                                             | 스타일                                                                |
| -------- | ------------------------------------------------ | --------------------------------------------------------------------- |
| 상태     | 정산 진행 중 / 정산 완료 / 만남 종료 / 참여 대기 | soft 배경 + strong 텍스트. 완료=민트, 진행=블루, 종료=중립, 대기=코랄 |
| 카테고리 | 총무 김산 등                                     | `--color-warm-soft` + `--color-warm-strong`, pill                     |

### Escrow Stepper (5+1 노드)

예치 → 락 → 동의 → 출금 → 정산 → 완료. 노드 상태 3종:
| 상태 | 원 | 라벨 | 세그먼트 |
|---|---|---|---|
| done | 블루 채움 + check SVG | body 색 | 블루 |
| cur | 흰 배경 + 블루 테두리 + 4px soft 링 + 숫자 | 블루 bold | 블루 |
| todo | `#E7EBF3` + faint 숫자 | faint | `#E7EBF3` |

체크는 **inline SVG `path M5 13l4 4L19 7`** (이모지 아님).

### Blue Slab

화면에서 가장 중요한 정보 블록. `--color-primary` 솔리드 + `--glow-slab`. 내부: 라벨(연블루 `#CBD6FF`) → 타이머/금액(800, tabular) → 반투명 인셋 행 → 아바타 스택 → 패널티 경고(lock SVG + 검은 반투명 박스). money 화면당 1개.

### Checklist Row

좌측 라디오(미완료=`--border-strong` 링 / 완료=`--color-success` + check SVG) + 항목명(완료 시 `line-through` + faint) + 우측 금액(Ink, tabular / 미완료="대기" faint). 하단 1px 구분선.

### Avatar Stack

26px 원, `margin-left:-8px` 겹침, 2px 배경색 테두리. 4번째는 `+N`. 뒤에 설명 텍스트.

### Input / Toggle / Checkbox

- Input: `--radius-md`, 1px `--border-default`, focus 시 `--border-focus`. 금액 입력은 우측 "원" suffix.
- Toggle: pill 트랙, on=`--color-primary`. Checkbox: `--radius-mini`, on=`--color-primary` + check SVG.

### Tab Bar / Bottom Sheet

- Tab Bar: 높이 `--tabbar-height: 64`, 아이콘+라벨, active=`--color-primary`. 중앙 "모임 만들기"는 블루 원형 FAB.
- Bottom Sheet: 상단 핸들 + 제목 + 닫기(X SVG), `--radius-2xl` 상단, `--shadow-pop`.

---

## 6. 마스코트 가이드

제품 마스코트의 정식(production) 에셋은 [`assets/mascots/`](assets/mascots/)의 추출 PNG(투명 배경)다 — 블루(주연) / 코랄(모임) / 민트(완료) / 옐로(장식) 젤리 4종 + 단체 `mascots.png`. **이모지 금지, 감정 화면에만 등장.**

파일: `mascot_blue/green/red/yellow/pink.png`, 단체 `mascots.png`, 투명 단체 `mascots_transparent.png`. 온보딩·빈 상태·정산 완료 축하 화면에 이 PNG를 직접 사용한다(예: [`screens/W-01.html`](screens/W-01.html) 온보딩).

| 등장 허용                                | 등장 금지                       |
| ---------------------------------------- | ------------------------------- |
| 온보딩 / 빈 상태(empty) / 정산 완료 축하 | money 화면(정산·금액·출금) 전부 |

정산 화면에 마스코트가 들어오면 신뢰의 무게가 흩어진다 — "총무를 안 믿어도 되네"를 약화시킨다.

---

## 7. 아이콘 정책

- **이모지 전면 금지.** 모든 글리프는 [lucide](https://lucide.dev) 스타일 **inline SVG**(`stroke-width: 2`, `currentColor`) 또는 직접 작도.
- 24×24 viewBox 기준, 색은 `currentColor`로 상속.
- 기준화면 참조: 뒤로가기(`M15 19l-7-7 7-7`), 캘린더, 자물쇠, 체크(`M5 13l4 4L19 7`).

---

## 8. Flutter ThemeData 매핑

CLAUDE.md 8절(디자인 토큰 → ThemeData 1:1) 준수. `core/theme`에서 매핑.

| tokens.css                          | Flutter                                                    |
| ----------------------------------- | ---------------------------------------------------------- |
| `--color-primary` `#3B5CFF`         | `ColorScheme.primary`                                      |
| `--color-warm` `#FF6B5C`            | 커스텀 `MoishoColors.warm` (community 전용 extension)      |
| `--color-success` `#00C781`         | 커스텀 `MoishoColors.success`                              |
| `--color-danger` `#F0384B`          | `ColorScheme.error`                                        |
| `--text-strong` `#161A24`           | `ColorScheme.onSurface` / 금액 텍스트 색                   |
| `--surface-sunken` `#F4F6FA`        | `ColorScheme.surfaceContainerLow`                          |
| `--text-editorial`                  | `TextTheme.displaySmall` (w800)                            |
| `--text-display`                    | `TextTheme.headlineLarge`                                  |
| `--text-title-1`                    | `TextTheme.titleLarge`                                     |
| `--text-body-1`                     | `TextTheme.bodyMedium`                                     |
| `--radius-xl` 20 / `--radius-md` 12 | `CardTheme.shape` / `ButtonStyle` `RoundedRectangleBorder` |
| `--shadow-card`                     | `CardTheme` `elevation` + 커스텀 `BoxShadow`               |
| `--ease-spring`                     | `Curves`에 커스텀 `Cubic(0.34,1.56,0.64,1)`                |

- 금액 텍스트: `TextStyle(fontFeatures: [FontFeature.tabularFigures()])`.
- 색 출입 권한은 화면 단위 `Theme` override 또는 `MoishoSurface.money/community` 위젯 래퍼로 강제.

---

## 9. 파일

**토큰·규칙**
| 파일 | 역할 |
|---|---|
| [`tokens.css`](tokens.css) | 토큰 단일 출처(색·타이포·간격·라운드·그림자·모션) |
| [`components.css`](components.css) | 재사용 컴포넌트 클래스 — 모든 화면이 공유 |
| [`AGENTS.md`](AGENTS.md) | **에이전트용 사용 규칙**(클로드코드가 매번 따름) |
| `DESIGN.md` | 이 문서(사람용 정본) |

**스캐폴드 / 갤러리 (루트)**
| 파일 | 역할 |
|---|---|
| [`template.html`](template.html) | 새 페이지 복사 시작점(스캐폴드) |
| [`components.html`](components.html) | 컴포넌트 갤러리(전 상태) |

**정본 기준화면 — [`screens_v0/`](screens_v0/)**
| 파일 | 역할 |
|---|---|
| [`meeting-detail.html`](screens_v0/meeting-detail.html) | 디자인 기준화면(baseline) · money |
| [`empty-state.html`](screens_v0/empty-state.html) | 빈 상태(마스코트 모먼트) |
| [`settlement-complete.html`](screens_v0/settlement-complete.html) | 정산 완료 축하 |

**제품 화면 와이어프레임 — [`screens/`](screens/)**

W-01~W-47. 온보딩(W-01)·본인인증(W-03)·모임 탐색(W-06)·예치(W-12)·현금화(W-24)·정산(W-TR) 등 실제 플로우. **W-40~47은 운영/어드민(데스크톱 레이아웃)으로 모바일 색 권한 모델 밖이다.**

**`screens_v0/` vs `screens/` — 역할 구분 & 충돌 방지 규칙**

둘은 중복이 아니라 **역할이 다르다.** `screens/W-xx`는 `screens_v0/` 기준화면의 디자인 언어를 *적용해 만든 결과물*이지 *대체본*이 아니다. 같은 페이지의 UI를 고칠 때 무엇을 정본으로 가져갈지는 아래로 판단한다.

| 구분 | `screens_v0/` (기준화면·baseline) | `screens/W-xx` (제품 화면) |
|---|---|---|
| 목적 | 디자인 **언어**(색 권한·타이포·간격·컴포넌트 원칙·마스코트 예외)의 살아있는 레퍼런스(SoT) | 그 언어로 만든 **실제 앱 화면** 정본 |
| 배포 대상 | 아니오 — 규칙 대조용 | 예 — 프로토타입·앱 생성 기준 |
| 언제 수정하나 | 디자인 **규칙**이 바뀔 때만 | **화면 UI**가 바뀔 때 |

- **앱 개발·화면 UI 수정의 정본은 항상 `screens/W-xx.html`이다.** 주제가 겹치는 경우(`meeting-detail` ↔ `W-11` 차수 상세, `settlement-complete` ↔ `W-23` 정산 완료)에도 화면 변경은 W-xx에서 한다.
- `screens_v0/`는 "이 디자인 규칙이 맞나?"를 대조하는 기준일 뿐 개별 화면을 배포하려 두는 게 아니다. 색·타이포 등 **디자인 언어 자체**가 바뀔 때만 기준화면을 갱신한다.
- **예외:** `empty-state.html`(빈 상태·마스코트)은 대응하는 W-xx 앱 화면이 없으므로 **그 자체가 정본**이다.

**에셋 / 코드**
| 파일 | 역할 |
|---|---|
| [`icons.svg`](icons.svg) | 아이콘 세트(lucide, 이모지 대체) |
| [`assets/mascots/`](assets/mascots/) | 마스코트 PNG(제품 정식 에셋 · 온보딩/빈상태/완료) |

> 클로드코드로 새 화면 개발 시: **[`AGENTS.md`](AGENTS.md)** 의 6단계 체크리스트를 따르고 [`template.html`](template.html) 에서 시작한다.
