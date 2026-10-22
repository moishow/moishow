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

class ClubRequestApiTest {
 static PostgreSQLContainer postgres=new PostgreSQLContainer("postgres:17-alpine");
 static ConfigurableApplicationContext context;
 @org.junit.jupiter.api.io.TempDir static java.nio.file.Path storage;
 static String base;
 static ObjectMapper json=new ObjectMapper();
 static HttpClient http=HttpClient.newHttpClient();
 static Map<String,String> sentCodes=new ConcurrentHashMap<>();
 record Reply(int status,JsonNode body) {}
 @Configuration @Profile("club-request-test") static class Providers {
  @Bean @Primary SocialVerifier testSocial(){return (provider,token,nonce)-> {
   if(!token.startsWith("test:"))throw new ApiProblem(401,"INVALID_SOCIAL_TOKEN");
   return new SocialVerifier.Identity(provider,token.substring(5));
  };}
  @Bean @Primary BankOwnershipVerifier bankVerifier(){return (user,bank,number,holder)->"verified-test-only";}
  @Bean @Primary SmsGateway testSms(){return (phone,code)->sentCodes.put(phone,code);}
 }
 @BeforeAll static void start(){
  postgres.start();
  context=new SpringApplicationBuilder(MoishowServerApplication.class,Providers.class).profiles("db","dev","club-request-test")
   .properties("server.port=0","BANK_DATA_KEY_BASE64=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=","logging.level.root=ERROR","spring.main.banner-mode=off",
    "spring.datasource.url="+postgres.getJdbcUrl(),"spring.datasource.username="+postgres.getUsername(),"spring.datasource.password="+postgres.getPassword()).run("--FILE_STORAGE_MODE=LOCAL","--FILE_STORAGE_ROOT="+storage,"--spring.datasource.url="+postgres.getJdbcUrl(),"--spring.datasource.username="+postgres.getUsername(),"--spring.datasource.password="+postgres.getPassword());
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
  return post("/clubs/"+clubId+"/events",host,Map.of("title","번개","kind",kind,"publicEvent",open,"settlementMode","POSTPAY","startsAt",Instant.now().plusSeconds(3600).toString(),"endsAt",Instant.now().plusSeconds(7200).toString(),"version",v));
 }
 static Reply round(String host,String eventId,long v,int capacity,boolean closed)throws Exception {
  return post("/events/"+eventId+"/rounds",host,Map.of("capacity",capacity,"closesAt",Instant.now().plusSeconds(closed?-60:1800).toString(),"cancellationFee",1000,"version",v));
 }

 static Reply account(String owner,String cid)throws Exception{return post("/clubs/"+cid+"/reserve/account",owner,Map.of("version",0,"bankName","테스트은행","accountNumber","123456789012","holderName","계좌담당"));}

 static final byte[] PNG=Base64.getDecoder().decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a9wAAAABJRU5ErkJggg==");
 static Reply upload(String token,String scope,String clubId,String eventId,byte[] bytes,String key)throws Exception{
  String boundary="moishow-boundary-"+UUID.randomUUID();var out=new java.io.ByteArrayOutputStream();
  var fields=new LinkedHashMap<String,String>();fields.put("scope",scope);if(clubId!=null)fields.put("clubId",clubId);if(eventId!=null)fields.put("eventId",eventId);
  for(var f:fields.entrySet())out.write(("--"+boundary+"\r\nContent-Disposition: form-data; name=\""+f.getKey()+"\"\r\n\r\n"+f.getValue()+"\r\n").getBytes(java.nio.charset.StandardCharsets.UTF_8));
  out.write(("--"+boundary+"\r\nContent-Disposition: form-data; name=\"file\"; filename=\"receipt.png\"\r\nContent-Type: image/png\r\n\r\n").getBytes(java.nio.charset.StandardCharsets.UTF_8));out.write(bytes);out.write(("\r\n--"+boundary+"--\r\n").getBytes(java.nio.charset.StandardCharsets.UTF_8));
  var req=HttpRequest.newBuilder(URI.create(base+"/files")).header("Authorization","Bearer "+token).header("Idempotency-Key",key).header("Content-Type","multipart/form-data; boundary="+boundary).POST(HttpRequest.BodyPublishers.ofByteArray(out.toByteArray())).build();
  var res=http.send(req,HttpResponse.BodyHandlers.ofString());return new Reply(res.statusCode(),res.body().isBlank()?json.createObjectNode():json.readTree(res.body()));
 }
 static int readFile(String token,String id)throws Exception{return http.send(HttpRequest.newBuilder(URI.create(base+"/files/"+id)).header("Authorization","Bearer "+token).GET().build(),HttpResponse.BodyHandlers.ofByteArray()).statusCode();}


