# 모이쇼 (Moisho) — 제품 설계 & 디자인 시스템

> 동아리·소모임 회비를 **투명하게** 모으고 정산하는 핀테크. 이 저장소는 모이쇼의 **제품 정의 문서 + v2 디자인 시스템**을 담습니다.

**🔗 종합 사이트(팀 공유용): https://moishow.github.io/moishow/** — 문제 정의·고객여정·와이어플로우·디자인시스템을 한 곳에서 볼 수 있습니다.

---

## 무엇을 푸는가

동아리·소모임은 회비를 **총무 개인 계좌 + 단톡방 캡처**로 운영한다. 돈이 걷히는 순간부터 정산이 끝날 때까지 **누구도 검증할 수 없는 신뢰 구간**이 생긴다 — 먹튀·불투명 정산·환급 누락. 모이쇼는 이 구간을 **앱 포인트 기반 기간 제한형 에스크로**와 **append-only 원장**으로 **구조적으로 검증 가능**하게 만든다. *총무의 선의가 아니라 구조가 신뢰를 보증한다.*

- 자세히 → [문제 정의](docs/problem.md) · [고객여정지도](docs/journey-map.md)

## 이 저장소에 있는 것

| 경로 | 내용 |
|---|---|
| `index.html` | 프로젝트 종합 포털 (GitHub Pages 랜딩) |
| `docs/problem.md` | 문제 정의 — 자금 6단계 위험 · 핵심문제 5개 · 페르소나 3종 |
| `docs/journey-map.md` | 고객여정지도 — 3 페르소나 여정 · 감정곡선(mermaid) · 진실의 순간 |
| `docs/wireframe.html` | 와이어플로우 정본 — S1~S8 시나리오 × 실제 화면(W-01~47) |
| `design/system/DESIGN.md` | 디자인 시스템 정본 — 색 출입권한 규칙 · 기준화면 역할 |
| `design/system/AGENTS.md` | 새 화면 제작 6단계 체크리스트 |
| `design/system/tokens.css` | **디자인 토큰 SoT** — 색 · 타이포 · 간격 · 라운드 · 섀도 · 모션 |
| `design/system/components.css` · `components.html` | 컴포넌트 스타일 · 갤러리 |
| `design/system/screens/` | 실제 화면 W-01~47 (40종, 각각 단독 실행) |
| `design/system/screens_v0/` | 디자인 기준화면(baseline) — 디자인 *언어* 레퍼런스 |
| `design/system/flutter/` | Flutter theme · components (토큰 → 코드 매핑) |
| `assets/` · `.nojekyll` | 마크다운 뷰어(marked + mermaid) · Pages 정적 서빙 설정 |

## 보는 방법

- **온라인 (권장):** https://moishow.github.io/moishow/
- **로컬:** 정적 서버로 열어야 마크다운 뷰어의 `fetch`가 동작한다 (`file://` 는 브라우저 보안정책상 막힘).
  ```bash
  python3 -m http.server 8000
  # → http://localhost:8000/
  ```

## 디자인 시스템 규칙 (요약)

- **정본 우선순위:** `tokens.css` > `DESIGN.md` > 개별 화면.
- **색 출입권한:** money 화면(정산·금액·출금)은 블루/잉크/민트만, community 화면(모임·온보딩·소셜)만 코랄. → [DESIGN.md](design/system/DESIGN.md)
- **기준화면 vs 앱 화면:** 화면 UI 정본은 `screens/W-xx`, 디자인 *언어* 기준은 `screens_v0` baseline. 둘은 **역할이 다르다(중복 아님)** — 같은 페이지 UI를 고칠 땐 `screens/W-xx`를 고친다.
- 새 화면은 `template.html` 에서 시작하고 [AGENTS.md](design/system/AGENTS.md) 의 6단계를 따른다.

## 종합 사이트 / 배포

- 루트 `index.html` 이 포털이다. 마크다운 문서는 내용 사본이 아니라 **얇은 `.html` 뷰어**가 옆의 `.md` 를 런타임에 `fetch` 해 marked.js + mermaid.js 로 렌더한다 → `.md` 가 단일 소스로 유지된다.
- **GitHub Pages**: `main` 브랜치 / 루트에서 배포. `.md` 를 정적 파일로 서빙하려면 루트 `.nojekyll` 이 **필수**다(Jekyll 이 `.md` 를 `.html` 로 변환하면 뷰어의 `fetch` 가 404).
- 새 `.md` 문서를 사이트에 추가하려면 `assets/doc.js`·`assets/doc.css` 를 쓰는 같은 패턴의 뷰어 `.html` 을 만들고 `index.html` 에 카드로 링크한다.
