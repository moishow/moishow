# Community and mobile hub API — issue 16

기준: POLICY P09–P13, 회원/피드 시나리오, issue5/10/16, REQUIREMENTS-AUDIT.md. 2026-10-22 후속 확정 GROUP_DM을 포함한다. 아래 보완 코드는 감사 회귀 테스트 RED 확인 후 작성했고 최종 Community17개 PostgreSQL/HTTP/STOMP 테스트 모두 통과했다. 이전 기반 Community4+Reserve5 검증도 보존한다.

모든 경로는 `/api/v1`, ACTIVE bearer session을 사용한다. POST는 UUID `Idempotency-Key`가 필수이며 동일 키·본문 재시도는 저장한 응답을 반환한다. 배열 조회는 `offset=0&limit=50`(1..200)을 지원한다. 메시지는 `after=sequence&limit=200`으로 페이지를 이어 읽는다. 제한은 전체 자료를 잘라 숨기는 상한이 아니라 한 페이지 크기다.

| 경로 | 본문·응답 |
|---|---|
| GET /home?date=YYYY-MM-DD | `{tasks:[{title,kind,eventId,clubId?,resourceId?}],upcoming:[{id,title,startsAt}]}`. 날짜는 Asia/Seoul 기준, 생략 시 미래 일정 |
| GET /clubs/discover?q= | 기존 활성 모임 이름·가입 방식. 공개/비공개 정책 질문 미응답으로 관련 변경 보류 |
| GET /clubs/{id}/events | 활성 부원은 내부 이벤트, 비부원은 공개 이벤트만 |
| GET /me/history | 종료됐고 최초 정산이 등록된 본인 참여/담당 이벤트 `{eventId,title,status}` |
| POST /me/profile | `{nickname,version}` 서비스 닉네임 |
| POST /clubs/{id}/nickname | `{nickname,version}` 본인 모임 닉네임, version은 모임 버전 |
| GET /feed/posts | 내 모임 글·공지 + 본인/팔로우 개인 글 + 이벤트 파생 모집 카드 |
| GET /feed/posts/{id} | 개인 글 직접 열람은 팔로우와 별개, 모임 글은 현재 멤버십 검사 |
| POST /feed/posts | `{clubId?,kind?:POST|NOTICE,body,photoIds?:[UUID]}`. NOTICE는 활성 모임 관리자 |
| POST /feed/posts/{id}/edit | `{version,body,photoIds?}` 작성자. photoIds 생략은 유지, 빈 배열은 연결 제거 |
| POST /feed/posts/{id}/delete | `{version}` 작성자 soft delete, 이전 본문/버전은 수정 이력 보존 |
| POST /feed/posts/{id}/like | `{enabled}` 사용자별 중복 없는 좋아요 |
| GET/POST /feed/posts/{id}/comments | 작성 `{body}`, 조회는 글과 동일 권한 + 개인 차단 필터 |
| POST /feed/comments/{id}/edit 또는 /delete | `{version,body?}` 작성자만 |
| POST /users/{id}/follow 또는 /block | `{enabled}`. 차단/해제는 사회활동 제한 중에도 가능, follow 이력 삭제 없음 |
| GET /chat/rooms | ACTIVE 방만 통합 목록 `{id,title,kind,lastMessage,lastMessageAt,canWrite,status,requesterId,clubId,eventId,createdAt}` |
| POST /chat/direct | `{userId,body?}`. 모르는 사람 첫 본문은 요청으로 저장. 본문 없이 생성한 방은 첫 POST messages 때 요청 생성 |
| GET /chat/requests | 받은 미결 DM 요청. 정상 방 목록과 분리 |
| POST /chat/rooms/{id}/accept 또는 /decline | `{}` 수신자만. 첫 요청 본문을 읽고 결정 |
| GET/POST /chat/rooms/{id}/messages | 작성 `{body}`, 조회 `{id,sequence,roomId,userId,nickname,status,version,body,createdAt}` 배열 |
| POST /chat/groups | `{title,userIds:[UUID]}`. 생성자는 ACTIVE, 대상자는 INVITED |
| GET /chat/invitations | 받은 그룹 초대 메타데이터만. 수락 전 메시지 내용 미공개 |
| GET /me/contacts | 알려진 관계의 활성 사용자만 `{id,nickname}` 배열. offset=0/limit=50(최대200), 닉네임+ID 순. 같은 활성 모임·같은 확정 이벤트(주최자 포함)·상호 팔로우, 양방향 차단 제외. 전역 사용자/전화번호 검색 아님 |
| POST /chat/rooms/{id}/invitations | `{userIds:[UUID]}` ACTIVE 멤버 누구나 초대 |
| POST /chat/rooms/{id}/invitations/accept 또는 /decline | `{}` 초대 대상 본인만 |
| POST /chat/rooms/{id}/leave | `{}` 그룹 DM 본인 즉시 나가기 |
| GET /chat/rooms/{id}/members | 권한 있는 멤버만 ID·현재 닉네임·참여/초대 상태 조회 |