 @Test void discoveryFiltersActualIntroMetadataWithoutExposingInternalContent()throws Exception {
  String owner=user("filterOwner"),reader=user("filterReader");
  var a=post("/clubs",owner,Map.of("name","필터산책서울","joinMode","IMMEDIATE","description","강변 산책","region","서울","category","산책"));assertEquals(200,a.status,a.body.toString());
  post("/clubs",owner,Map.of("name","필터산책부산","joinMode","IMMEDIATE","region","부산","category","산책"));
  post("/clubs",owner,Map.of("name","필터독서서울","joinMode","IMMEDIATE","region","서울","category","독서"));
  var filtered=get("/clubs/discover?q="+java.net.URLEncoder.encode("필터",java.nio.charset.StandardCharsets.UTF_8)+"&region="+java.net.URLEncoder.encode("서울",java.nio.charset.StandardCharsets.UTF_8)+"&category="+java.net.URLEncoder.encode("산책",java.nio.charset.StandardCharsets.UTF_8),reader);
  assertEquals(200,filtered.status);assertEquals(1,filtered.body.size());assertEquals(text(a,"id"),filtered.body.get(0).path("id").asText());assertEquals(1,filtered.body.get(0).path("activeMemberCount").asInt());
  assertEquals("강변 산책",text(get("/clubs/"+text(a,"id"),reader),"description"));

 }
 @Test void clubIntroUsesOptionalTrimmedMetadataAndOnlyExplicitPersonalImage()throws Exception {
  String owner=user("introOwner"),outsider=user("introOut");
  var image=upload(owner,"POST",null,null,PNG,UUID.randomUUID().toString());assertEquals(200,image.status);
  var other=upload(owner,"POST",null,null,PNG,UUID.randomUUID().toString());
  var c=post("/clubs",owner,Map.of("name","소개모임","joinMode","APPROVAL","description"," 함께 걸어요 ","region"," 서울 ","category"," 산책 ","imageFileId",text(image,"id")));assertEquals(200,c.status,c.body.toString());String cid=text(c,"id");
  var intro=get("/clubs/"+cid,outsider);assertEquals("함께 걸어요",text(intro,"description"));assertEquals("서울",text(intro,"region"));assertEquals("산책",text(intro,"category"));assertEquals(1,intro.body.path("activeMemberCount").asInt());
  assertEquals(200,readFile(outsider,text(image,"id")));assertEquals(403,readFile(outsider,text(other,"id")));
  assertEquals(400,post("/clubs",owner,Map.of("name","길이","joinMode","IMMEDIATE","description","가".repeat(1001))).status);
  assertEquals(403,post("/clubs/"+cid+"/metadata",outsider,Map.of("version",version(c),"description","변경")).status);
  var privateImage=upload(owner,"POST",cid,null,PNG,UUID.randomUUID().toString());
  assertEquals(403,post("/clubs/"+cid+"/metadata",owner,Map.of("version",version(c),"imageFileId",text(privateImage,"id"))).status);
  assertEquals(403,post("/clubs",outsider,Map.of("name","훔친사진","joinMode","IMMEDIATE","imageFileId",text(image,"id"))).status);
  var changed=post("/clubs/"+cid+"/metadata",owner,Map.of("version",version(c),"description","", "clearImage",true));assertEquals(200,changed.status,changed.body.toString());assertEquals(403,readFile(outsider,text(image,"id")));
 }
 @Test void pendingMembershipCanBeRejectedWithPrivateHistoryAndReappliedWithoutPermanentBan()throws Exception {
  String owner=user("requestOwner"),applicant=user("requestApplicant"),other=user("requestOther");var c=club(owner,"APPROVAL");String cid=text(c,"id"),uid=text(get("/me",applicant),"id");
  var pending=post("/clubs/"+cid+"/join",applicant,Map.of("nickname","신청자","version",version(c),"memo","가입 메모"));assertEquals(200,pending.status);
  assertFalse(get("/clubs/"+cid,other).body.toString().contains("가입 메모"));
  assertEquals("가입 메모",get("/clubs/"+cid+"/join-requests",owner).body.get(0).path("memo").asText());
  var pendingHistory=get("/clubs/"+cid+"/join-history",applicant);assertEquals("신청자",pendingHistory.body.get(0).path("nickname").asText());assertEquals("신청자",pendingHistory.body.get(0).path("actorNickname").asText());assertTrue(pendingHistory.body.get(0).has("departed"));assertFalse(pendingHistory.body.get(0).path("departed").asBoolean());
  assertEquals(403,post("/clubs/"+cid+"/members/"+uid+"/reject",other,Map.of("version",version(pending),"reason","사유")).status);
  String rejectKey=UUID.randomUUID().toString();var rejectBody=Map.of("version",version(pending),"reason","가입 거절 사유");var rejected=call("POST","/clubs/"+cid+"/members/"+uid+"/reject",owner,rejectBody,rejectKey);assertEquals(rejected.body,call("POST","/clubs/"+cid+"/members/"+uid+"/reject",owner,rejectBody,rejectKey).body);assertEquals(200,rejected.status,rejected.body.toString());assertEquals("REJECTED",text(rejected,"membershipStatus"));
  var history=get("/clubs/"+cid+"/join-history",applicant);assertEquals(2,history.body.size());assertTrue(history.body.toString().contains("가입 거절 사유"));assertEquals("신청자",history.body.get(1).path("nickname").asText());assertEquals("requestOwner",history.body.get(1).path("actorNickname").asText());assertTrue(history.body.get(1).has("actorDeparted"));assertFalse(history.body.get(1).path("actorDeparted").asBoolean());assertEquals(0,get("/clubs/"+cid+"/join-history",other).body.size());
  var again=join(applicant,cid,version(rejected),null);assertEquals("PENDING",text(again,"membershipStatus"));
  var approved=post("/clubs/"+cid+"/members/"+uid+"/approve",owner,Map.of("version",version(again)));assertEquals(200,approved.status);
  assertEquals(409,post("/clubs/"+cid+"/members/"+uid+"/reject",owner,Map.of("version",version(approved),"reason","확정자 제외 금지")).status);
  assertEquals(2,get("/clubs/"+cid,other).body.path("activeMemberCount").asInt());
  var renamed=post("/clubs/"+cid+"/nickname",applicant,Map.of("version",version(get("/clubs/"+cid,applicant)),"nickname","현재 신청 닉네임"));assertEquals(200,renamed.status,renamed.body.toString());
  assertEquals(200,post("/clubs/"+cid+"/leave",applicant,Map.of("version",version(renamed))).status);
  var departed=get("/clubs/"+cid+"/join-history",applicant);assertEquals("현재 신청 닉네임",departed.body.get(1).path("nickname").asText());assertTrue(departed.body.get(1).path("departed").asBoolean());assertEquals("현재 신청 닉네임",departed.body.get(0).path("actorNickname").asText());assertTrue(departed.body.get(0).path("actorDeparted").asBoolean());
  var unrelated=get("/clubs/"+cid+"/join-history",other);assertEquals(0,unrelated.body.size());assertFalse(unrelated.body.toString().contains("가입 메모"));
 }
 @Test void lateRequestRejectionDoesNotCreateFeeOrScoreAndCannotExcludeConfirmedParticipant()throws Exception {
  String owner=user("lateOwner"),applicant=user("lateApplicant"),other=user("lateOther");var c=club(owner,"IMMEDIATE");var e=event(owner,text(c,"id"),version(c),"LIGHTNING",true);String eid=text(e,"id");var r=round(owner,eid,version(e),2,true);String rid=text(r,"id");
  var pending=post("/rounds/"+rid+"/participations",applicant,Map.of("version",version(r),"memo","일곱시 도착"));assertEquals(200,pending.status);
  assertEquals(403,post("/rounds/"+rid+"/participations/"+text(pending,"id")+"/reject",other,Map.of("version",version(pending),"reason","거절")).status);
  var jdbc=context.getBean(org.springframework.jdbc.core.JdbcTemplate.class);jdbc.update("update club_event set responsible_id=? where id=?",UUID.fromString(text(get("/me",other),"id")),UUID.fromString(eid));
  assertEquals(403,post("/rounds/"+rid+"/participations/"+text(pending,"id")+"/reject",other,Map.of("version",version(pending),"reason","정산인수는 운영권 아님")).status);
  assertFalse(get("/events/"+eid+"/participations",other).body.toString().contains("일곱시 도착"));
  var rejected=post("/rounds/"+rid+"/participations/"+text(pending,"id")+"/reject",owner,Map.of("version",version(pending),"reason","장소 마감"));assertEquals(200,rejected.status,rejected.body.toString());assertEquals("REJECTED",text(rejected,"status"));
  var lateHistory=get("/rounds/"+rid+"/request-history",applicant);assertTrue(lateHistory.body.toString().contains("일곱시 도착"));assertEquals("lateApplicant",lateHistory.body.get(1).path("nickname").asText());assertEquals("lateOwner",lateHistory.body.get(1).path("actorNickname").asText());assertTrue(lateHistory.body.get(1).has("departed"));assertFalse(lateHistory.body.get(1).path("departed").asBoolean());assertEquals(0,get("/rounds/"+rid+"/request-history",other).body.size());
  var sql=context.getBean(org.springframework.jdbc.core.JdbcTemplate.class);UUID pid=UUID.fromString(text(pending,"id"));assertEquals(false,sql.queryForObject("select ever_confirmed from participation where id=?",Boolean.class,pid));
  assertEquals(0,sql.queryForObject("select count(*) from payment_request where user_id=?",Integer.class,UUID.fromString(text(get("/me",applicant),"id"))));
  // Existing event join uniqueness remains: rejection is not a blacklist and does not silently reopen a participation.
  assertEquals(409,post("/rounds/"+rid+"/participations",applicant,Map.of("version",version(rejected))).status);
  var r2=round(owner,eid,version(get("/events/"+eid,owner)),2,false);var confirmed=post("/rounds/"+text(r2,"id")+"/participations",applicant,Map.of("version",version(r2)));
  assertEquals(409,post("/rounds/"+text(r2,"id")+"/participations/"+text(confirmed,"id")+"/reject",owner,Map.of("version",version(confirmed),"reason","선별 탈락 금지")).status);
 }

