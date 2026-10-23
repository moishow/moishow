package com.moishow.identity;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Profile;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import java.net.URI;
import java.net.URLDecoder;
import java.net.URLEncoder;
import java.net.http.*;
import java.nio.charset.StandardCharsets;
import java.time.*;
import java.util.*;
import static com.moishow.identity.ApiProblem.require;

/** Fixed-host CODEF protocol adapter. User challenge lifetime and proof consumption belong to the service. */
@Component @Profile("db")
class CodefGateway {
 interface Transport {Reply send(HttpRequest request) throws Exception;}
 record Reply(int status,String body){}
 record Bank(String id,String name,String holderOrganization,String transferOrganization){}
 record Transfer(String code,String reference){}
 private static final Duration TIMEOUT=Duration.ofSeconds(30);
 private static final String OAUTH="https://oauth.codef.io/oauth/token";
 private static final String PRODUCT="https://api.codef.io/v1/kr/bank/a/account/";
 private static final ObjectMapper JSON=new ObjectMapper();
 private final Transport transport;
 private final List<Bank> banks;
 private final String clientId,clientSecret;
 private final boolean live;
 private String accessToken;
 private Instant tokenExpiresAt=Instant.EPOCH;

 @Autowired CodefGateway(Environment env){this(env,defaultTransport());}
 CodefGateway(Environment env,Transport transport){
  this.transport=Objects.requireNonNull(transport);
  clientId=env.getProperty("CODEF_CLIENT_ID","");clientSecret=env.getProperty("CODEF_CLIENT_SECRET","");
  String mode=env.getProperty("CODEF_MODE","DISABLED");
  List<Bank> configured=List.of();boolean valid=Set.of("DISABLED","DEMO","PRODUCTION").contains(mode);
  if(valid){try{configured=readBanks(env.getProperty("CODEF_BANKS_JSON","[]"));}catch(Exception invalid){valid=false;}}
  banks=valid?configured:List.of();
  live=valid&&mode.equals("PRODUCTION")&&!clientId.isBlank()&&!clientSecret.isBlank()&&!banks.isEmpty();
 }
 private static Transport defaultTransport(){
  var client=HttpClient.newBuilder().connectTimeout(TIMEOUT).followRedirects(HttpClient.Redirect.NEVER).build();
  return request->{var reply=client.send(request,HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));return new Reply(reply.statusCode(),reply.body());};
 }
 private static List<Bank> readBanks(String source){
  var root=JSON.readTree(source);if(root==null||!root.isArray())throw new IllegalArgumentException();
  var result=new ArrayList<Bank>();var ids=new HashSet<String>();var names=new HashSet<String>();
  for(var node:root){
   String id=configText(node,"id"),name=configText(node,"name"),holder=configText(node,"holderOrganization"),transfer=configText(node,"transferOrganization");
   if(!id.matches("[A-Za-z0-9_-]{1,100}")||name.length()>100||!holder.matches("[0-9]{1,16}")||!transfer.matches("[0-9]{1,16}")||!ids.add(id)||!names.add(name))throw new IllegalArgumentException();
   result.add(new Bank(id,name,holder,transfer));
  }
  return List.copyOf(result);
 }
 private static String configText(JsonNode node,String field){var value=node.path(field);if(!value.isTextual()||value.asText().isBlank())throw new IllegalArgumentException();return value.asText().strip();}
 boolean live(){return live;}
 List<Bank> banks(){return banks;}
 Bank bank(String id){return banks.stream().filter(bank->bank.id().equals(id)).findFirst().orElseThrow(()->new ApiProblem(400,"UNKNOWN_BANK"));}
 private void input(Bank bank,String account){require(live,503,"BANK_PROVIDER_NOT_CONFIGURED");require(bank!=null&&banks.contains(bank),400,"UNKNOWN_BANK");require(account!=null&&account.matches("[0-9]{4,34}"),400,"INVALID_ACCOUNT_NUMBER");}
 String holder(Bank bank,String account,String identity){
  input(bank,account);require(identity!=null&&identity.matches("[0-9]{6}"),400,"INVALID_BANK_IDENTITY");
  var response=product("holder-authentication",Map.of("organization",bank.holderOrganization(),"account",account,"identity",identity));
  String name=responseText(response.path("data"),"name").strip();require(name.length()<=100,503,"CODEF_INVALID_RESPONSE");return name;
 }
 Transfer transfer(Bank bank,String account){
  input(bank,account);var response=product("transfer-authentication",Map.of("organization",bank.transferOrganization(),"account",account,"inPrintType","0"));
  String code=responseText(response.path("data"),"authCode");require(code.matches("[0-9]{4}"),503,"CODEF_INVALID_RESPONSE");
  String reference=responseText(response.path("result"),"transactionId").strip();require(reference.length()<=500,503,"CODEF_INVALID_RESPONSE");return new Transfer(code,reference);
 }
 private JsonNode product(String endpoint,Map<String,String> fields){
  String encoded=URLEncoder.encode(JSON.writeValueAsString(fields),StandardCharsets.UTF_8);String usedToken=token();
  var request=HttpRequest.newBuilder(URI.create(PRODUCT+endpoint)).timeout(TIMEOUT).header("Authorization","Bearer "+usedToken).header("Accept","application/json").header("Content-Type","application/x-www-form-urlencoded").POST(HttpRequest.BodyPublishers.ofString(encoded,StandardCharsets.UTF_8)).build();
  var response=send(request);if(response.path("result").path("code").isTextual()&&response.path("result").path("code").asText().equals("CF-00401"))invalidateToken(usedToken);require(response.path("result").path("code").isTextual()&&response.path("result").path("code").asText().equals("CF-00000")&&response.path("data").isObject(),503,"CODEF_PRODUCT_FAILED");return response;
 }
 private synchronized String token(){
  Instant now=Instant.now();if(accessToken!=null&&now.isBefore(tokenExpiresAt))return accessToken;
  String basic=Base64.getEncoder().encodeToString((clientId+":"+clientSecret).getBytes(StandardCharsets.UTF_8));
  var request=HttpRequest.newBuilder(URI.create(OAUTH)).timeout(TIMEOUT).header("Authorization","Basic "+basic).header("Content-Type","application/x-www-form-urlencoded").POST(HttpRequest.BodyPublishers.ofString("grant_type=client_credentials&scope=read",StandardCharsets.UTF_8)).build();
  var response=send(request);String token=responseText(response,"access_token");var expiry=response.path("expires_in");require(expiry.isIntegralNumber()&&expiry.canConvertToLong(),503,"CODEF_INVALID_RESPONSE");long seconds=expiry.asLong();require(seconds>0&&seconds<=604800,503,"CODEF_INVALID_RESPONSE");
  require(token.chars().allMatch(c->c>=33&&c<=126),503,"CODEF_INVALID_RESPONSE");accessToken=token;tokenExpiresAt=now.plusSeconds(seconds);return accessToken;
 }
 private synchronized void invalidateToken(String expected){
  // A delayed failure for an older token cannot discard a replacement obtained by another request.
  if(Objects.equals(accessToken,expected)){accessToken=null;tokenExpiresAt=Instant.EPOCH;}
 }
 private JsonNode send(HttpRequest request){
  try{
   Reply reply=transport.send(request);
   if(reply!=null&&reply.status()==401)request.headers().firstValue("Authorization").filter(header->header.startsWith("Bearer ")).ifPresent(header->invalidateToken(header.substring(7)));
   require(reply!=null&&reply.status()==200&&reply.body()!=null,503,"CODEF_UNAVAILABLE");String body=reply.body().strip();
   // Raw JSON must retain literal '+' and '%': decode only a whole encoded JSON object, exactly once.
   if(body.regionMatches(true,0,"%7B",0,3))body=URLDecoder.decode(body,StandardCharsets.UTF_8);
   var json=JSON.readTree(body);require(json!=null&&json.isObject(),503,"CODEF_INVALID_RESPONSE");return json;
  }catch(InterruptedException interrupted){Thread.currentThread().interrupt();throw new ApiProblem(503,"CODEF_UNAVAILABLE");}
  catch(ApiProblem problem){throw problem;}
  catch(Exception failure){throw new ApiProblem(503,"CODEF_UNAVAILABLE");}
 }
 private static String responseText(JsonNode node,String field){var value=node.path(field);require(value.isTextual()&&!value.asText().isBlank(),503,"CODEF_INVALID_RESPONSE");return value.asText();}
}
