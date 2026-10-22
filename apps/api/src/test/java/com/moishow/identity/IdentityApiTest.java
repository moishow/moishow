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

class IdentityApiTest {
 static PostgreSQLContainer postgres=new PostgreSQLContainer("postgres:17-alpine");
 static ConfigurableApplicationContext context;
 static String base;
 static ObjectMapper json=new ObjectMapper();
 static HttpClient http=HttpClient.newHttpClient();
 static Map<String,String> sentCodes=new ConcurrentHashMap<>();
 record Reply(int status,JsonNode body) {}
 @Configuration @Profile("identity-test") static class Providers {
  @Bean @Primary SocialVerifier testSocial(){return (provider,token,nonce)-> {
   if(!token.startsWith("test:"))throw new ApiProblem(401,"INVALID_SOCIAL_TOKEN");
   return new SocialVerifier.Identity(provider,token.substring(5));
  };}
  @Bean @Primary SmsGateway testSms(){return (phone,code)->sentCodes.put(phone,code);}
 }
 @BeforeAll static void start(){
  postgres.start();
  context=new SpringApplicationBuilder(MoishowServerApplication.class,Providers.class).profiles("db","identity-test")
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
  return post("/clubs/"+clubId+"/events",host,Map.of("title","번개","kind",kind,"publicEvent",open,"startsAt",Instant.now().plusSeconds(3600).toString(),"endsAt",Instant.now().plusSeconds(7200).toString(),"version",v));
 }
 static Reply round(String host,String eventId,long v,int capacity,boolean closed)throws Exception {
  return post("/events/"+eventId+"/rounds",host,Map.of("capacity",capacity,"closesAt",Instant.now().plusSeconds(closed?-60:1800).toString(),"cancellationFee",1000,"version",v));
 }
 @Test void identityHasRestrictedOnboardingAndRevocableOpaqueSessions()throws Exception {
  var login=post("/auth/social",null,Map.of("provider","GOOGLE","token","test:onboard"));assertEquals(200,login.status);
  assertEquals("ONBOARDING",text(login,"scope"));
  assertEquals(403,club(text(login,"token"),"IMMEDIATE").status);
  assertEquals(401,get("/me","forged").status);
  String token=user("session");assertEquals(200,get("/me",token).status);
  assertEquals(200,post("/auth/logout",token,Map.of()).status);
  assertEquals(401,get("/me",token).status);
 }
 @Test void phoneCannotBeMergedAcrossSocialIdentitiesAndOtpCannotBeForged()throws Exception {
  String active=user("phoneOwner");String phone=text(get("/me",active),"phone");
  var login=post("/auth/social",null,Map.of("provider","APPLE","token","test:otherSocial"));String pending=text(login,"token");
  context.getBean(org.springframework.jdbc.core.JdbcTemplate.class).update("update sms_challenge set created_at=now()-interval '61 seconds' where phone=?",phone);
  var sms=post("/auth/sms",pending,Map.of("phone",phone));assertEquals(200,sms.status);
  assertEquals(400,post("/auth/sms/"+text(sms,"id")+"/verify",pending,Map.of("code","wrong")).status);
  assertEquals(200,post("/auth/sms/"+text(sms,"id")+"/verify",pending,Map.of("code",sentCodes.get(phone))).status);
  assertEquals(409,post("/auth/register",pending,Map.of("nickname","다른계정","verificationId",text(sms,"id"))).status);
  assertEquals(401,post("/auth/social",null,Map.of("provider","GOOGLE","token","invalid")).status);
 }
 @Test void clubWritesAreIdempotentAndRejectConflictingReuse()throws Exception {
  String host=user("idempotent");String key=UUID.randomUUID().toString();var body=Map.of("name","원본","joinMode","IMMEDIATE");
  var first=call("POST","/clubs",host,body,key);assertEquals(200,first.status);
  var second=call("POST","/clubs",host,body,key);assertEquals(first.body,second.body);
  assertEquals(409,call("POST","/clubs",host,Map.of("name","변경","joinMode","IMMEDIATE"),key).status);
  assertEquals(400,call("POST","/clubs",host,body,null).status);
 }
 @Test void membershipInvitationExpulsionAndBlacklistHavePolicyPriority()throws Exception {
  String host=user("owner"),member=user("member"),outsider=user("outsider");
  var c=club(host,"APPROVAL");String id=text(c,"id");
  assertEquals("PENDING",text(join(member,id,version(c),null),"membershipStatus"));
  var current=get("/clubs/"+id,host);
  String memberId=text(get("/me",member),"id");
  assertEquals(403,post("/clubs/"+id+"/members/"+memberId+"/approve",outsider,Map.of("version",version(current))).status);
  var approved=post("/clubs/"+id+"/members/"+memberId+"/approve",host,Map.of("version",version(current)));assertEquals(200,approved.status);
  var expelled=post("/clubs/"+id+"/members/"+memberId+"/expel",host,Map.of("version",version(approved)));assertEquals(200,expelled.status);
  var invite=post("/clubs/"+id+"/invites",host,Map.of("version",version(expelled)));assertEquals(200,invite.status);
  var rejoin=join(member,id,version(invite),text(invite,"inviteToken"));assertEquals("PENDING",text(rejoin,"membershipStatus"));
  var banned=post("/clubs/"+id+"/members/"+memberId+"/blacklist",host,Map.of("version",version(rejoin),"enabled",true));assertEquals(200,banned.status);
  assertEquals(403,join(member,id,version(banned),text(invite,"inviteToken")).status);
  assertEquals(200,club(member,"IMMEDIATE").status);
  assertEquals(403,post("/clubs/"+id+"/leave",host,Map.of("version",version(banned))).status);
 }
 @Test void memberCanHostLightningButRegularAndPrivateEventAccessAreRestricted()throws Exception {
  String host=user("rolesHost"),member=user("rolesMember"),outsider=user("rolesOut");var c=club(host,"IMMEDIATE");String id=text(c,"id");
  var joined=join(member,id,version(c),null);assertEquals(200,joined.status);
  assertEquals(403,event(member,id,version(joined),"REGULAR",false).status);
  var lightning=event(member,id,version(joined),"LIGHTNING",false);assertEquals(200,lightning.status);
  assertEquals(403,get("/events/"+text(lightning,"id"),outsider).status);
  var access=get("/events/"+text(lightning,"id")+"/access",host);assertFalse(access.body.path("manageSettlement").asBoolean());
  assertTrue(get("/events/"+text(lightning,"id")+"/access",member).body.path("manageSettlement").asBoolean());
 }
 @Test void capacityLateApprovalAndHistoricalAccessSurviveClubLeave()throws Exception {
  String host=user("roundHost"),a=user("roundA"),b=user("roundB");var c=club(host,"IMMEDIATE");String clubId=text(c,"id");
  var e=event(host,clubId,version(c),"LIGHTNING",true);String eventId=text(e,"id");var r=round(host,eventId,version(e),1,false);String roundId=text(r,"id");
  var pa=post("/rounds/"+roundId+"/participations",a,Map.of("version",version(r)));assertEquals("CONFIRMED",text(pa,"status"));
  var pb=post("/rounds/"+roundId+"/participations",b,Map.of("version",version(pa)));assertEquals("WAITLISTED",text(pb,"status"));
  assertFalse(get("/events/"+eventId+"/access",b).body.path("viewSettlement").asBoolean());
  var r2=round(host,eventId,version(get("/events/"+eventId,host)),2,true);String rid2=text(r2,"id");
  var late=post("/rounds/"+rid2+"/participations",a,Map.of("version",version(r2)));assertEquals("LATE_REQUESTED",text(late,"status"));
  assertEquals(403,post("/rounds/"+rid2+"/participations/"+text(late,"id")+"/approve",b,Map.of("version",version(late))).status);
  assertEquals("CONFIRMED",text(post("/rounds/"+rid2+"/participations/"+text(late,"id")+"/approve",host,Map.of("version",version(late))),"status"));
  var left=post("/clubs/"+clubId+"/leave",host,Map.of("version",version(get("/clubs/"+clubId,host))));assertEquals(403,left.status);
  assertTrue(get("/events/"+eventId+"/access",a).body.path("viewSettlement").asBoolean());
 }
 @Test void parallelRequestsCannotOverbookAndStaleVersionsFail()throws Exception {
  String host=user("raceHost"),a=user("raceA"),b=user("raceB");var c=club(host,"IMMEDIATE");var e=event(host,text(c,"id"),version(c),"LIGHTNING",true);var r=round(host,text(e,"id"),version(e),1,false);String path="/rounds/"+text(r,"id")+"/participations";
  try(var pool=Executors.newVirtualThreadPerTaskExecutor()){
   var fa=pool.submit(()->post(path,a,Map.of("version",version(r))));var fb=pool.submit(()->post(path,b,Map.of("version",version(r))));
   var replies=List.of(fa.get(),fb.get());assertEquals(1,replies.stream().filter(x->x.status==200).count());assertEquals(1,replies.stream().filter(x->x.status==409).count());
   var winner=replies.stream().filter(x->x.status==200).findFirst().orElseThrow();String loser=fa.get().status==409?a:b;
   assertEquals("WAITLISTED",text(post(path,loser,Map.of("version",version(winner))),"status"));
  }
 }

