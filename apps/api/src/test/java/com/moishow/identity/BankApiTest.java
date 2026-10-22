package com.moishow.identity;

import com.moishow.MoishowServerApplication;
import org.junit.jupiter.api.*;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.web.server.context.WebServerApplicationContext;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.context.annotation.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.testcontainers.postgresql.PostgreSQLContainer;
import tools.jackson.databind.*;
import java.net.*;import java.net.http.*;import java.time.*;import java.util.*;
import static org.junit.jupiter.api.Assertions.*;

class BankApiTest {
 static PostgreSQLContainer postgres=new PostgreSQLContainer("postgres:17-alpine");
 static ConfigurableApplicationContext context;static JdbcTemplate sql;static String base;
 static ObjectMapper json=new ObjectMapper();static HttpClient http=HttpClient.newHttpClient();
 record User(UUID id,String token){}record Reply(int status,JsonNode body){}
 @Configuration @Profile("bank-test") static class Providers {
  @Bean @Primary BankOwnershipVerifier testBank(){return (user,bank,number,holder)->{
   if(number.equals("9999999999"))throw new ApiProblem(400,"BANK_OWNERSHIP_REJECTED");
   return "test-only-owner-verification-"+UUID.randomUUID();
  };}
 }
 @BeforeAll static void start(){postgres.start();context=new SpringApplicationBuilder(MoishowServerApplication.class,Providers.class).profiles("db","bank-test").run("--server.port=0","--BANK_DATA_KEY_BASE64=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=","--logging.level.root=ERROR","--spring.main.banner-mode=off","--spring.datasource.url="+postgres.getJdbcUrl(),"--spring.datasource.username="+postgres.getUsername(),"--spring.datasource.password="+postgres.getPassword());sql=context.getBean(JdbcTemplate.class);base="http://127.0.0.1:"+((WebServerApplicationContext)context).getWebServer().getPort()+"/api/v1";}
 @AfterAll static void stop(){if(context!=null)context.close();postgres.stop();}
 static User user(){UUID id=UUID.randomUUID();String token=UUID.randomUUID().toString();sql.update("insert into app_user(id,provider,subject,phone,nickname,status) values(?,'GOOGLE',?,?,?,'ACTIVE')",id,id.toString(),"+8210"+String.format("%08d",Math.floorMod(id.hashCode(),100000000)),"닉네임");sql.update("insert into service_session(token_hash,user_id,scope,expires_at,revoked) values(?,?,'ACTIVE',now()+interval '1 day',false)",Crypto.hash(token),id);return new User(id,token);}
 static Reply call(String method,String path,User actor,Object body,String key)throws Exception{
  var request=HttpRequest.newBuilder(URI.create(base+path)).timeout(Duration.ofSeconds(20)).header("Authorization","Bearer "+actor.token).header("Content-Type","application/json");
  if(key!=null)request.header("Idempotency-Key",key);
  request.method(method,body==null?HttpRequest.BodyPublishers.noBody():HttpRequest.BodyPublishers.ofString(json.writeValueAsString(body)));
  var response=http.send(request.build(),HttpResponse.BodyHandlers.ofString());return new Reply(response.statusCode(),response.body().isBlank()?json.createObjectNode():json.readTree(response.body()));
 }
 static Map<String,Object> form(long version,String number){return Map.of("version",version,"bankName","테스트은행","accountNumber",number,"holderName","김예금");}
 @Test void transferInstructionsAreLimitedToExactCurrentSenderAndOpenObligation()throws Exception{
  var host=user();var payer=user();var other=user();var successor=user();
  for(var person:List.of(host,payer,other,successor))assertEquals(200,call("POST","/me/bank-account",person,form(0,person==host?"1111222233":person==payer?"2222333344":person==other?"4444555566":"3333444455"),UUID.randomUUID().toString()).status);
  UUID club=UUID.randomUUID(),event=UUID.randomUUID(),book=UUID.randomUUID(),round=UUID.randomUUID(),request=UUID.randomUUID(),refund=UUID.randomUUID();
  sql.update("insert into club values(?,0,'은행 테스트','IMMEDIATE','ACTIVE',?)",club,host.id);
  for(var person:List.of(host,payer,other))sql.update("insert into membership values(?,0,?,?,'닉네임',?,'ACTIVE',false,false)",UUID.randomUUID(),club,person.id,person==host?"OWNER":"MEMBER");
  assertEquals("ACTIVE",call("GET","/clubs/"+club,host,null,null).body.path("status").asText());
  sql.update("insert into club_event(id,version,club_id,host_id,responsible_id,title,kind,public_event,starts_at,ends_at,settlement_mode) values(?,0,?,?,?,'계좌 안내','LIGHTNING',true,now(),now()+interval '1 hour','PREPAY')",event,club,host.id,host.id);
  sql.update("insert into event_round(id,version,event_id,capacity,closes_at,cancellation_fee) values(?,0,?,10,now(),0)",round,event);
  sql.update("insert into settlement_book(id,version,event_id,status,mode) values(?,0,?,'OPEN','PREPAY')",book,event);
  sql.update("insert into participation(id,version,round_id,user_id,status,ever_confirmed,agreed_fee) values(?,0,?,?,'CONFIRMED',true,0)",UUID.randomUUID(),round,payer.id);
  sql.update("insert into payment_request(id,version,book_id,round_id,user_id,amount,status) values(?,0,?,?,?,100,'ACTIVE')",request,book,round,payer.id);
  sql.update("insert into participation(id,version,round_id,user_id,status,ever_confirmed,agreed_fee) values(?,0,?,?,'CANCELLED',true,0)",UUID.randomUUID(),round,other.id);
  UUID oldRequest=UUID.randomUUID(),receipt=UUID.randomUUID();
  sql.update("insert into payment_request(id,version,book_id,round_id,user_id,amount,status) values(?,0,?,?,?,25,'ACTIVE')",oldRequest,book,round,other.id);
  sql.update("insert into payment_report(id,version,book_id,request_id,user_id,reported_amount,amount,status,reported_at,processed_by) values(?,0,?,?,?,25,25,'VERIFIED',now(),?)",receipt,book,oldRequest,other.id,host.id);
  sql.update("insert into receipt_allocation(id,version,book_id,report_id,round_id,kind,amount) values(?,0,?,?,?,'ATTENDANCE',25)",UUID.randomUUID(),book,receipt,round);
  sql.update("insert into finance_refund(id,version,book_id,user_id,amount,sent_amount,status,requested_at,requested_by) values(?,0,?,?,25,0,'REQUESTED',now(),?)",refund,book,other.id,host.id);
  String payPath="/events/"+event+"/finance/requests/"+request+"/transfer-instructions",refundPath="/events/"+event+"/finance/refunds/"+refund+"/transfer-instructions";
  var pay=call("GET",payPath,payer,null,null);assertEquals(200,pay.status,pay.body.toString());assertEquals("1111222233",pay.body.path("accountNumber").asText());assertEquals("김예금",pay.body.path("holderName").asText());assertEquals(100,pay.body.path("amount").asLong());assertEquals(403,call("GET",payPath,other,null,null).status);
  var giveBack=call("GET",refundPath,host,null,null);assertEquals(200,giveBack.status,giveBack.body.toString());assertEquals("4444555566",giveBack.body.path("accountNumber").asText());assertEquals(403,call("GET",refundPath,other,null,null).status);
  sql.update("update membership set status='LEFT' where club_id=? and user_id=?",club,payer.id);assertEquals(200,call("GET",payPath,payer,null,null).status);
  sql.update("update club_event set responsible_id=? where id=?",successor.id,event);
  assertEquals("3333444455",call("GET",payPath,payer,null,null).body.path("accountNumber").asText());assertEquals(403,call("GET",refundPath,host,null,null).status);assertEquals(200,call("GET",refundPath,successor,null,null).status);
  sql.update("update payment_request set status='SUPERSEDED' where id=?",request);sql.update("update finance_refund set status='SENT' where id=?",refund);
  assertEquals(409,call("GET",payPath,payer,null,null).status);assertEquals(409,call("GET",refundPath,successor,null,null).status);
  sql.update("update club set status='DISSOLVED' where id=?",club);var dissolved=call("GET","/clubs/"+club,host,null,null);assertEquals("DISSOLVED",dissolved.body.path("status").asText());assertEquals("OWNER",dissolved.body.path("role").asText());
 }
 @Test void verifiedPersonalAccountIsMaskedEncryptedVersionedAndIdempotent()throws Exception{
  var owner=user();var outsider=user();var empty=call("GET","/me/bank-account",owner,null,null);assertEquals(200,empty.status);assertFalse(empty.body.path("registered").asBoolean(true));
  String key=UUID.randomUUID().toString();var body=form(0,"1234567890");var saved=call("POST","/me/bank-account",owner,body,key);assertEquals(200,saved.status,saved.body.toString());assertTrue(saved.body.path("registered").asBoolean());assertFalse(saved.body.toString().contains("1234567890"));assertFalse(saved.body.toString().contains("김예금"));assertTrue(saved.body.path("accountMasked").asText().contains("7890"));
  assertEquals(saved.body,call("POST","/me/bank-account",owner,body,key).body);
  assertEquals(409,call("POST","/me/bank-account",owner,form(0,"1234567800"),key).status);
  var stored=sql.queryForMap("select * from personal_bank_account where user_id=? and current",owner.id);assertFalse(stored.toString().contains("1234567890"));assertFalse(stored.toString().contains("김예금"));
  assertFalse(call("GET","/me/bank-account",outsider,null,null).body.path("registered").asBoolean(true));
  assertEquals(409,call("POST","/me/bank-account",owner,form(0,"1234567800"),UUID.randomUUID().toString()).status);
  long v=saved.body.path("version").asLong();assertEquals(400,call("POST","/me/bank-account",owner,form(v,"9999999999"),UUID.randomUUID().toString()).status);
  assertEquals(saved.body,call("GET","/me/bank-account",owner,null,null).body);
  var changed=call("POST","/me/bank-account",owner,form(v,"1234567800"),UUID.randomUUID().toString());assertEquals(200,changed.status,changed.body.toString());assertEquals(v+1,changed.body.path("version").asLong());assertEquals(2,sql.queryForObject("select count(*) from personal_bank_account where user_id=?",Integer.class,owner.id));assertEquals(1,sql.queryForObject("select count(*) from personal_bank_account where user_id=? and current",Integer.class,owner.id));
 }
}
