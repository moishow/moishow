package com.moishow.identity;

import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;
import tools.jackson.databind.ObjectMapper;
import java.net.*;
import java.net.http.HttpRequest;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.Flow;
import static org.junit.jupiter.api.Assertions.*;

class CodefGatewayTest {
 static final ObjectMapper JSON=new ObjectMapper();
 // Intentionally fictional institution codes: protocol fixtures are not a production bank registry.
 static final CodefGateway.Bank BANK=new CodefGateway.Bank("fixture-bank","테스트은행","9001","901");
 static final String BANKS="[{\"id\":\"fixture-bank\",\"name\":\"테스트은행\",\"holderOrganization\":\"9001\",\"transferOrganization\":\"901\"}]";
 static MockEnvironment environment(){return new MockEnvironment().withProperty("CODEF_MODE","PRODUCTION").withProperty("CODEF_CLIENT_ID","fixture-client").withProperty("CODEF_CLIENT_SECRET","fixture-secret").withProperty("CODEF_BANKS_JSON",BANKS);}
 static String encoded(String text){return URLEncoder.encode(text,StandardCharsets.UTF_8);}
 static String result(String data){return "{\"result\":{\"code\":\"CF-00000\",\"transactionId\":\"fixture-reference\"},\"data\":"+data+"}";}
 static final class Wire implements CodefGateway.Transport {
  final List<HttpRequest> requests=new ArrayList<>();final Deque<CodefGateway.Reply> replies=new ArrayDeque<>();
  Wire(String...products){replies.add(new CodefGateway.Reply(200,"{\"access_token\":\"fixture-token\",\"expires_in\":3600}"));for(String product:products)replies.add(new CodefGateway.Reply(200,product));}
  public CodefGateway.Reply send(HttpRequest request){requests.add(request);return replies.removeFirst();}
 }
 static String body(HttpRequest request)throws Exception {
  var output=new java.io.ByteArrayOutputStream();var done=new CompletableFuture<String>();
  request.bodyPublisher().orElseThrow().subscribe(new Flow.Subscriber<ByteBuffer>(){
   public void onSubscribe(Flow.Subscription subscription){subscription.request(Long.MAX_VALUE);}
   public void onNext(ByteBuffer bytes){byte[] part=new byte[bytes.remaining()];bytes.get(part);output.writeBytes(part);}
   public void onError(Throwable error){done.completeExceptionally(error);}
   public void onComplete(){done.complete(output.toString(StandardCharsets.UTF_8));}
  });return done.get(2,TimeUnit.SECONDS);
 }
 @Test void oauthAndProductWireEncodeOncePreserveOrganizationAndReuseToken()throws Exception {
  var wire=new Wire(encoded(result("{\"name\":\"홍길동\"}")),encoded(result("{\"authCode\":\"0042\"}")));
  var gateway=new CodefGateway(environment(),wire);assertTrue(gateway.live());assertEquals(BANK,gateway.bank("fixture-bank"));assertEquals(List.of(BANK),gateway.banks());
  assertEquals("홍길동",gateway.holder(BANK,"1234567890","900101"));var transfer=gateway.transfer(BANK,"1234567890");assertEquals("0042",transfer.code());assertEquals("fixture-reference",transfer.reference());
  assertEquals(3,wire.requests.size());var token=wire.requests.get(0);assertEquals("https://oauth.codef.io/oauth/token",token.uri().toString());assertEquals("POST",token.method());assertEquals("Basic "+Base64.getEncoder().encodeToString("fixture-client:fixture-secret".getBytes(StandardCharsets.UTF_8)),token.headers().firstValue("Authorization").orElseThrow());assertEquals("application/x-www-form-urlencoded",token.headers().firstValue("Content-Type").orElseThrow());assertEquals("grant_type=client_credentials&scope=read",body(token));
  var holder=wire.requests.get(1);assertEquals("https://api.codef.io/v1/kr/bank/a/account/holder-authentication",holder.uri().toString());assertEquals("Bearer fixture-token",holder.headers().firstValue("Authorization").orElseThrow());assertTrue(body(holder).startsWith("%7B"));var holderJson=JSON.readTree(URLDecoder.decode(body(holder),StandardCharsets.UTF_8));assertEquals("9001",holderJson.path("organization").asText());assertEquals("900101",holderJson.path("identity").asText());assertEquals("1234567890",holderJson.path("account").asText());
  var sent=wire.requests.get(2);assertEquals("https://api.codef.io/v1/kr/bank/a/account/transfer-authentication",sent.uri().toString());var transferJson=JSON.readTree(URLDecoder.decode(body(sent),StandardCharsets.UTF_8));assertEquals("901",transferJson.path("organization").asText());assertEquals("0",transferJson.path("inPrintType").asText());assertFalse(transferJson.has("identity"));assertFalse(transferJson.has("holderName"));
  for(var request:wire.requests)assertEquals(Duration.ofSeconds(30),request.timeout().orElseThrow());
 }
 @Test void rawJsonPlusAndEncodedPercentAreNotDecodedTwice(){
  var wire=new Wire(result("{\"name\":\"홍+길동\"}"),encoded(result("{\"name\":\"홍%2B길동\"}")));
  var gateway=new CodefGateway(environment(),wire);assertEquals("홍+길동",gateway.holder(BANK,"1234567890","900101"));assertEquals("홍%2B길동",gateway.holder(BANK,"1234567890","900101"));
 }
 @Test void http200ProviderErrorsMissingOrNonTextNamesFailClosedWithoutLeakingProviderBody(){
  for(String response:List.of("{\"result\":{\"code\":\"CF-12345\",\"message\":\"sensitive-provider-body\"},\"data\":{\"name\":\"홍길동\"}}",result("{}"),result("{\"name\":\"  \"}"),result("{\"name\":123}"),result("{\"name\":\""+"가".repeat(101)+"\"}"),"not-json")){
   var wire=new Wire(response);var error=assertThrows(ApiProblem.class,()->new CodefGateway(environment(),wire).holder(BANK,"1234567890","900101"));assertEquals(503,error.status);assertFalse(error.getMessage().contains("sensitive-provider-body"));assertEquals(2,wire.requests.size());
  }
 }
 @Test void missingOrMalformedTransferCodeAndMissingReferenceFailClosed(){
  for(String response:List.of(result("{}"),result("{\"authCode\":1234}"),result("{\"authCode\":\"123\"}"),result("{\"authCode\":\"ABCD\"}"),"{\"result\":{\"code\":\"CF-00000\"},\"data\":{\"authCode\":\"1234\"}}","{\"result\":{\"code\":\"CF-00000\",\"transactionId\":\""+"x".repeat(501)+"\"},\"data\":{\"authCode\":\"1234\"}}"))assertThrows(ApiProblem.class,()->new CodefGateway(environment(),new Wire(response)).transfer(BANK,"1234567890"));
 }
 @Test void oauthExpiresInAndTokenShapeAreValidatedBeforeSendingProduct(){
  for(String response:List.of("{}","{\"access_token\":\"fixture-token\",\"expires_in\":0}","{\"access_token\":\"fixture-token\",\"expires_in\":604801}","{\"access_token\":\"fixture-token\",\"expires_in\":1.5}","{\"access_token\":123,\"expires_in\":3600}")){
   var wire=new Wire();wire.replies.clear();wire.replies.add(new CodefGateway.Reply(200,response));assertThrows(ApiProblem.class,()->new CodefGateway(environment(),wire).holder(BANK,"1234567890","900101"));assertEquals(1,wire.requests.size());
  }
 }
 @Test void httpOrTransportFailureNeverRetriesOrRedirects(){
  for(int status:List.of(302,401,429,500)){
   var wire=new Wire();wire.replies.add(new CodefGateway.Reply(status,"sensitive-provider-body"));var error=assertThrows(ApiProblem.class,()->new CodefGateway(environment(),wire).transfer(BANK,"1234567890"));assertEquals(503,error.status);assertEquals(2,wire.requests.size());
  }
  var calls=new java.util.concurrent.atomic.AtomicInteger();CodefGateway.Transport failed=request->{calls.incrementAndGet();throw new java.net.http.HttpTimeoutException("sensitive-provider-body");};assertThrows(ApiProblem.class,()->new CodefGateway(environment(),failed).holder(BANK,"1234567890","900101"));assertEquals(1,calls.get());
  var wire=new Wire();var callsAfterToken=new java.util.concurrent.atomic.AtomicInteger();CodefGateway.Transport transferTimeout=request->{callsAfterToken.incrementAndGet();if(request.uri().getHost().equals("oauth.codef.io"))return wire.replies.removeFirst();throw new java.io.IOException("ambiguous-transfer");};assertThrows(ApiProblem.class,()->new CodefGateway(environment(),transferTimeout).transfer(BANK,"1234567890"));assertEquals(2,callsAfterToken.get());
 }
 @Test void disabledDemoMissingKeysOrEmptyRegistryAreNotLiveAndNeverSend(){
  for(var env:List.of(new MockEnvironment(),environment().withProperty("CODEF_MODE","DISABLED"),environment().withProperty("CODEF_MODE","DEMO"),environment().withProperty("CODEF_CLIENT_SECRET",""),environment().withProperty("CODEF_BANKS_JSON","[]"))){
   var wire=new Wire();var gateway=new CodefGateway(env,wire);assertFalse(gateway.live());assertThrows(ApiProblem.class,()->gateway.holder(BANK,"1234567890","900101"));assertEquals(0,wire.requests.size());
  }
 }
 @Test void malformedConfigurationCannotInventBanksOrSend(){
  for(var env:List.of(environment().withProperty("CODEF_MODE","UNKNOWN"),environment().withProperty("CODEF_BANKS_JSON","{}"),environment().withProperty("CODEF_BANKS_JSON","[null]"),environment().withProperty("CODEF_BANKS_JSON",BANKS.replace("9001","not-a-code")),environment().withProperty("CODEF_BANKS_JSON",BANKS.replace("901","")),environment().withProperty("CODEF_BANKS_JSON","["+BANKS.substring(1,BANKS.length()-1)+","+BANKS.substring(1,BANKS.length()-1)+"]"))){
   var wire=new Wire();var gateway=new CodefGateway(env,wire);assertFalse(gateway.live());assertTrue(gateway.banks().isEmpty());assertThrows(ApiProblem.class,()->gateway.holder(BANK,"1234567890","900101"));assertEquals(0,wire.requests.size());
  }
 }
 @Test void unregisteredOrForgedBanksAndInvalidInputsCannotReachTransport(){
  var wire=new Wire();var gateway=new CodefGateway(environment(),wire);assertThrows(ApiProblem.class,()->gateway.bank("unknown"));assertThrows(ApiProblem.class,()->gateway.holder(new CodefGateway.Bank("fixture-bank","테스트은행","0004","004"),"1234567890","900101"));assertThrows(ApiProblem.class,()->gateway.holder(BANK,"123-not-account","900101"));assertThrows(ApiProblem.class,()->gateway.holder(BANK,"1234567890","9001017"));assertEquals(0,wire.requests.size());
 }
 @Test void encodedOauthResponseWorksAndExpiredTokenIsNotReused()throws Exception {
  var wire=new Wire();wire.replies.clear();wire.replies.add(new CodefGateway.Reply(200,encoded("{\"access_token\":\"first-token\",\"expires_in\":1}")));wire.replies.add(new CodefGateway.Reply(200,result("{\"name\":\"홍길동\"}")));wire.replies.add(new CodefGateway.Reply(200,"{\"access_token\":\"second-token\",\"expires_in\":3600}"));wire.replies.add(new CodefGateway.Reply(200,result("{\"name\":\"홍길동\"}")));
  var gateway=new CodefGateway(environment(),wire);assertEquals("홍길동",gateway.holder(BANK,"1234567890","900101"));Thread.sleep(1100);assertEquals("홍길동",gateway.holder(BANK,"1234567890","900101"));assertEquals(4,wire.requests.size());assertEquals("Bearer second-token",wire.requests.get(3).headers().firstValue("Authorization").orElseThrow());
 }