 @Test void leavingClubKeepsEventResponsibilityButRemovesClubManagement()throws Exception {
  String owner=user("leaveOwner"),host=user("leaveHost");var c=club(owner,"IMMEDIATE");String cid=text(c,"id");var joined=join(host,cid,version(c),null);
  var e=event(host,cid,version(joined),"LIGHTNING",false);String eid=text(e,"id");
  var left=post("/clubs/"+cid+"/leave",host,Map.of("version",version(get("/clubs/"+cid,owner))));assertEquals(200,left.status);
  var access=get("/events/"+eid+"/access",host);assertEquals(200,access.status);assertTrue(access.body.path("manageSettlement").asBoolean());assertFalse(access.body.path("manageEvent").asBoolean());
  assertEquals(403,get("/clubs/"+cid+"/members",host).status);
  assertEquals(403,round(host,eid,version(e),2,false).status);
 }
 @Test void blacklistBlocksPublicParticipationAndLateApprovalAndPersistsOutsideMembership()throws Exception {
  String host=user("banHost"),a=user("banA");var c=club(host,"IMMEDIATE");String cid=text(c,"id");var e=event(host,cid,version(c),"LIGHTNING",true);String eid=text(e,"id");var r=round(host,eid,version(e),1,true);
  var late=post("/rounds/"+text(r,"id")+"/participations",a,Map.of("version",version(r)));assertEquals("LATE_REQUESTED",text(late,"status"));
  String uid=text(get("/me",a),"id");var ban=post("/clubs/"+cid+"/members/"+uid+"/blacklist",host,Map.of("version",version(get("/clubs/"+cid,host)),"enabled",true));assertEquals(200,ban.status);
  assertEquals(403,post("/rounds/"+text(r,"id")+"/participations/"+text(late,"id")+"/approve",host,Map.of("version",version(late))).status);
  var r2=round(host,eid,version(get("/events/"+eid,host)),1,false);
  assertEquals(403,post("/rounds/"+text(r2,"id")+"/participations",a,Map.of("version",version(r2))).status);
 }
 @Test void otpAttemptsAndSessionExpiryAreEnforcedAndRawTokensAreNotStored()throws Exception {
  var login=post("/auth/social",null,Map.of("provider","GOOGLE","token","test:attempts"));String token=text(login,"token");String phone="+821099999998";
  var challenge=post("/auth/sms",token,Map.of("phone",phone));assertEquals(200,challenge.status);
  assertEquals(400,post("/auth/register",token,Map.of("nickname","bad","verificationId",text(challenge,"id"))).status);
  for(int i=0;i<5;i++)assertEquals(400,post("/auth/sms/"+text(challenge,"id")+"/verify",token,Map.of("code","bad")).status);
  assertEquals(400,post("/auth/sms/"+text(challenge,"id")+"/verify",token,Map.of("code",sentCodes.get(phone))).status);
  var jdbc=context.getBean(org.springframework.jdbc.core.JdbcTemplate.class);
  assertEquals(5,jdbc.queryForObject("select attempts from sms_challenge where id=?",Integer.class,UUID.fromString(text(challenge,"id"))));
  assertEquals(0,jdbc.queryForObject("select count(*) from service_session where token_hash=?",Integer.class,token));
  jdbc.update("update service_session set expires_at=now()-interval '1 second' where user_id=?",UUID.fromString(text(login,"userId")));
  assertEquals(401,post("/auth/sms",token,Map.of("phone","+821099999997")).status);
 }
 @Test void loginNonceCannotBeReplayed()throws Exception {
  var c=post("/auth/challenges",null,Map.of());var b=Map.of("provider","APPLE","token","test:nonce","challengeId",text(c,"challengeId"));
  assertEquals(200,call("POST","/auth/social",null,b,null).status);
  assertEquals(401,call("POST","/auth/social",null,b,null).status);
 }
 @Test void databaseRejectsDuplicateSocialPhoneAndDanglingMembership()throws Exception {
  String token=user("constraints");var me=get("/me",token);var jdbc=context.getBean(org.springframework.jdbc.core.JdbcTemplate.class);
  assertThrows(org.springframework.dao.DataIntegrityViolationException.class,()->jdbc.update("insert into app_user(id,version,provider,subject,phone,nickname,status) values(?,0,'APPLE',? ,?,'x','ACTIVE')",UUID.randomUUID(),UUID.randomUUID().toString(),text(me,"phone")));
  assertThrows(org.springframework.dao.DataIntegrityViolationException.class,()->jdbc.update("insert into membership(id,version,club_id,user_id,role,status,expelled_history,blacklisted) values(?,0,?,?,'MEMBER','NONE',false,false)",UUID.randomUUID(),UUID.randomUUID(),UUID.fromString(text(me,"id"))));
  assertEquals(1,jdbc.queryForObject("select count(*) from flyway_schema_history where version='1' and success",Integer.class));
 }
 @Test void concurrentSameCommandCreatesOnlyOneClub()throws Exception {
  String host=user("sameCommand");String key=UUID.randomUUID().toString();var body=Map.of("name","一回","joinMode","IMMEDIATE");
  try(var pool=Executors.newVirtualThreadPerTaskExecutor()){
   var a=pool.submit(()->call("POST","/clubs",host,body,key));var b=pool.submit(()->call("POST","/clubs",host,body,key));
   assertEquals(200,a.get().status);assertEquals(200,b.get().status);assertEquals(a.get().body,b.get().body);
   assertEquals(1,get("/clubs",host).body.size());
  }
 }

