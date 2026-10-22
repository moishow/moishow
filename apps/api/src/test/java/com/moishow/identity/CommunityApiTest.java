package com.moishow.identity;

import com.moishow.MoishowServerApplication;
import org.junit.jupiter.api.*;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.web.server.context.WebServerApplicationContext;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.context.annotation.*;
import org.testcontainers.postgresql.PostgreSQLContainer;
import tools.jackson.databind.*;
import java.net.*;
import java.net.http.*;
import java.time.*;
import java.util.*;
import java.util.concurrent.*;
import static org.junit.jupiter.api.Assertions.*;

class CommunityApiTest {
 static PostgreSQLContainer postgres=new PostgreSQLContainer("postgres:17-alpine");
 static ConfigurableApplicationContext context;
 static String base;
 static ObjectMapper json=new ObjectMapper();
 static HttpClient http=HttpClient.newHttpClient();
 static Map<String,String> sentCodes=new ConcurrentHashMap<>();
 record Reply(int status,JsonNode body) {}
 @Configuration @Profile("community-test") static class Providers {
  @Bean @Primary SocialVerifier testSocial(){return (provider,token,nonce)-> {
   if(!token.startsWith("test:"))throw new ApiProblem(401,"INVALID_SOCIAL_TOKEN");
   return new SocialVerifier.Identity(provider,token.substring(5));
  };}
  @Bean @Primary SmsGateway testSms(){return (phone,code)->sentCodes.put(phone,code);}
 }
 @BeforeAll static void start(){
  postgres.start();
  context=new SpringApplicationBuilder(MoishowServerApplication.class,Providers.class).profiles("db","community-test")
   .properties("server.port=0","logging.level.root=ERROR","spring.main.banner-mode=off",
    "spring.datasource.url="+postgres.getJdbcUrl(),"spring.datasource.username="+postgres.getUsername(),"spring.datasource.password="+postgres.getPassword()).run("--spring.datasource.url="+postgres.getJdbcUrl(),"--spring.datasource.username="+postgres.getUsername(),"--spring.datasource.password="+postgres.getPassword());
  base="http://127.0.0.1:"+((WebServerApplicationContext)context).getWebServer().getPort()+"/api/v1";
 }
 @AfterAll static void stop(){if(context!=null)context.close();postgres.stop();}
 static Reply call(String method,String path,String token,Object body,String key)throws Exception{
  var b=HttpRequest.newBuilder(URI.create(base+path)).timeout(Duration.ofSeconds(20)).header("Content-Type","application/json");
  if(token!=null)b.header("Authorization","Bearer "+token);
  if(key!=null)b.header("Idempotency-Key",key);
  b.method(method,body==null?HttpRequest.BodyPublishers.noBody():HttpRequest.BodyPublishers.ofString(json.writeValueAsString(body)));
  var r=http.send(b.build(),HttpResponse.BodyHandlers.ofString());
  return new Reply(r.statusCode(),r.body().isBlank()?json.createObjectNode():json.readTree(r.body()));
 }
 static Reply post(String path,String token,Object body)throws Exception{
  if(path.equals("/auth/social")){
   var challenge=call("POST","/auth/challenges",null,Map.of(),null);
   var data=new HashMap<String,Object>((Map<String,Object>)body);data.put("challengeId",text(challenge,"challengeId"));body=data;
  }
  return call("POST",path,token,body,UUID.randomUUID().toString());
 }
 static Reply get(String path,String token)throws Exception{return call("GET",path,token,null,null);}
 static String text(Reply r,String key){return r.body.path(key).asText();}
 static long version(Reply r){return r.body.path("version").asLong();}
 static String user(String suffix)throws Exception {
  var login=post("/auth/social",null,Map.of("provider","GOOGLE","token","test:"+suffix));assertEquals(200,login.status,login.body.toString());
  String pending=text(login,"token");
  String phone="+8210"+String.format("%08d",Math.floorMod(suffix.hashCode(),100000000));
  var sms=post("/auth/sms",pending,Map.of("phone",phone));assertEquals(200,sms.status,sms.body.toString());
  var verify=post("/auth/sms/"+text(sms,"id")+"/verify",pending,Map.of("code",sentCodes.get(phone)));assertEquals(200,verify.status);
  var registered=post("/auth/register",pending,Map.of("nickname",suffix,"verificationId",text(sms,"id")));assertEquals(200,registered.status,registered.body.toString());
  return text(registered,"token");
 }
 static Reply club(String host,String mode)throws Exception{return post("/clubs",host,Map.of("name","모임","joinMode",mode));}
 static Reply join(String token,String clubId,long v,String invite)throws Exception {
  var b=new HashMap<String,Object>();b.put("nickname","부원");b.put("version",v);if(invite!=null)b.put("inviteToken",invite);
  return post("/clubs/"+clubId+"/join",token,b);
 }
 static Reply event(String host,String clubId,long v,String kind,boolean open)throws Exception {
  return event(host,clubId,v,kind,open,"POSTPAY");
 }
 static Reply event(String host,String clubId,long v,String kind,boolean open,String mode)throws Exception {
  return post("/clubs/"+clubId+"/events",host,Map.of("title","번개","kind",kind,"publicEvent",open,"startsAt",Instant.now().plusSeconds(3600).toString(),"endsAt",Instant.now().plusSeconds(7200).toString(),"version",v,"settlementMode",mode));
 }
 static Reply round(String host,String eventId,long v,int capacity,boolean closed)throws Exception {
  return post("/events/"+eventId+"/rounds",host,Map.of("capacity",capacity,"closesAt",Instant.now().plusSeconds(closed?-60:1800).toString(),"cancellationFee",1000,"version",v));
 }
 @Test void contactPickerExposesOnlyKnownActiveUnblockedPeople()throws Exception {
  String owner=user("contactOwner"),member=user("contactMember"),mutual=user("contactMutual"),stranger=user("contactStranger");
  String ownerId=text(get("/me",owner),"id"),memberId=text(get("/me",member),"id"),mutualId=text(get("/me",mutual),"id"),strangerId=text(get("/me",stranger),"id");
  var c=club(owner,"IMMEDIATE");assertEquals(200,join(member,text(c,"id"),version(c),null).status);
  assertEquals(200,post("/users/"+mutualId+"/follow",owner,Map.of("enabled",true)).status);
  assertEquals(200,post("/users/"+ownerId+"/follow",mutual,Map.of("enabled",true)).status);
  var contacts=get("/me/contacts",owner);assertEquals(200,contacts.status,contacts.body.toString());assertTrue(contacts.body.isArray());
  Set<String> ids=new HashSet<>();for(var row:contacts.body){ids.add(row.path("id").asText());assertTrue(row.path("nickname").isTextual());assertFalse(row.has("phone"));assertFalse(row.has("subject"));}
  assertEquals(Set.of(memberId,mutualId),ids);assertFalse(ids.contains(strangerId));
  assertEquals(1,get("/me/contacts?limit=1",owner).body.size());assertEquals(400,get("/me/contacts?limit=201",owner).status);
  assertEquals(200,post("/users/"+memberId+"/block",owner,Map.of("enabled",true)).status);
  var visible=get("/me/contacts",owner);assertEquals(1,visible.body.size());assertEquals(mutualId,visible.body.get(0).path("id").asText());
 }
 @Test void followingCannotRevealClubPostsAndBlockingHidesFeed()throws Exception {
  String owner=user("feedOwner"),other=user("feedOther");var c=club(owner,"IMMEDIATE");String cid=text(c,"id"),uid=text(get("/me",owner),"id");
  assertEquals(200,post("/feed/posts",owner,Map.of("clubId",cid,"body","비공개 모임 글")).status);
  assertEquals(200,post("/users/"+uid+"/follow",other,Map.of("enabled",true)).status);
  assertEquals(0,get("/feed/posts",other).body.size());
  assertEquals(200,post("/feed/posts",owner,Map.of("body","개인 공개 글")).status);
  assertEquals(1,get("/feed/posts",other).body.size());
  assertEquals(200,post("/users/"+uid+"/block",other,Map.of("enabled",true)).status);
  assertEquals(0,get("/feed/posts",other).body.size());
 }
 @Test void directRequiresRecipientAcceptanceAndCommandsPersistOnce()throws Exception {
  String a=user("dmA"),b=user("dmB");String bid=text(get("/me",b),"id");var room=post("/chat/direct",a,Map.of("userId",bid));assertEquals(200,room.status,room.body.toString());String rid=text(room,"id");assertEquals("PENDING",text(room,"status"));
  assertEquals(200,post("/chat/rooms/"+rid+"/messages",a,Map.of("body","첫 요청")).status);assertEquals(403,post("/chat/rooms/"+rid+"/messages",a,Map.of("body","두번째 요청 금지")).status);
  assertEquals(403,post("/chat/rooms/"+rid+"/accept",a,Map.of()).status);
  assertEquals(200,post("/chat/rooms/"+rid+"/accept",b,Map.of()).status);
  String key=UUID.randomUUID().toString();var body=Map.of("body","안녕하세요");assertEquals(200,call("POST","/chat/rooms/"+rid+"/messages",a,body,key).status);assertEquals(200,call("POST","/chat/rooms/"+rid+"/messages",a,body,key).status);
  var messages=get("/chat/rooms/"+rid+"/messages",b);assertEquals(2,messages.body.size());long cursor=messages.body.get(1).path("sequence").asLong();assertEquals(0,get("/chat/rooms/"+rid+"/messages?after="+cursor,b).body.size());
  assertEquals(200,post("/users/"+bid+"/block",a,Map.of("enabled",true)).status);assertEquals(403,get("/chat/rooms/"+rid+"/messages",b).status);
 }
 @Test void clubRoomAuthorizationIsRecheckedAfterLeaveAndWaitlistHasNoEventRoom()throws Exception {
  String owner=user("chatOwner"),member=user("chatMember"),wait=user("chatWait");var c=club(owner,"IMMEDIATE");String cid=text(c,"id");var joined=join(member,cid,version(c),null);assertEquals(200,joined.status);
  var e=event(owner,cid,version(joined),"LIGHTNING",true);var r=round(owner,text(e,"id"),version(e),1,false);var p=post("/rounds/"+text(r,"id")+"/participations",member,Map.of("version",version(r)));assertEquals(200,p.status);assertEquals("WAITLISTED",text(post("/rounds/"+text(r,"id")+"/participations",wait,Map.of("version",version(p))),"status"));
  assertEquals(0,get("/chat/rooms",wait).body.size());var rooms=get("/chat/rooms",member);assertEquals(2,rooms.body.size());String rid="";for(var room:rooms.body)if(room.path("kind").asText().equals("CLUB"))rid=room.path("id").asText();assertFalse(rid.isBlank());
  assertEquals(200,post("/clubs/"+cid+"/leave",member,Map.of("version",version(get("/clubs/"+cid,owner)))).status);assertEquals(403,get("/chat/rooms/"+rid+"/messages",member).status);
  assertEquals(200,get("/home",member).status);assertEquals(200,get("/me/history",member).status);
 }
 static class SocketFrames implements WebSocket.Listener {
  final BlockingQueue<String> frames=new LinkedBlockingQueue<>();final StringBuilder pending=new StringBuilder();
  @Override public void onOpen(WebSocket socket){socket.request(1);}
  @Override public CompletionStage<?> onText(WebSocket socket,CharSequence data,boolean last){pending.append(data);if(last){frames.add(pending.toString());pending.setLength(0);}socket.request(1);return CompletableFuture.completedFuture(null);}
  String await(String prefix)throws Exception {long until=System.nanoTime()+TimeUnit.SECONDS.toNanos(5);while(System.nanoTime()<until){String f=frames.poll(200,TimeUnit.MILLISECONDS);if(f!=null&&f.startsWith(prefix))return f;}return null;}
 }
 static WebSocket socket(SocketFrames f)throws Exception{return http.newWebSocketBuilder().subprotocols("v12.stomp").buildAsync(URI.create(base.replace("http:","ws:")+"/chat/socket"),f).get(10,TimeUnit.SECONDS);}
 @Test void stompAuthenticatesConnectAndRechecksRevokedMembershipOnDelivery()throws Exception {
  var badFrames=new SocketFrames();var bad=socket(badFrames);bad.sendText("CONNECT\naccept-version:1.2\nhost:localhost\n\n\u0000",true).join();assertNotNull(badFrames.await("ERROR"));bad.abort();
  String owner=user("socketOwner"),member=user("socketMember");var c=club(owner,"IMMEDIATE");String cid=text(c,"id");assertEquals(200,join(member,cid,version(c),null).status);String rid="";for(var room:get("/chat/rooms",member).body)if(room.path("kind").asText().equals("CLUB"))rid=room.path("id").asText();assertFalse(rid.isBlank());
  var frames=new SocketFrames();var ws=socket(frames);ws.sendText("CONNECT\naccept-version:1.2\nhost:localhost\nAuthorization:Bearer "+member+"\n\n\u0000",true).join();assertNotNull(frames.await("CONNECTED"));ws.sendText("SUBSCRIBE\nid:sub-1\ndestination:/topic/chat/"+rid+"\n\n\u0000",true).join();
  // Retry an initial probe until subscription has been processed, bounded by real message receipt.
  String first=null;for(int i=0;i<3&&first==null;i++){assertEquals(200,post("/chat/rooms/"+rid+"/messages",owner,Map.of("body","권한 확인")).status);first=frames.frames.poll(500,TimeUnit.MILLISECONDS);}assertNotNull(first);assertTrue(first.startsWith("MESSAGE"));
  assertEquals(200,post("/clubs/"+cid+"/leave",member,Map.of("version",version(get("/clubs/"+cid,owner)))).status);frames.frames.clear();assertEquals(200,post("/chat/rooms/"+rid+"/messages",owner,Map.of("body","탈퇴 후 비공개")).status);assertNull(frames.frames.poll(700,TimeUnit.MILLISECONDS));ws.abort();
 }
 @Test void auditedFeedSelectsFollowedAndOwnButDirectPersonalReadRemainsAuthorized()throws Exception {
  String owner=user("auditFeedOwner"),stranger=user("auditFeedStranger");String uid=text(get("/me",owner),"id");var p=post("/feed/posts",owner,Map.of("body","공개지만 추천 피드 아님"));assertEquals(200,p.status);String id=text(p,"id");assertEquals(0,get("/feed/posts",stranger).body.size());assertEquals(200,get("/feed/posts/"+id,stranger).status);
  assertEquals(200,post("/users/"+uid+"/follow",stranger,Map.of("enabled",true)).status);assertEquals(1,get("/feed/posts",stranger).body.size());assertEquals(200,post("/users/"+uid+"/block",stranger,Map.of("enabled",true)).status);assertEquals(200,post("/users/"+uid+"/block",stranger,Map.of("enabled",false)).status);assertEquals(1,get("/feed/posts",stranger).body.size());
  var c=club(owner,"IMMEDIATE");var internal=post("/feed/posts",owner,Map.of("clubId",text(c,"id"),"body","모임 내부"));assertEquals(403,get("/feed/posts/"+text(internal,"id"),stranger).status);assertEquals(403,get("/feed/posts/"+text(internal,"id")+"/comments",stranger).status);
 }
 @Test void restrictedUsersCanStillBlockAndUnblockWithoutDeletingFollowRelations()throws Exception {
  String a=user("auditRestricted"),b=user("auditRestrictedTarget");UUID aid=UUID.fromString(text(get("/me",a),"id")),bid=UUID.fromString(text(get("/me",b),"id"));assertEquals(200,post("/users/"+bid+"/follow",a,Map.of("enabled",true)).status);var sql=context.getBean(org.springframework.jdbc.core.JdbcTemplate.class);UUID caseId=UUID.randomUUID();sql.update("insert into platform_case(id,case_type,requester_id,target_user_id,route,reason) values(?,'REPORT',?,?,'OPERATOR','테스트 제한')",caseId,bid,aid);sql.update("insert into platform_restriction(user_id,case_id,reason) values(?,?,'제한')",aid,caseId);
  assertEquals(200,post("/users/"+bid+"/block",a,Map.of("enabled",true)).status);assertEquals(200,post("/users/"+bid+"/block",a,Map.of("enabled",false)).status);assertEquals(1,sql.queryForObject("select count(*) from community_follow where user_id=? and target_id=?",Integer.class,aid,bid));assertEquals(403,post("/feed/posts",a,Map.of("body","제한됨")).status);assertEquals(200,get("/home",a).status);
 }
 @Test void firstDirectMessageAppearsInRequestInboxAndKnownClubStartsNormally()throws Exception {
  String a=user("auditRequestA"),b=user("auditRequestB");String bid=text(get("/me",b),"id");var room=post("/chat/direct",a,Map.of("userId",bid,"body","첫 메시지 요청"));assertEquals(200,room.status);String rid=text(room,"id");assertEquals(0,get("/chat/rooms",b).body.size());var inbox=get("/chat/requests",b);assertEquals(200,inbox.status);assertEquals(1,inbox.body.size());assertEquals("첫 메시지 요청",inbox.body.get(0).path("lastMessage").asText());assertEquals(1,get("/chat/rooms/"+rid+"/messages",b).body.size());assertEquals(403,post("/chat/rooms/"+rid+"/messages",b,Map.of("body","수락 전 응답 금지")).status);assertEquals(200,post("/chat/rooms/"+rid+"/decline",b,Map.of()).status);assertEquals(0,get("/chat/requests",b).body.size());
  String c=user("auditKnownA"),d=user("auditKnownB");var club=club(c,"IMMEDIATE");assertEquals(200,join(d,text(club,"id"),version(club),null).status);var known=post("/chat/direct",c,Map.of("userId",text(get("/me",d),"id"),"body","아는 부원"));assertEquals("ACTIVE",text(known,"status"));
 }
 @Test void groupInvitationsRequireConsentAndAnyActiveMemberCanInviteAfterCreatorLeaves()throws Exception {
  String a=user("auditGroupA"),b=user("auditGroupB"),c=user("auditGroupC"),d=user("auditGroupD");String bid=text(get("/me",b),"id"),cid=text(get("/me",c),"id"),did=text(get("/me",d),"id");var group=post("/chat/groups",a,Map.of("title","친구들","userIds",List.of(bid)));assertEquals(200,group.status,group.body.toString());String rid=text(group,"id");assertEquals(403,get("/chat/rooms/"+rid+"/messages",b).status);assertEquals(1,get("/chat/invitations",b).body.size());assertEquals(200,post("/chat/rooms/"+rid+"/invitations/accept",b,Map.of()).status);assertEquals(2,get("/chat/rooms/"+rid+"/members",b).body.size());assertEquals(200,post("/chat/rooms/"+rid+"/leave",a,Map.of()).status);assertEquals(403,get("/chat/rooms/"+rid+"/messages",a).status);
  assertEquals(200,post("/chat/rooms/"+rid+"/invitations",b,Map.of("userIds",List.of(cid))).status);assertEquals(200,post("/chat/rooms/"+rid+"/invitations/decline",c,Map.of()).status);assertEquals(403,get("/chat/rooms/"+rid+"/messages",c).status);assertEquals(200,post("/users/"+did+"/block",b,Map.of("enabled",true)).status);assertEquals(403,post("/chat/rooms/"+rid+"/invitations",b,Map.of("userIds",List.of(did))).status);assertEquals(200,post("/chat/rooms/"+rid+"/messages",b,Map.of("body","멤버만 볼 메시지")).status);
 }
 @Test void endedEventKeepsParticipantConversationAndDepartedNicknames()throws Exception {
  String owner=user("auditHistoryOwner"),member=user("auditHistoryMember");var c=club(owner,"IMMEDIATE");String cid=text(c,"id");var j=join(member,cid,version(c),null);var e=event(owner,cid,version(j),"LIGHTNING",true);String eid=text(e,"id");var r=round(owner,eid,version(e),2,false);assertEquals(200,post("/rounds/"+text(r,"id")+"/participations",member,Map.of("version",version(r))).status);String rid="";for(var room:get("/chat/rooms",member).body)if(room.path("kind").asText().equals("EVENT"))rid=room.path("id").asText();assertEquals(200,post("/chat/rooms/"+rid+"/messages",member,Map.of("body","남길 기록")).status);
  var me=get("/me",member);assertEquals(200,post("/clubs/"+cid+"/nickname",member,Map.of("nickname","바뀐 모임 이름","version",version(get("/clubs/"+cid,owner)))).status);assertEquals("바뀐 모임 이름",get("/chat/rooms/"+rid+"/messages",owner).body.get(0).path("nickname").asText());assertEquals(200,post("/clubs/"+cid+"/leave",member,Map.of("version",version(get("/clubs/"+cid,owner)))).status);context.getBean(org.springframework.jdbc.core.JdbcTemplate.class).update("update club_event set starts_at=now()-interval '2 hours',ends_at=now()-interval '1 hour' where id=?",UUID.fromString(eid));var history=get("/chat/rooms/"+rid+"/messages",member);assertEquals(200,history.status,history.body.toString());assertTrue(history.body.get(0).path("nickname").asText().contains("탈퇴한 멤버"));assertEquals(200,post("/chat/rooms/"+rid+"/messages",member,Map.of("body","종료 후에도 대화 유지")).status);
 }
 @Test void feedSupportsAuthorVersionsLikesNoticesAndEventCardsWithoutDuplicateWrites()throws Exception {
  String a=user("auditPostA"),b=user("auditPostB");var c=club(a,"IMMEDIATE");String cid=text(c,"id");var j=join(b,cid,version(c),null);assertEquals(403,post("/feed/posts",b,Map.of("clubId",cid,"kind","NOTICE","body","권한 없는 공지")).status);var p=post("/feed/posts",a,Map.of("clubId",cid,"kind","NOTICE","body","공지"));assertEquals(200,p.status);String pid=text(p,"id");assertEquals(200,post("/feed/posts/"+pid+"/like",b,Map.of("enabled",true)).status);assertEquals(1,get("/feed/posts/"+pid,b).body.path("likeCount").asInt());assertEquals(403,post("/feed/posts/"+pid+"/edit",b,Map.of("version",version(p),"body","도용")).status);var edited=post("/feed/posts/"+pid+"/edit",a,Map.of("version",version(p),"body","수정 공지"));assertEquals(200,edited.status);assertEquals(409,post("/feed/posts/"+pid+"/edit",a,Map.of("version",version(p),"body","낡은 수정")).status);
  var comment=post("/feed/posts/"+pid+"/comments",b,Map.of("body","댓글"));assertEquals(200,comment.status);assertEquals(200,post("/feed/comments/"+text(comment,"id")+"/delete",b,Map.of("version",version(comment))).status);assertEquals(0,get("/feed/posts/"+pid+"/comments",a).body.size());var event=event(a,cid,version(get("/clubs/"+cid,a)),"LIGHTNING",true);assertEquals(200,event.status);int cards=0;for(var item:get("/feed/posts",a).body)if(item.path("kind").asText().equals("RECRUITMENT")&&item.path("eventId").asText().equals(text(event,"id")))cards++;assertEquals(1,cards);assertEquals(200,post("/feed/posts/"+pid+"/delete",a,Map.of("version",version(edited))).status);assertEquals(404,get("/feed/posts/"+pid,a).status);
 }
 @Test void paginationAndHomeDateDoNotQuietlyTruncateOrDuplicateFutureHistory()throws Exception {
  String a=user("auditPageOwner");for(int n=0;n<3;n++)assertEquals(200,post("/feed/posts",a,Map.of("body","글 "+n)).status);assertEquals(2,get("/feed/posts?limit=2",a).body.size());assertEquals(1,get("/feed/posts?limit=2&offset=2",a).body.size());var c=club(a,"IMMEDIATE");var e=event(a,text(c,"id"),version(c),"LIGHTNING",true);assertEquals(200,e.status);assertEquals(0,get("/me/history",a).body.size());assertEquals(0,get("/home?date=2099-01-01",a).body.path("upcoming").size());
 }
 @Test void blockingRetainsClubChatAndExistingFinancialAccess()throws Exception {
  String a=user("scopeOwner"),b=user("scopeMember");var c=club(a,"IMMEDIATE");String cid=text(c,"id");var j=join(b,cid,version(c),null);var e=event(a,cid,version(j),"LIGHTNING",false);assertEquals(200,e.status);assertEquals(200,post("/events/"+text(e,"id")+"/finance/open",a,Map.of("version",0,"mode","POSTPAY")).status);String aid=text(get("/me",a),"id");assertEquals(200,post("/users/"+aid+"/block",b,Map.of("enabled",true)).status);assertEquals(200,get("/events/"+text(e,"id")+"/finance",b).status);String rid="";for(var r:get("/chat/rooms",b).body)if(r.path("kind").asText().equals("CLUB"))rid=r.path("id").asText();assertFalse(rid.isEmpty());assertEquals(200,post("/chat/rooms/"+rid+"/messages",a,Map.of("body","공동방은 유지")).status);assertEquals(1,get("/chat/rooms/"+rid+"/messages",b).body.size());
 }
 @Test void groupPairBlockFiltersMessagesAndSelfLeaveRevokesExistingSocket()throws Exception {
  String a=user("groupSocketA"),b=user("groupSocketB"),c=user("groupSocketC");String bid=text(get("/me",b),"id"),cid=text(get("/me",c),"id");var r=post("/chat/groups",a,Map.of("title","공유 대화","userIds",List.of(bid,cid)));assertEquals(200,r.status);String rid=text(r,"id");assertEquals(200,post("/chat/rooms/"+rid+"/invitations/accept",b,Map.of()).status);assertEquals(200,post("/chat/rooms/"+rid+"/invitations/accept",c,Map.of()).status);var frames=new SocketFrames();var ws=socket(frames);ws.sendText("CONNECT\naccept-version:1.2\nhost:localhost\nAuthorization:Bearer "+c+"\n\n\u0000",true).join();assertNotNull(frames.await("CONNECTED"));ws.sendText("SUBSCRIBE\nid:group\ndestination:/topic/chat/"+rid+"\n\n\u0000",true).join();String first=null;for(int i=0;i<3&&first==null;i++){assertEquals(200,post("/chat/rooms/"+rid+"/messages",b,Map.of("body","차단 전")).status);first=frames.frames.poll(500,TimeUnit.MILLISECONDS);}assertNotNull(first);
  assertEquals(200,post("/users/"+bid+"/block",c,Map.of("enabled",true)).status);assertEquals(3,get("/chat/rooms/"+rid+"/members",c).body.size());assertEquals(0,get("/chat/rooms/"+rid+"/messages",c).body.size());frames.frames.clear();assertEquals(200,post("/chat/rooms/"+rid+"/messages",b,Map.of("body","차단 상대만 숨김")).status);assertNull(frames.frames.poll(500,TimeUnit.MILLISECONDS));assertEquals(200,post("/chat/rooms/"+rid+"/messages",a,Map.of("body","다른 멤버는 유지")).status);assertNotNull(frames.await("MESSAGE"));assertEquals(200,post("/chat/rooms/"+rid+"/leave",c,Map.of()).status);frames.frames.clear();assertEquals(200,post("/chat/rooms/"+rid+"/messages",a,Map.of("body","나간 후 비공개")).status);assertNull(frames.frames.poll(500,TimeUnit.MILLISECONDS));ws.abort();assertEquals(403,get("/chat/rooms/"+rid+"/messages",c).status);
 }
 @Test void blacklistPreventsNewApplicationsButDoesNotCancelConfirmedEventConversation()throws Exception {
  String a=user("existingBanOwner"),b=user("existingBanParticipant");var c=club(a,"IMMEDIATE");String cid=text(c,"id");var e=event(a,cid,version(c),"LIGHTNING",true);String eid=text(e,"id");var r=round(a,eid,version(e),2,false);assertEquals(200,post("/rounds/"+text(r,"id")+"/participations",b,Map.of("version",version(r))).status);String rid="";for(var room:get("/chat/rooms",b).body)if(room.path("kind").asText().equals("EVENT"))rid=room.path("id").asText();assertFalse(rid.isBlank());String bid=text(get("/me",b),"id");assertEquals(200,post("/clubs/"+cid+"/members/"+bid+"/blacklist",a,Map.of("version",version(get("/clubs/"+cid,a)),"enabled",true)).status);assertEquals(200,get("/chat/rooms/"+rid+"/messages",b).status);assertEquals(200,post("/chat/rooms/"+rid+"/messages",b,Map.of("body","확정 참가는 유지")).status);
 }
 @Test void financialHandoverDoesNotGrantChatAndFormerHostWriteEndsWithoutOtherRelationship()throws Exception {
  String owner=user("chatTransferOwner"),host=user("chatTransferHost");var c=club(owner,"IMMEDIATE");String cid=text(c,"id");var j=join(host,cid,version(c),null);var e=event(host,cid,version(j),"LIGHTNING",false);String eid=text(e,"id"),rid="";for(var room:get("/chat/rooms",host).body)if(room.path("kind").asText().equals("EVENT"))rid=room.path("id").asText();assertFalse(rid.isEmpty());assertEquals(200,post("/clubs/"+cid+"/leave",host,Map.of("version",version(get("/clubs/"+cid,owner)))).status);var sql=context.getBean(org.springframework.jdbc.core.JdbcTemplate.class);sql.update("update club_event set responsible_id=? where id=?",UUID.fromString(text(get("/me",owner),"id")),UUID.fromString(eid));assertEquals(200,get("/chat/rooms/"+rid+"/messages",host).status);assertEquals(403,post("/chat/rooms/"+rid+"/messages",host,Map.of("body","인계 후 다른 관계 없음")).status);assertEquals(403,get("/chat/rooms/"+rid+"/messages",owner).status);
 }
 @Test void newGroupInviteesReadOnlyMessagesCommittedAfterTheirAcceptance()throws Exception {
  String a=user("historyBoundaryA"),b=user("historyBoundaryB");String bid=text(get("/me",b),"id");var r=post("/chat/groups",a,Map.of("title","이전 대화 보호","userIds",List.of(bid)));assertEquals(200,r.status,r.body.toString());String rid=text(r,"id");var old=post("/chat/rooms/"+rid+"/messages",a,Map.of("body","초대 수락 전 대화"));assertEquals(200,old.status);var invites=get("/chat/invitations",b);assertEquals(200,invites.status);assertEquals("",invites.body.get(0).path("lastMessage").asText());assertEquals(200,post("/chat/rooms/"+rid+"/invitations/accept",b,Map.of()).status);assertEquals(0,get("/chat/rooms/"+rid+"/messages",b).body.size());assertFalse(context.getBean(PlatformContentAccess.class).canReadMessage(new Actor(UUID.fromString(bid),"ACTIVE","internal-read-test"),UUID.fromString(text(old,"id"))));assertEquals(1,get("/chat/rooms/"+rid+"/messages",a).body.size());assertEquals(200,post("/chat/rooms/"+rid+"/messages",a,Map.of("body","수락 후 대화")).status);assertEquals(1,get("/chat/rooms/"+rid+"/messages",b).body.size());assertEquals(2,get("/chat/rooms/"+rid+"/messages",a).body.size());
 }
 @Test void realSocialActionsCreateGroupedGenericInboxItemsWithoutSelfOrBlockedLeaks()throws Exception {
  String a=user("notifySocialA"),b=user("notifySocialB"),c=user("notifySocialC"),d=user("notifySocialD");String aid=text(get("/me",a),"id"),bid=text(get("/me",b),"id");var p=post("/feed/posts",a,Map.of("body","소셜 알림 글"));assertEquals(200,p.status);String pid=text(p,"id");for(int i=0;i<2;i++){assertEquals(200,post("/users/"+aid+"/follow",b,Map.of("enabled",true)).status);assertEquals(200,post("/feed/posts/"+pid+"/like",b,Map.of("enabled",true)).status);assertEquals(200,post("/feed/posts/"+pid+"/comments",b,Map.of("body","COMMENT_SECRET_"+i)).status);}assertEquals(200,post("/feed/posts/"+pid+"/like",a,Map.of("enabled",true)).status);assertEquals(200,post("/feed/posts/"+pid+"/comments",a,Map.of("body","SELF_SECRET")).status);var inbox=get("/notifications",a);assertEquals(200,inbox.status);assertEquals(3,inbox.body.size(),inbox.body.toString());int count=0;for(var n:inbox.body){assertEquals("SOCIAL",n.path("kind").asText());count+=n.path("count").asInt();assertFalse(n.path("body").asText().contains("SECRET"));}assertEquals(4,count);
  assertEquals(200,post("/users/"+bid+"/block",a,Map.of("enabled",true)).status);assertEquals(403,post("/feed/posts/"+pid+"/comments",b,Map.of("body","BLOCKED_SECRET")).status);assertEquals(3,get("/notifications",a).body.size());var request=post("/chat/direct",a,Map.of("userId",text(get("/me",c),"id"),"body","DM_SECRET"));assertEquals(200,request.status);var dmInbox=get("/notifications",c);assertEquals(1,dmInbox.body.size());assertFalse(dmInbox.body.get(0).path("body").asText().contains("DM_SECRET"));var group=post("/chat/groups",a,Map.of("title","GROUP_SECRET","userIds",List.of(text(get("/me",d),"id"))));assertEquals(200,group.status);var inviteInbox=get("/notifications",d);assertEquals(1,inviteInbox.body.size());assertFalse(inviteInbox.body.get(0).path("body").asText().contains("GROUP_SECRET"));
 }
}