글/댓글 응답은 `id,clubId 또는 postId,userId,nickname,body,version,status,createdAt`를 포함한다. 글은 `kind,photoIds,likeCount,liked`를 더한다. 모집 카드는 게시글을 중복 저장하지 않고 이벤트에서 파생한다. `kind=RECRUITMENT,eventId,title,startsAt,publicEvent`이며 글 편집·좋아요·댓글 대신 이벤트 상세로 진입한다. 피드는 최신 글 다음 이벤트 카드를 연결한 결정적 순서로 페이지를 제공하며 이벤트에는 실제 생성 시각을 꾸며 넣지 않는다.

사진은 보호 파일 API가 발급한 UUID만 받는다. root 소유 `AttachmentAccess.requirePostPhoto(actor,fileId,clubId)`가 소유자·scope·모임을 확인한 뒤 `community_post_photo`에 연결한다. 실제 접근은 파일 API가 Community의 `PlatformContentAccess.canReadPost`를 호출해 확인한다. 임의 외부 URL 문자열을 업로드 성공으로 취급하지 않는다.

개인 차단은 양방향 피드·직접 DM에 적용하며 금융 권한은 변하지 않는다. 그룹 DM은 이미 수락한 멤버십을 유지하되 차단한 두 사람 사이의 메시지만 조회·lastMessage·실시간 전송에서 숨긴다. 모임/이벤트 공동방은 개인 차단으로 필터하지 않는다. 그룹 초대/수락 시 현재 ACTIVE 멤버 중 차단 관계가 있으면 거절하며 누구의 차단인지는 노출하지 않는다. 생성자가 나가도 다른 ACTIVE 멤버가 초대할 수 있고, 강퇴/모임 관리자 권한을 임의로 부여하지 않는다. 나가기는 즉시 읽기/쓰기/구독 권한을 끝내고 남은 멤버의 DB 기록은 보존한다. 새 초대 수락 시 같은 방 쓰기 잠금 아래 마지막 commit 메시지 sequence+1을 min_sequence로 저장하며 수락 전 대화는 새 멤버에게 공개하지 않는다. 생성자는 min_sequence=0, 기존 멤버의 기록은 유지한다. 다시 초대받아 재수락할 때도 그 수락 시점부터 접근한다. 이 제한은 REST/lastMessage/정확한 신고 메시지/실시간 전송 모두에 적용한다.

알려진 직접 DM 상대는 같은 활성 모임, 같은 확정 이벤트(주최자 포함), 상호 팔로우다. 미지인 PENDING 상태에서는 요청자 첫 메시지 한 건만 저장하고 수신자가 요청함에서 읽어 수락/거절한다. 거절은 DECLINED로 보존하며 자동 재요청하지 않는다. 삭제 계정 상대에게 새 메시지를 쓰지 않는다. 기존 기록은 현재 닉네임과 탈퇴 표기를 사용한다.

