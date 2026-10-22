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

class FileApiTest {
 static PostgreSQLContainer postgres=new PostgreSQLContainer("postgres:17-alpine");
 static ConfigurableApplicationContext context;
 @org.junit.jupiter.api.io.TempDir static java.nio.file.Path storage;
 static String base;
 static ObjectMapper json=new ObjectMapper();
 static HttpClient http=HttpClient.newHttpClient();
 static Map<String,String> sentCodes=new ConcurrentHashMap<>();
 record Reply(int status,JsonNode body) {}
 @Configuration @Profile("file-test") static class Providers {
  @Bean @Primary SocialVerifier testSocial(){return (provider,token,nonce)-> {
   if(!token.startsWith("test:"))throw new ApiProblem(401,"INVALID_SOCIAL_TOKEN");
   return new SocialVerifier.Identity(provider,token.substring(5));
  };}
  @Bean @Primary BankOwnershipVerifier bankVerifier(){return (user,bank,number,holder)->"verified-test-only";}
  @Bean @Primary SmsGateway testSms(){return (phone,code)->sentCodes.put(phone,code);}
 }
 @BeforeAll static void start(){
  postgres.start();
  context=new SpringApplicationBuilder(MoishowServerApplication.class,Providers.class).profiles("db","file-test")
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
 @Test void stagedFilesAreOwnerOnlyAndUploadKeyIsBoundToBytesAndContext()throws Exception {
  String owner=user("fileOwner"),other=user("fileOther");String key=UUID.randomUUID().toString();var uploaded=upload(owner,"POST",null,null,PNG,key);assertEquals(200,uploaded.status,uploaded.body.toString());String id=text(uploaded,"id");assertEquals(200,readFile(owner,id));assertEquals(403,readFile(other,id));
  assertEquals(uploaded.body,upload(owner,"POST",null,null,PNG,key).body);
  assertEquals(409,upload(owner,"POST",null,null,"not-an-image".getBytes(),key).status);
  assertEquals(400,upload(owner,"POST",null,null,"pretend-image".getBytes(),UUID.randomUUID().toString()).status);
 }
 @Test void attachedClubPhotosUseLiveMembershipRatherThanFollowing()throws Exception {
  String owner=user("photoOwner"),member=user("photoMember"),outsider=user("photoOut");var c=club(owner,"IMMEDIATE");String cid=text(c,"id");assertEquals(200,join(member,cid,version(c),null).status);
  var photo=upload(owner,"POST",cid,null,PNG,UUID.randomUUID().toString());assertEquals(200,photo.status);String id=text(photo,"id");
  var post=post("/feed/posts",owner,Map.of("clubId",cid,"body","모임 사진","photoIds",List.of(id)));assertEquals(200,post.status,post.body.toString());
  assertEquals(200,readFile(member,id));assertEquals(403,readFile(outsider,id));
  assertEquals(200,post("/clubs/"+cid+"/leave",member,Map.of("version",version(get("/clubs/"+cid,owner)))).status);assertEquals(403,readFile(member,id));
 }
 @Test void financialDisputePhotoIsNotMadePublicByClubMembership()throws Exception {
  String owner=user("proofHost"),member=user("proofMember");var c=club(owner,"IMMEDIATE");String cid=text(c,"id");var j=join(member,cid,version(c),null);var e=event(owner,cid,version(j),"LIGHTNING",false);String eid=text(e,"id");var b=post("/events/"+eid+"/finance/open",owner,Map.of("version",0,"mode","POSTPAY"));assertEquals(200,b.status);
  var proof=upload(member,"DISPUTE",null,eid,PNG,UUID.randomUUID().toString());assertEquals(200,proof.status,proof.body.toString());String id=text(proof,"id");assertEquals(403,readFile(owner,id));
  var sql=context.getBean(org.springframework.jdbc.core.JdbcTemplate.class);UUID did=UUID.randomUUID();sql.update("insert into finance_dispute(id,version,book_id,user_id,status,reason,evidence,created_at,correction_amount) values(?,0,?,?,'OPEN','test-proof',?,now(),0)",did,UUID.fromString(text(b,"id")),UUID.fromString(text(get("/me",member),"id")),"file:"+id);
  assertEquals(200,readFile(owner,id));String unrelated=user("proofUnrelated");var clubNow=get("/clubs/"+cid,owner);assertEquals(200,join(unrelated,cid,version(clubNow),null).status);assertEquals(403,readFile(unrelated,id));
 }

 @Test void originalReceiptProcessorKeepsOnlyTheirEvidenceAfterHandover()throws Exception {
  String owner=user("receiptOld"),payer=user("receiptPayer"),successor=user("receiptNew"),unrelated=user("receiptOther");
  var c=club(owner,"IMMEDIATE");String cid=text(c,"id");assertEquals(200,join(payer,cid,version(c),null).status);
  var e=event(owner,cid,version(get("/clubs/"+cid,owner)),"LIGHTNING",false);String eid=text(e,"id");
  var b=post("/events/"+eid+"/finance/open",owner,Map.of("version",0,"mode","POSTPAY"));assertEquals(200,b.status);
  var proof=upload(payer,"PAYMENT",null,eid,PNG,UUID.randomUUID().toString());assertEquals(200,proof.status,proof.body.toString());String file=text(proof,"id");
  var sql=context.getBean(org.springframework.jdbc.core.JdbcTemplate.class);UUID request=UUID.randomUUID();
  UUID oldId=UUID.fromString(text(get("/me",owner),"id")),payerId=UUID.fromString(text(get("/me",payer),"id")),newId=UUID.fromString(text(get("/me",successor),"id")),book=UUID.fromString(text(b,"id"));
  sql.update("insert into payment_request(id,version,book_id,user_id,amount,status) values(?,0,?,?,100,'ACTIVE')",request,book,payerId);
  sql.update("insert into payment_report(id,version,book_id,request_id,user_id,reported_amount,amount,status,evidence,reported_at,processed_by) values(?,0,?,?,?,100,100,'VERIFIED',?,now(),?)",UUID.randomUUID(),book,request,payerId,"file:"+file,oldId);
  assertEquals(200,readFile(owner,file));sql.update("update club_event set responsible_id=? where id=?",newId,UUID.fromString(eid));
  assertEquals(200,readFile(owner,file));assertEquals(200,readFile(successor,file));assertEquals(200,readFile(payer,file));assertEquals(403,readFile(unrelated,file));
 }
 @Test void originalDisputeCounterpartyKeepsOnlyTheirOwnEvidenceAfterHandover()throws Exception {
  String owner=user("caseOld"),member=user("caseAuthor"),successor=user("caseNew");var c=club(owner,"IMMEDIATE");String cid=text(c,"id");assertEquals(200,join(member,cid,version(c),null).status);
  var e=event(owner,cid,version(get("/clubs/"+cid,owner)),"LIGHTNING",false);String eid=text(e,"id");var book=post("/events/"+eid+"/finance/open",owner,Map.of("version",0,"mode","POSTPAY"));assertEquals(200,book.status);
  var proof=upload(member,"DISPUTE",null,eid,PNG,UUID.randomUUID().toString());assertEquals(200,proof.status);String original=text(proof,"id");
  var sql=context.getBean(org.springframework.jdbc.core.JdbcTemplate.class);UUID oldId=UUID.fromString(text(get("/me",owner),"id")),newId=UUID.fromString(text(get("/me",successor),"id")),memberId=UUID.fromString(text(get("/me",member),"id")),bookId=UUID.fromString(text(book,"id"));
  sql.update("insert into finance_dispute(id,version,book_id,user_id,counterparty_id,status,reason,evidence,created_at,correction_amount) values(?,0,?,?,?,'OPEN','old-case',?,now(),0)",UUID.randomUUID(),bookId,memberId,oldId,"file:"+original);
  assertEquals(200,readFile(owner,original));sql.update("update club_event set responsible_id=? where id=?",newId,UUID.fromString(eid));assertEquals(200,readFile(owner,original));
  var next=upload(member,"DISPUTE",null,eid,PNG,UUID.randomUUID().toString());assertEquals(200,next.status);String subsequent=text(next,"id");
  sql.update("insert into finance_dispute(id,version,book_id,user_id,counterparty_id,status,reason,evidence,created_at,correction_amount) values(?,0,?,?,?,'OPEN','new-case',?,now(),0)",UUID.randomUUID(),bookId,memberId,newId,"file:"+subsequent);
  assertEquals(403,readFile(owner,subsequent));assertEquals(200,readFile(successor,original));assertEquals(200,readFile(successor,subsequent));
 }
 @Test void assignedModerationKeepsExactOriginalPhotoAfterPostEdit()throws Exception {
  String owner=user("photoCaseOwner"),reporter=user("photoCaseReporter"),operator=user("photoCaseOperator"),other=user("photoCaseOther");var c=club(owner,"IMMEDIATE");String cid=text(c,"id");assertEquals(200,join(reporter,cid,version(c),null).status);
  var photo=upload(owner,"POST",cid,null,PNG,UUID.randomUUID().toString());assertEquals(200,photo.status);String fileId=text(photo,"id");var created=post("/feed/posts",owner,Map.of("clubId",cid,"body","원래 신고 대상","photoIds",List.of(fileId)));assertEquals(200,created.status);String postId=text(created,"id");
  var jdbc=context.getBean(org.springframework.jdbc.core.JdbcTemplate.class);jdbc.update("insert into platform_operator(user_id,provisioned_by) values(?,'offline-photo-test')",UUID.fromString(text(get("/me",operator),"id")));
  var report=post("/reports",reporter,Map.of("clubId",cid,"targetUserId",text(get("/me",owner),"id"),"type","CLUB_CONTENT","contentType","POST","contentId",postId,"reason","사진 원문 보존 검증"));assertEquals(200,report.status,report.body.toString());String caseId=text(report,"id");
  var claimed=post("/support/cases/"+caseId+"/claim",operator,Map.of("version",version(report)));assertEquals(200,claimed.status,claimed.body.toString());assertEquals(200,readFile(operator,fileId));
  var laterPhoto=upload(owner,"POST",cid,null,PNG,UUID.randomUUID().toString());assertEquals(200,laterPhoto.status);String laterId=text(laterPhoto,"id");
  var edited=post("/feed/posts/"+postId+"/edit",owner,Map.of("version",version(created),"body","수정된 글의 새 사진","photoIds",List.of(laterId)));assertEquals(200,edited.status,edited.body.toString());
  assertEquals(200,readFile(operator,fileId));assertEquals(403,readFile(other,fileId));assertEquals(403,readFile(operator,laterId));assertEquals(200,readFile(reporter,laterId));
  jdbc.update("delete from platform_operator where user_id=?",UUID.fromString(text(get("/me",operator),"id")));assertEquals(403,readFile(operator,fileId));
 }
}
