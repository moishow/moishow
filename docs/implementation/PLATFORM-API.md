# Platform API · issue 15

Policy P10–P13 and issue15 are compared in `REQUIREMENTS-AUDIT.md`; passing tests alone does not close that audit. Paths use `/api/v1`, an ACTIVE opaque bearer session, and UUID `Idempotency-Key` on POST/DELETE. Cases require current `version`; stale or conflicting claims return409.

| Method | Path | Body / result |
|---|---|---|
| GET | `/notifications` | Own durable inbox: id,kind,body,eventId,groupKey,count,read,createdAt |
| POST | `/notifications/{id}/read` | Own item only |
| GET / POST | `/notification-preferences` | `{pushEnabled:boolean}`; disabling suppresses queued pushes, never inbox |
| GET / POST | `/push/devices` | POST `{token,platform:ANDROID|IOS|WEB}`; returns id/platform; GET lists own active metadata, never tokens |
| DELETE | `/push/devices/{id}` | Owner only, erases token and retains delivery audit IDs |
| GET | `/clubs/{clubId}/levels/{userId}` | 0..100 score/history, same active club or same confirmed event only |
| POST | `/support/requests` | `{eventId,reason,financialDisputeId?}`; linked dispute must belong to this event and requesting party |
| POST | `/reports` | `{clubId?,eventId?,targetUserId,type,reason,contentId?,contentType?:POST|COMMENT|MESSAGE}` |
| GET | `/support/cases`, `/operator/cases` | Non-sensitive party/eligible processing queue; operator route requires offline grant |
| POST | `/support/cases/{id}/claim` | `{version}`; one actual handler, no requester/target self-processing |
| GET | `/support/cases/{id}` | Private reason/history/reported single-item snapshot; parties or current exact handler |
| POST | `/support/cases/{id}/escalate` | `{version}`; requester after72h without progress; HOST→OWNER→OPERATOR; owner host routes directly to OPERATOR |
| POST | `/support/cases/{id}/decisions` | `{version,action,reason}`; actual assigned handler only |
| GET | `/events/{id}/support/results` | Club members see linked financial status/public result/correction amount/revision ID; other financial parties only their own case; no private reason/proof |

Report types: CLUB_CONTENT (club post/comment), PERSONAL_CONTENT (personal post/comment or exact readable MESSAGE), USER (no arbitrary content pointer). Community owns current post/message visibility, including blocked group messages. Message reports go to operators; a club admin does not acquire private room access. Authors and club/room relationships are validated, and the reported item's original body is preserved separately from later edits/deletion. Reported POST photos are copied to platform_case_photo with their original positions under a post row lock. Authorized case details include these original photoIds. Protected file reads use `assignedFileEvidence(actor,fileId)` for that exact claimed snapshot, including proof after closure or removal from the edited post. `assignedContentEvidence(actor,contentId,contentType)` also remains available for exact content predicates; neither grants whole-room or whole-post visibility.

Club post/comment reports first go to active club admins unless an owner/admin is the target, in which case they go directly to operators. Personal content and user reports go directly to operators. Claim is a single handler assignment; it does not count as first response or extend the 72h inactivity timer. A valid current handler cannot be overwritten; if their role/account is revoked a new eligible handler can reclaim with an audit entry. Escalation clears assignment. The requester and report target cannot claim/process their own case. The HOST can answer an ordinary assigned support request.

Decision actions: PROGRESS, RESOLVE, WARN, RESTRICT, CORRECTION_REQUEST, HANDOVER_REQUEST, CONTENT_REMOVE. They preserve actor/reason/time. Content removal updates only the reported actual POST/COMMENT/MESSAGE status and version. Community consumes social restrictions; financial access survives restrictions. Correction/handover actions are tracked requests and never mark external transfers or arbitrary receipts complete.

`FinanceCaseAccess.canRead(actor,event,dispute)` allows only the exact linked dispute to its actual claimed handler with a currently valid role, including historical proof after support closure. `canResolve`/legacy `assigned` additionally require an active support case. It does not grant whole-book finance access, payment verification, refund confirmation, or external transfer authority. Finance owns dispute results and revision/correction amounts; the public summary never substitutes private case notes for public results.