 @Test void rejectedNeverConfirmedRequestCannotBeReclassifiedByFinancialManager()throws Exception {
  String owner=user("rejectCorrectOwner"),applicant=user("rejectCorrectApplicant"),successor=user("rejectCorrectSuccessor");
  var c=club(owner,"IMMEDIATE");var e=event(owner,text(c,"id"),version(c),"LIGHTNING",true);String eid=text(e,"id");var r=round(owner,eid,version(e),2,true);String rid=text(r,"id");
  var request=post("/rounds/"+rid+"/participations",applicant,Map.of("version",version(r),"memo","합류 요청"));String pid=text(request,"id");
  var rejected=post("/rounds/"+rid+"/participations/"+pid+"/reject",owner,Map.of("version",version(request),"reason","합류 거절"));assertEquals(200,rejected.status,rejected.body.toString());
  var book=post("/events/"+eid+"/finance/open",owner,Map.of("version",0,"mode","POSTPAY"));assertEquals(200,book.status,book.body.toString());
  var sql=context.getBean(org.springframework.jdbc.core.JdbcTemplate.class);
  for(String manager:List.of(owner,successor)){
   // Isolate the existing current financial-manager boundary with a controlled database fixture.
   sql.update("update club_event set responsible_id=? where id=?",UUID.fromString(text(get("/me",manager),"id")),UUID.fromString(eid));
   for(String target:List.of("CANCELLED","NO_SHOW","CONFIRMED"))assertEquals(409,post("/events/"+eid+"/finance/participations/"+pid+"/correct",manager,Map.of("version",version(get("/events/"+eid+"/finance",manager)),"status",target,"reason","거절은 금융정정으로 재승인하지 않음")).status);
  }
  assertEquals(false,sql.queryForObject("select ever_confirmed from participation where id=?",Boolean.class,UUID.fromString(pid)));
  assertEquals("REJECTED",text(get("/rounds/"+rid+"/participation",applicant),"status"));UUID uid=UUID.fromString(text(get("/me",applicant),"id"));
  assertEquals(0,sql.queryForObject("select count(*) from payment_request where user_id=?",Integer.class,uid));assertEquals(0,sql.queryForObject("select count(*) from platform_level where user_id=? and role='PARTICIPANT'",Integer.class,uid));
 }
}