 @Test void roundCreationReturnsParentVersionForConsecutiveRounds()throws Exception {
  String host=user("parentVersion");var c=club(host,"IMMEDIATE");var e=event(host,text(c,"id"),version(c),"LIGHTNING",true);String eid=text(e,"id");
  var first=round(host,eid,version(e),2,false);assertEquals(version(e)+1,first.body.path("eventVersion").asLong());
  assertEquals(200,round(host,eid,first.body.path("eventVersion").asLong(),2,false).status);
 }
 @Test void adminDiscoversJoinRequestsWithoutApplicantSharingTheirId()throws Exception {
  String host=user("queueOwner"),member=user("queueMember"),other=user("queueOther");var c=club(host,"APPROVAL");String cid=text(c,"id");assertEquals(200,join(member,cid,version(c),null).status);
  var requests=get("/clubs/"+cid+"/join-requests",host);assertEquals(200,requests.status);assertEquals(1,requests.body.size());var request=requests.body.get(0);
  assertEquals(403,get("/clubs/"+cid+"/join-requests",other).status);assertEquals(403,get("/clubs/"+cid+"/join-requests",member).status);
  assertEquals(200,post("/clubs/"+cid+"/members/"+request.path("userId").asText()+"/approve",host,Map.of("version",request.path("version").asLong())).status);
  assertEquals(0,get("/clubs/"+cid+"/join-requests",host).body.size());
 }
 @Test void hostDiscoversLateRequestsAndParticipantCanReloadOwnState()throws Exception {
  String host=user("lateQueueHost"),a=user("lateQueueA"),other=user("lateQueueOther");var c=club(host,"IMMEDIATE");var e=event(host,text(c,"id"),version(c),"LIGHTNING",true);String eid=text(e,"id");var r=round(host,eid,version(e),2,true);String rid=text(r,"id");
  assertEquals(200,post("/rounds/"+rid+"/participations",a,Map.of("version",version(r))).status);
  var own=get("/rounds/"+rid+"/participation",a);assertEquals(200,own.status);assertEquals("LATE_REQUESTED",text(own,"status"));
  assertEquals(404,get("/rounds/"+rid+"/participation",other).status);
  var list=get("/events/"+eid+"/participations",host);assertEquals(200,list.status);assertEquals(1,list.body.size());var item=list.body.get(0);
  assertEquals(403,get("/events/"+eid+"/participations",other).status);assertEquals(403,get("/events/"+eid+"/participations",a).status);
  assertEquals(200,post("/rounds/"+rid+"/participations/"+item.path("id").asText()+"/approve",host,Map.of("version",item.path("version").asLong())).status);
  assertEquals("CONFIRMED",text(get("/rounds/"+rid+"/participation",a),"status"));
 }
 @Test void onboardingUserCannotBypassSmsCooldownByChangingPhone()throws Exception {
  String pending=text(post("/auth/social",null,Map.of("provider","GOOGLE","token","test:smsQuota")),"token");
  assertEquals(200,post("/auth/sms",pending,Map.of("phone","+821099999991")).status);
  assertEquals(429,post("/auth/sms",pending,Map.of("phone","+821099999992")).status);
 }
}
