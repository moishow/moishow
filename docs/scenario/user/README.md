# 마이페이지 시나리오 → 페이지 목록

마이페이지에서 사용자가 수행하는 흐름과, 각 흐름에 필요한 화면을 연결한다. 정책·데이터 규칙은 이 문서의 범위에 포함하지 않는다.

전체 흐름은 [마이페이지 와이어프레임·와이어플로우](../../mypage-wireflow.html)에서 iframe 카드와 연결선으로 확인할 수 있다.

| 시나리오 | 필요한 페이지 | 페이지별 기능 정의 |
|---|---|---|
| [마이페이지 진입·개요](mypage-overview/README.md) | 마이페이지 | [mypage](../../../design/mypage/mypage/README.md) |
| [프로필 편집](profile-edit/README.md) | 프로필 편집 | [profile-edit](../../../design/mypage/profile-edit/README.md) |
| [소셜 프로필](social-profile/README.md) | 내 게시글, 팔로워, 팔로잉, 상대 프로필 | [my-posts](../../../design/mypage/my-posts/README.md), [followers](../../../design/mypage/followers/README.md), [following](../../../design/mypage/following/README.md), [relative-profile](../../../design/mypage/relative-profile/README.md) |
| [내 모임 일정](schedule/README.md) | 내 모임 일정, 모임·차수 상세 | [schedule](../../../design/mypage/schedule/README.md), 기존 W-11 |
| [설정](settings/README.md) | 설정, 알림 설정, 계정 설정, 계좌 등록·인증 | [settings](../../../design/mypage/settings/README.md), [notification-settings](../../../design/mypage/notification-settings/README.md), [account-settings](../../../design/mypage/account-settings/README.md), [bank-account](../../../design/mypage/bank-account/README.md) |

## 외부 도메인 이동

마이페이지의 보낼 돈·받을 돈·최근 정산 내역은 상태를 요약해 보여 주는 진입점이다. 상세 송금·환불·수금·정산 처리는 모임 정산 도메인의 기존 화면(W-22, W-TR, W-23)으로 이동하며, 마이페이지에서 새로 만들지 않는다.