Operators are granted/revoked through audited offline SQL only, e.g. `INSERT INTO platform_operator(user_id,provisioned_by) VALUES ('<existing-active-user-uuid>', '<admin/change-ticket>');`. There is no HTTP self-grant, client flag or environment list of operator IDs. Privileges are checked on every read/write.

SOCIAL notifications merge matching user+groupKey unread items; MONEY/REFUND/DISPUTE/SUPPORT remain separate. A read social group gets a new row on the next event. Synchronous trusted DomainSignals join the financial command transaction, atomically persisting inbox/outbox with that command; no client notification injection endpoint exists.

FCM uses the actual HTTP v1 API and official Google Auth Java SDK typed ServiceAccountCredentials parser with firebase.messaging scope. Set `FCM_PROJECT_ID` and mount a service account JSON file through `FCM_SERVICE_ACCOUNT_FILE`; equivalent Spring properties are `moishow.fcm.project-id` and `moishow.fcm.credentials-file`. The production endpoint is the official Google HTTPS endpoint. Credentials/tokens are never returned or copied into error messages. Push content is generic plus notificationId/kind; financial evidence and case reasons remain inside authenticated inbox/detail APIs.

Per-device delivery records preserve accepted provider message names. A partial retry skips already accepted devices. Only provider acceptance is SENT; no code claims DELIVERED or real-device receipt. Missing configuration, invalid credentials, no active device, timeout or transient provider errors retain RETRY and the inbox. Only an explicit FCM UNREGISTERED error revokes a token. Disabling push suppresses old queued sends; re-enabling does not replay those suppressed messages. FCM has no transactional exactly-once guarantee: a crash after acceptance before commit can resend; notificationId is the app deduplication key. HTTP connect/request limits are5/10seconds, retry15minutes, batch100; these are documented implementation defaults, not user-approved product limits.

Level is initial50, bounded0..100, one effective delta per user/event/role and append audit. PARTICIPANT: ON_TIME+1, LATE−2, RECOVERED−1 net. HOST: ON_TIME+2, LATE−4, RECOVERED−2 net. HOLD/ERROR_CORRECTED remove the affected judgment's delta, with no unrelated participant penalty. Canonical finance reassessment owns effective corrected receipt times/amounts/allocation/obligation/dispute state, avoiding stale raw receipt SQL. Platform scheduling locks club→event→book per transaction. Actual initial registrant is preserved in the immutable INITIAL revision. After handover, HOST credit attribution is explicitly unresolved policy and held rather than automatically relabeling the recipient as original host. This is a community record, never a financial credit score.

Quartz is a clustered JDBC store. Flyway V5 creates the official Quartz2.5.0 PostgreSQL schema once, with upstream DROP statements/COMMIT removed. `spring.quartz.jdbc.initialize-schema=never` is required. A persistent minute trigger scans reminders, trusted finance backfill and outbox. Reminders are once after24h of inactivity; a real progress response resets the timer. Operator first response target72h is not a guaranteed resolution/refund.

Validation status and residual policy/environment limits are tracked in `REQUIREMENTS-AUDIT.md`. Real FCM credentials, device receipt and production operator staffing remain environment checks; the adapter itself is implemented; all17 PlatformApiTest cases passed in `.superpowers/platform-file-community-audit.log`, including the local HTTP OAuth/FCM contract. The combined run still had File/Community failures, so this is only the platform result. This is distinct from credential-only configuration work.


`platform-file-final` archive validates the final photo snapshot/FileService/V7 FK and split read/resolve integration: Platform17 + File4, all21 passed without skips. This does not certify real FCM/device delivery or production operator browser E2E.

## 앱 버튼 권한 요약

support/operator cases 목록과 정확 detail에 isRequester/canReadDetails/canClaim/canDecide를 추가한다. 기존 현재 eligible/visible/processor 판정 그대로이며 다른 유효 담당자가 맡은 건은 canClaim=false, 종료 건은 canClaim/canDecide=false다. 정확 담당자의 종료 증빙 읽기는 유지한다. bool은 UI 안내용이고 실제 명령의 서버 권한/버전 재검사는 유지한다. 미배정 후보 summary에 사유/증빙을 추가하지 않는다. 로그인 후 GET /operator/cases의200(빈배열 포함)/403으로 실제 운영자 여부를 확인할 수 있으며401은 인증 만료로 구분한다. capability-green-bank-red의 역할별 회귀1개는 통과했고 전체 기존Platform 회귀를 재검증 중이다.