모임 방은 현재 활성 부원만 접근한다. 이벤트 방은 과거 확정 참가/주최 이력을 근거로 종료 후 읽기를 유지하고, 새 쓰기는 현재 확정 참가 또는 주최자에게 허용한다. 이벤트 종료나 기존 참가자의 모임 블랙리스트 추가를 채팅 자동 종료/참가 자동 취소로 해석하지 않는다. 종료/블랙 게이트의 실패 테스트를 확인한 뒤 해당 제한을 제거했다. 원 주최자는 과거 관계로 읽기를 유지하되, 인계 후에는 현재 확정 참가 또는 활성 모임 부원 관계가 없으면 쓰기를 잃는다. 정산 담당 수락만으로 새 담당자에게 채팅 권한을 주지 않는다. 대기/마감 후 요청만 있는 사람은 방 입장 근거가 없다. 개인 차단·그룹 나가기·세션 취소는 매 REST/구독/전송 시 다시 검사한다. 모임 탈퇴자의 메시지는 마지막 모임 닉네임+탈퇴 표기, 서비스 삭제 계정은 탈퇴 사용자 표기다.

홈 할 일 kind: PAYMENT, VERIFY_PAYMENT, SEND_REFUND(아직 송금하지 않은 순환불), REFUND(본인 수령 확인), DISPUTE, REGISTER_SETTLEMENT, HANDOVER, RESERVE, OWNER_TRANSFER. PAYMENT/SEND_REFUND 판정은 FinanceService 계산을 재사용한다. 개인정보나 타인의 금액을 홈 DTO에 싣지 않는다.

STOMP `/api/v1/chat/socket`: CONNECT native `Authorization: Bearer <session>`, `/topic/chat/<UUID>`만 구독. SEND는 금지하며 REST로 쓰고 PostgreSQL commit 후 방송한다. 단일 인스턴스 simple broker는 메시지 저장소가 아니다. 재연결은 DB sequence로 복구한다. 다중 인스턴스 fan-out·하트비트·운영 Origin 설정·실제 공급자와 실기기 검증은 별도 운영 검증이며 완료로 표시하지 않는다.

브라우저 WebSocket은 기본 same-origin이다. 운영 웹앱은 API와 같은 Origin의 `/api/v1/chat/socket` 프록시를 사용하며 Upgrade/Connection 전달이 필요하다. 별도 개발 프리뷰 Origin은 서버 `CHAT_ALLOWED_ORIGINS=http://127.0.0.1:8766`처럼 명시한다. 쉼표 구분의 정확한 http/https Origin만 허용하며 wildcard·경로·query·fragment·userinfo·잘못된 port는 서버 시작 때 거부한다. 빈 설정은 기본 same-origin을 유지한다. 이는 HTTP CORS 설정과 별개이며 REST 인가/모임 권한을 넓히지 않는다. Native처럼 Origin 없는 연결은 기존대로 허용하고, 브라우저 허용 Origin도 STOMP bearer 인증이 필수다. 미허용 Origin은 handshake403이다. bearer를 URL query에 넣지 않는다.

추가 구현 선택: 본문 10000자, 검색 100자, 그룹 제목 100자. 직접 DM 쌍은 하나의 방을 재사용한다. 빈 일반 방은 조회 때 지연 생성한다. 메시지는 불변이며 운영자 REMOVED와 버전 필드를 지원한다. 별도 보관 기간·read receipt·typing·메시지 검색·운영자 임의 그룹 강퇴를 승인된 기능으로 간주하지 않는다.


## 검증 이력

- `movement-context-origin-green-01`: Community19/19 및 CommunityOrigin1/1 GREEN. 실제 브라우저 Origin 허용 handshake·허용 Origin의 STOMP 무인증 ERROR/인증 CONNECTED·미허용 Origin403과 기존 Native Origin 없음의 실제 STOMP 회귀를 함께 검증했다. exact origin 설정 검증은 wildcard/path/query/fragment/userinfo/잘못된 port를 거부한다. 같은 실행의 금융/은행 선택회귀까지 총44/44이며 실기기·운영 프록시 수락은 별도다.

