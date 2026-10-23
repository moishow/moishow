# 보호 파일 API·요구 대조

정본: 피드F3 사진선택/증빙첨부 선택, P10 일반증빙 부원전체·분쟁 당사자/처리자만, issue13/16, REQUIREMENTS-AUDIT. 증빙 문자열만 지원하던 코드누락을 보완한다.

- POST /api/v1/files multipart scope POST|PAYMENT|EXPENSE|DISPUTE, clubId?(POST),eventId?(증빙),file. bearer와 UUID Idempotency-Key 필수. 파일소유자·맥락권한을 검증하고 bytes SHA256과메타데이터를저장한다. 응답 id/reference(file:uuid)/displayUrl/size/contentType. 같은key·동일파일/맥락 재시도는같은file, 다른내용409.
- GET /files/{id}: 미연결 staged는본인만. 명시적으로 선택된 personal POST 대표사진은 정확 club.imageFileId 소개 ACL을 따르고, 게시글첨부는연결게시글 권한, 일반지출은부원 또는기참가자의관련차수, 분쟁은당사자/정확사건처리자. 접근때마다 검사하고 외부 URL이 아니라 인증프록시로 스트리밍한다. HTML/SVG/실행파일과콘텐츠타입위장은거부한다.
- S3 SDK2.57.2 비공개object·SSE·기본credentials chain. FILES_BUCKET/AWS_REGION 필요. LOCAL은명시적인 FILE_STORAGE_MODE=LOCAL+FILE_STORAGE_ROOT 에서만실제파일쓰기를허용(개발/테스트), 기본S3설정없음503. 자원생성/외부접근은하지않는다.
- 구현선택: 허용 PNG/JPEG/WebP/PDF, 최대10MiB(서버설정), 임의UUIDobjectkey, 원본파일명경로로저장하지않음, 하드삭제/보관기간 정책미정으로soft-deleted 접근거부. 숫자/기간은사용자새정책이아닌보안/리소스설정이며 원장에기록한다.

테스트먼저: 실제PostgreSQL+임시로컬파일, 소유 staged/게시글첨부맥락/다른부원·비부원/분쟁접근분리, MIME위장/크기/멱등충돌. S3실권한/단말사진은외부환경검증으로남긴다. 폼·부모엔티티연결없이파일ID만알아서읽을수없어야한다.

입금 증빙은 납부자·현재 담당자와 그 입금 보고의 원래 확인자(processedBy)만 읽는다. 인계로 원 확인자의 본인 처리 증빙 접근을 없애지 않으며, 원주최자라는 이유로 다른 입금/이의 증빙 전체를 공개하지 않는다. bank-reference-file-red에서 실제 인계 후 원 확인자 GET403(기대200)을 확인한 뒤 정확 report.processedBy 조건을 추가했다. 최신 full-mobile-contract-server-01의 File6개/전체168개 GREEN에 이 추가 회귀와 정확 사건사진 snapshot 경계가 포함됐다.


2026-10-23 현재서버파일소스는변경없이전체Java196/File6개검증을유지한다. Flutter는불변저널의fileBase64를Api.request에서multipart로변환해위POST에전송하며서버JSON업로드API를별도로추가한것이아니다. 첨부시작계정과각await복귀시화면/API/token/user가같은지검사하여A사진을B의저널/인증으로보내지않는다. 실제앱라우터재현3RED후정상owner포함4GREEN/전체105를확인했다.

권한설정변경없이인앱브라우저최신105TEST에서프로젝트가상PNG의선택/실제업로드/프로필연결저장/보호뷰어를확인하고실API본인200·타부원403·no-store를대조했다. 이는명시LOCAL저장소와가상사용자검증이며S3실권한/실단말/모든분쟁맥락GUI인수를대신하지않는다.