 private void explicitRequestAfterRevocationRefreshes(CodefGateway.Reply revoked){
  var wire=new Wire();wire.replies.clear();
  wire.replies.add(new CodefGateway.Reply(200,"{\"access_token\":\"revoked-A\",\"expires_in\":3600}"));wire.replies.add(revoked);
  wire.replies.add(new CodefGateway.Reply(200,"{\"access_token\":\"replacement-B\",\"expires_in\":3600}"));wire.replies.add(new CodefGateway.Reply(200,result("{\"name\":\"홍길동\"}")));
  var gateway=new CodefGateway(environment(),wire);assertThrows(ApiProblem.class,()->gateway.holder(BANK,"1234567890","900101"));assertEquals(2,wire.requests.size(),"Failed call must not automatically request another token or replay the product");
  assertEquals("홍길동",assertDoesNotThrow(()->gateway.holder(BANK,"1234567890","900101"),"The next explicit request must refresh the revoked token"));assertEquals(4,wire.requests.size());assertEquals("Bearer replacement-B",wire.requests.get(3).headers().firstValue("Authorization").orElseThrow());
 }
 @Test void http401InvalidatesCachedTokenForNextExplicitRequestOnly(){explicitRequestAfterRevocationRefreshes(new CodefGateway.Reply(401,"provider-error"));}
 @Test void cf00401InvalidatesCachedTokenForNextExplicitRequestOnly(){explicitRequestAfterRevocationRefreshes(new CodefGateway.Reply(200,"{\"result\":{\"code\":\"CF-00401\"},\"data\":{}}"));}
 @Test void delayedOldTokenFailureCannotClearNewlyCachedToken()throws Exception {
  var heldA=new CountDownLatch(1);var releaseA=new CountDownLatch(1);var tokenCalls=new java.util.concurrent.atomic.AtomicInteger();var requests=new CopyOnWriteArrayList<HttpRequest>();
  CodefGateway.Transport transport=request->{requests.add(request);if(request.uri().getHost().equals("oauth.codef.io")){int version=tokenCalls.incrementAndGet();return new CodefGateway.Reply(200,"{\"access_token\":\"token-"+version+"\",\"expires_in\":3600}");}
   var data=JSON.readTree(URLDecoder.decode(body(request),StandardCharsets.UTF_8));String account=data.path("account").asText();
   if(account.equals("1111")){heldA.countDown();if(!releaseA.await(5,TimeUnit.SECONDS))throw new java.io.IOException("test barrier timed out");return new CodefGateway.Reply(401,"old-token-revoked");}
   if(account.equals("2222"))return new CodefGateway.Reply(401,"token-revoked");return new CodefGateway.Reply(200,result("{\"name\":\"홍길동\"}"));
  };
  var gateway=new CodefGateway(environment(),transport);assertEquals("홍길동",gateway.holder(BANK,"0000","900101"));
  try(var executor=Executors.newVirtualThreadPerTaskExecutor()){
   var old=executor.submit(()->assertThrows(ApiProblem.class,()->gateway.holder(BANK,"1111","900101")));
   try{assertTrue(heldA.await(5,TimeUnit.SECONDS));assertThrows(ApiProblem.class,()->gateway.holder(BANK,"2222","900101"));assertEquals("홍길동",gateway.holder(BANK,"3333","900101"));assertEquals(2,tokenCalls.get(),"A replacement token must have been cached before the old request finishes");}
   finally{releaseA.countDown();}
   assertEquals(503,old.get(5,TimeUnit.SECONDS).status);assertEquals("홍길동",gateway.holder(BANK,"4444","900101"));assertEquals(2,tokenCalls.get(),"An old-token failure must not invalidate its replacement");assertEquals("Bearer token-2",requests.getLast().headers().firstValue("Authorization").orElseThrow());
  }
 }
}