- `.superpowers/community-baseline.log`: 기반 Community4 + Reserve5 모두 GREEN (실제 PostgreSQL/HTTP/STOMP).
- `.superpowers/community-audit-red.log`: 보완 전 11개 중 8개 실패, 목록/요청함/그룹/이력/편집/페이지 요구 이탈 확인.
- `.superpowers/platform-file-community-audit.log`: Community15 중9개 GREEN, 신규3정책게이트+GROUP2프록시버그+금융조회fixture1 실패. 같은 실행의 Platform17 GREEN, File3은 아직 없는 경로 RED.
- 위6개 실패의 원인에 따라 EVENT 종료/블랙 제한 제거·전 주최자 인계 후 쓰기 제한, GROUP 서비스 프록시 필드 직접 접근 제거, 실제 finance/open fixture를 반영했다. 후속 Community17 최종 GREEN으로 위 커뮤니티 실패 수정이 검증됐다.
- `.superpowers/community-file-finance-audit.log`: Community15 모두 GREEN. File3 중2 GREEN/1 새 finance_dispute fixture 필수값 누락, Finance17 중6 GREEN/11 실패로 각 담당자에게 전달. 전체 실행을 GREEN이라 주장하지 않는다.
- `.superpowers/community-history-red.log`: 새 그룹 수락자의 이전 대화 차단 회귀 테스트1 RED 확인. min_sequence 경계를 적용했고 후속 최종17개 테스트에서 수락 시점 이력 경계도 GREEN 확인.

## 소셜 알림 연결

댓글·새 좋아요·새 팔로우·미지인의 첫 DM 요청·그룹 초대는 콘텐츠/관계 변경과 같은 트랜잭션에서 신뢰된 DomainSignals.Notification을 발행한다. PlatformSignals가 인앱 알림과 push outbox를 함께 저장한다. 자기 자신/차단 관계는 제외하고 중복 좋아요·팔로우의 0행 삽입은 새 알림을 만들지 않는다. 푸시 본문에는 보호 댓글·DM 본문·그룹 제목을 싣지 않는다.

소셜 groupKey는 `social:comments:<postId>`, `social:likes:<postId>`, `social:followers`, `chat:request:<roomId>`, `chat:group-invite:<roomId>`다. 유사 미확인 건은 Platform의 기존 묶기 규칙을 따른다. 딥링크 진입에서도 글/방/초대 권한을 다시 검사하며 이미 삭제되거나 권한이 끝난 대상은 일반 목록으로 복귀한다.
- `.superpowers/checks/audited-integration-01/`: Community17 중16 GREEN/신규SOCIAL1 RED; Finance17·Platform17·FK동시성1 모두 GREEN, File4 중3 GREEN/원본사진스냅샷1 RED. 클래스별 결과를 보존한다.
- `.superpowers/checks/community-final-02/`: **Community17 모두 GREEN, 실패0·오류0·skip0**, 40초. 실제 PG17·HTTP·WebSocket/STOMP, 보호된 그룹 이력/차단/나가기·닉네임·피드/공지/편집/댓글/좋아요·알림 신뢰 경로·날짜/페이지·금융접근 분리 검증. 같은 폴더 XML은 이후 Gradle 실행으로 덮어쓰지 않도록 아카이브했다.

현재 `/me/contacts`는 같은 활성 모임·공유 확정 이벤트(주최자 포함)·상호 팔로우 관계의 이미 허용된 현재 활성 사용자 식별자만 검색/페이지/차단 필터하여 제공한다. 전역 사용자 디렉터리나 단순 대화 이력만으로 디렉터리 접근을 만들지 않는다. 모바일의 이름 선택기는 이 API와 정확 이벤트/모임 후보를 사용한다. 홈의 선지출/담당 인계 업무는 해당 모듈의 canonical 할 일을 연결하며 자체 지급 산식을 추가하지 않는다.
