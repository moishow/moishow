# 화면·상태 인수 목록
> 2026-10-22 · 모든 화면은 정책 v1.0 기준. 외부 인증/이체/DB는 미연동 목업.

| ID | 화면 | 도메인 | 주요 상태·인수 기준 |
|---|---|---|---|
| LOGIN | [로그인](../design/system/screen_v1/LOGIN.html) | 가입·계정 | 소셜 로그인 후 신규 사용자만 SMS. 실명/CI 필수 아님. |
| SMS | [전화번호 인증](../design/system/screen_v1/SMS.html) | 가입·계정 | 입력/재전송/오류/중복 번호·기존 로그인 안내. |
| ONBOARD | [첫 설정](../design/system/screen_v1/ONBOARD.html) | 가입·계정 | 닉네임 필수·관심사 건너뛰기 허용. |
| HOME | [홈](../design/system/screen_v1/HOME.html) | 홈·탐색 | 할 일과 일정은 홈, 돈 기록은 마이. 일반 주최자도 운영 todo. |
| TODO | [정산 할 일](../design/system/screen_v1/TODO.html) | 홈·탐색 | 미납/확인 대기/환불/이의 구분·중복 요청 방지. |
| SCHEDULE | [내 일정](../design/system/screen_v1/SCHEDULE.html) | 홈·탐색 | 홈 날짜 선택·취소/빈 상태·마이에 일정 중복 없음. |
| EXPLORE | [모임 탐색](../design/system/screen_v1/EXPLORE.html) | 홈·탐색 | 팔로우해도 비가입 내부 글/이벤트 숨김. |
| CREATE | [정모·번개 만들기](../design/system/screen_v1/CREATE.html) | 홈·탐색 | 정모=모임장/관리자·번개=부원. 공통 폼/검증. |
| CLUB_CREATE | [모임 만들기](../design/system/screen_v1/CLUB_CREATE.html) | 모임·참여 | 모임 이름 중복·가입 방식·모임별 닉네임 필수. |
| CLUB_PREVIEW | [모임 소개](../design/system/screen_v1/CLUB_PREVIEW.html) | 모임·참여 | 비부원 소개·인원/역할만 공개, 내부 글/정산은 잠금. |
| CLUB | [모임 홈](../design/system/screen_v1/CLUB.html) | 모임·참여 | 부원/운영 권한 분기·정모/번개 생성 양쪽 진입. |
| JOIN | [모임 가입](../design/system/screen_v1/JOIN.html) | 모임·참여 | 즉시 가입/승인제·강퇴 이력 승인·블랙 차단 우선. |
| JOIN_REVIEW | [가입 신청 검토](../design/system/screen_v1/JOIN_REVIEW.html) | 모임·참여 | 초대/강퇴/블랙 우선순위·승인/거절 이력. |
| EVENT | [정모 상세](../design/system/screen_v1/EVENT.html) | 모임·참여 | 차수 선택·정원 내 즉시 확정/초과 대기·공개 정보 제한. |
| ROUND | [차수 신청](../design/system/screen_v1/ROUND.html) | 모임·참여 | 차수별 마감·비용 고지·납부기한 별도·마감 후 합류. |
| WAITLIST | [참여 대기](../design/system/screen_v1/WAITLIST.html) | 모임·참여 | 대기 상태·미납만으로 자리 취소/승격하지 않음. |
| JOIN_LATE | [마감 후 합류](../design/system/screen_v1/JOIN_LATE.html) | 모임·참여 | 요청/승인/거절·승인 후 해당자 회비만 요청. |
| ATTENDANCE | [참석 확인](../design/system/screen_v1/ATTENDANCE.html) | 모임·참여 | 노쇼=고지 취소 비용·0명도 정산 가능. |
| PAY | [회비 보내기](../design/system/screen_v1/PAY.html) | 납부·확인 | 외부 송금→신고→실입금 확인·부분입금 잔여만 요청. |
| PAY_PENDING | [확인 대기](../design/system/screen_v1/PAY_PENDING.html) | 납부·확인 | 확인 대기는 실제 미납과 구분·지연 판정 보류. |
| COLLECT | [입금 확인](../design/system/screen_v1/COLLECT.html) | 납부·확인 | 실입금액/시각 확인·부분입금·중복확인 방지. |
| CANCEL | [참여 취소](../design/system/screen_v1/CANCEL.html) | 취소·환불 | 기납부 비용 차감/미납 비용만청구·주최자 취소 전액. |
| CONSENT | [변경 동의](../design/system/screen_v1/CONSENT.html) | 취소·환불 | 미응답 참여 유지/동의 대기·새 비용 미적용·거부무료취소. |
| EXPENSE | [지출 입력](../design/system/screen_v1/EXPENSE.html) | 정산·이의 | 항목명/금액/차수·실제지급자/개인자금/모인돈명시·증빙선택. |
| SETTLE | [이벤트 최종 정산](../design/system/screen_v1/SETTLE.html) | 정산·이의 | 개인별 순차액 상계·지출/비용/분담 합계 보존. |
| REFUND | [환불 확인](../design/system/screen_v1/REFUND.html) | 취소·환불 | 실송금→수령확인·마감 후 미수령 요청 유지. |
| CLOSED | [계산 마감](../design/system/screen_v1/CLOSED.html) | 정산·이의 | 미납/환불/이의 계속·원본 잠금·후속 입금 기록. |
| CORRECTION | [정정 기록](../design/system/screen_v1/CORRECTION.html) | 정산·이의 | 원본 보존·사유/변경금액·영향자 알림·기지급 환불 반영. |
| DISPUTE | [이의 제기](../design/system/screen_v1/DISPUTE.html) | 정산·이의 | 상세/증빙 당사자·담당자만·타부원 상태/결과/정정금액. |
| DISPUTE_REVIEW | [이의 처리](../design/system/screen_v1/DISPUTE_REVIEW.html) | 정산·이의 | 모임장→운영자·주최자가모임장이면운영자직접·증빙권한. |
| HANDOVER | [정산 인계](../design/system/screen_v1/HANDOVER.html) | 인계·적립금 | 모임장/관리자/참여자수락→실제입금확인→권한이전·0원확인. |
| RESERVE | [모임 적립금](../design/system/screen_v1/RESERVE.html) | 인계·적립금 | 부원전체내역·실확인잔액·사용권한모임장관리자. |
| RESERVE_ADD | [적립 입금 확인](../design/system/screen_v1/RESERVE_ADD.html) | 인계·적립금 | 전환요청/송금/입금확인 상태·확인전잔액미반영. |
| RESERVE_USE | [적립금 사용](../design/system/screen_v1/RESERVE_USE.html) | 인계·적립금 | 요청등록만으로차감안함·계좌담당실거래후완료·자기사용동일. |
| DISSOLVE | [모임 해산](../design/system/screen_v1/DISSOLVE.html) | 인계·적립금 | 잔액0원/입출금확인·기존기록보존·미납환불이의의무유지. |
| MY | [마이](../design/system/screen_v1/MY.html) | 기록·설정 | 마이는기록/레벨/프로필/설정·돈액션/일정중복없음. |
| HISTORY | [개인 정산 내역](../design/system/screen_v1/HISTORY.html) | 기록·설정 | 이벤트개인합산·차수근거·마감후미완요청과같은원본. |
| LEVEL | [모임 레벨](../design/system/screen_v1/LEVEL.html) | 기록·설정 | 50점시작·0~100·역할별1회·실입금기준·보류/회복. |
| PROFILE | [프로필](../design/system/screen_v1/PROFILE.html) | 기록·설정 | 사용자ID유지·예금주명별도·탈퇴후마지막닉네임표시. |
| SETTINGS | [설정](../design/system/screen_v1/SETTINGS.html) | 기록·설정 | 필수정산강제푸시없음·알림함과업무기록유지. |
| BANK | [계좌 등록·확인](../design/system/screen_v1/BANK.html) | 기록·설정 | CODEF 두 단계 인증·가입SMS와분리·미확인시자동재송금없음·목업은실제인증안함. |
| ACCOUNT | [계정 관리](../design/system/screen_v1/ACCOUNT.html) | 기록·설정 | 담당업무완료또는실제인계후삭제·계산마감만으론불가. |
| NOTIFICATIONS | [알림함](../design/system/screen_v1/NOTIFICATIONS.html) | 알림·채팅 | 소셜묶음·정산개별·딥링크권한/만료폴백. |
| CHAT | [채팅](../design/system/screen_v1/CHAT.html) | 알림·채팅 | 4종통합·그룹초대수락전대화미공개·종류구분. |
| CHAT_ROOM | [이벤트 채팅](../design/system/screen_v1/CHAT_ROOM.html) | 알림·채팅 | 닉네임표시·정산권한과개인차단분리·기록보존. |
| FEED | [피드](../design/system/screen_v1/FEED.html) | 피드·안전 | 개인/모임글분리·공개번개허용정보·차단필터. |
| POST | [게시글 상세](../design/system/screen_v1/POST.html) | 피드·안전 | 글권한·댓글·삭제/만료·신고대상유형분리. |
| COMPOSE | [글쓰기](../design/system/screen_v1/COMPOSE.html) | 피드·안전 | 모임글멤버십·공지권한·모집카드는이벤트자동생성. |
| REPORT | [신고](../design/system/screen_v1/REPORT.html) | 피드·안전 | 모임글관리자→운영자·개인/사람/관리자대상운영자직접. |
| MODERATION | [신고 처리](../design/system/screen_v1/MODERATION.html) | 운영 | 관리자자기신고처리금지·처리근거·필요최소증빙. |
| OPS | [운영 대시보드](../design/system/screen_v1/OPS.html) | 운영 | 증빙/소명·정정/인계요청·강제송금/허위입금확인불가. |
| GROUP_CREATE | [그룹 대화 만들기](../design/system/screen_v1/GROUP_CREATE.html) | 알림·채팅 | 알려진관계닉네임선택·초대수락후입장·금융권한부여없음. |
| GROUP_INVITE | [그룹 초대](../design/system/screen_v1/GROUP_INVITE.html) | 알림·채팅 | 수락/거절명시·차단상대초대차단·수락전대화미공개. |
| GROUP_MEMBERS | [그룹 멤버](../design/system/screen_v1/GROUP_MEMBERS.html) | 알림·채팅 | 생성자소유권없음·나가기즉시권한회수·기존금융권한분리. |
| ADVANCE | [선지출 반환](../design/system/screen_v1/ADVANCE.html) | 정산·이의 | 개인자금/모인돈구분·기존주최자반환의무인계·실송금/수령별도. |
| SELF_RECOVERY | [내 선지출 회수](../design/system/screen_v1/SELF_RECOVERY.html) | 정산·이의 | 명시적비현금상계·보관금/미회수선지출한도·일반환불의무보호. |
| HANDOVER_REVIEW | [변경된 인계 확인](../design/system/screen_v1/HANDOVER_REVIEW.html) | 인계·적립금 | 실수령사실보존·기존금액재송금금지·재수락전권한유지·실반환가능. |
