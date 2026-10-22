package com.moishow.identity;

import org.springframework.context.annotation.*;
import org.springframework.core.env.Environment;
import org.springframework.security.oauth2.jwt.*;
import java.net.*;import java.net.http.*;
import java.time.*;import java.util.*;import java.util.concurrent.ConcurrentHashMap;
import javax.crypto.Mac;import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import tools.jackson.databind.*;
import static com.moishow.identity.ApiProblem.require;

@Configuration @Profile("db")
class ProviderConfiguration {
 private final HttpClient http=HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();
 private final ObjectMapper json=new ObjectMapper();
 private final Map<String,JwtDecoder> decoders=new ConcurrentHashMap<>();
 @Bean SocialVerifier providerVerifier(Environment env){return (provider,token,nonce)->{
  String config=provider.equals("KAKAO")?"AUTH_KAKAO_APP_ID":provider.equals("GOOGLE")?"AUTH_GOOGLE_CLIENT_ID":"AUTH_APPLE_CLIENT_ID";
  String client=env.getProperty(config,"");require(!client.isBlank(),503,"SOCIAL_PROVIDER_NOT_CONFIGURED");
  if(provider.equals("KAKAO")){
   var info=request("GET","https://kapi.kakao.com/v1/user/access_token_info","Bearer "+token,null);
   require(client.equals(info.path("app_id").asText())&&info.path("expires_in").asLong()>0&&info.path("id").asLong()>0,401,"INVALID_SOCIAL_TOKEN");
   return new SocialVerifier.Identity(provider,info.path("id").asText());
  }
  Jwt jwt;
  try{
   var decoder=decoders.computeIfAbsent(provider,key->{
    String url=key.equals("GOOGLE")?"https://www.googleapis.com/oauth2/v3/certs":"https://appleid.apple.com/auth/keys";
    var d=NimbusJwtDecoder.withJwkSetUri(url).build();
    d.setJwtValidator(JwtValidators.createDefaultWithIssuer(key.equals("GOOGLE")?"https://accounts.google.com":"https://appleid.apple.com"));return d;
   });jwt=decoder.decode(token);
  }catch(JwtException e){throw new ApiProblem(401,"INVALID_SOCIAL_TOKEN");}
  require(jwt.getAudience().contains(client)&&jwt.getExpiresAt()!=null&&jwt.getExpiresAt().isAfter(Instant.now())&&nonce!=null&&nonce.equals(jwt.getClaimAsString("nonce")),401,"INVALID_SOCIAL_TOKEN");
  return new SocialVerifier.Identity(provider,jwt.getSubject());
 };}
 @Bean SmsGateway smsGateway(Environment env){return (phone,code)->{
  String key=env.getProperty("SOLAPI_API_KEY",""),secret=env.getProperty("SOLAPI_API_SECRET",""),from=env.getProperty("SOLAPI_FROM","");
  require(!key.isBlank()&&!secret.isBlank()&&!from.isBlank(),503,"SMS_PROVIDER_NOT_CONFIGURED");
  require(phone.matches("\\+8210[0-9]{8}"),400,"UNSUPPORTED_PHONE_COUNTRY");
  String date=Instant.now().toString(),salt=Crypto.token();String signature;
  try{var mac=Mac.getInstance("HmacSHA256");mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8),"HmacSHA256"));signature=HexFormat.of().formatHex(mac.doFinal((date+salt).getBytes(StandardCharsets.UTF_8)));}catch(java.security.GeneralSecurityException e){throw new IllegalStateException(e);}
  String authorization="HMAC-SHA256 apiKey="+key+", date="+date+", salt="+salt+", signature="+signature;
  var response=request("POST","https://api.solapi.com/messages/v4/send-many/detail",authorization,Map.of("messages",List.of(Map.of("to","0"+phone.substring(3),"from",from,"text","모이쇼 인증번호 ["+code+"] (5분 이내 입력)"))));
  require(response.has("groupInfo")&&response.path("failedMessageList").size()==0,503,"SMS_DELIVERY_REJECTED");
 };}
 private JsonNode request(String method,String url,String authorization,Object body){
  try{
   var b=HttpRequest.newBuilder(URI.create(url)).timeout(Duration.ofSeconds(10)).header("Authorization",authorization).header("Content-Type","application/json");
   b.method(method,body==null?HttpRequest.BodyPublishers.noBody():HttpRequest.BodyPublishers.ofString(json.writeValueAsString(body)));
   var response=http.send(b.build(),HttpResponse.BodyHandlers.ofString());
   if(response.statusCode()==401||response.statusCode()==403)throw new ApiProblem(method.equals("GET")?401:503,"PROVIDER_REJECTED");
   require(response.statusCode()>=200&&response.statusCode()<300,503,"PROVIDER_UNAVAILABLE");return json.readTree(response.body());
  }catch(InterruptedException e){Thread.currentThread().interrupt();throw new ApiProblem(503,"PROVIDER_UNAVAILABLE");}
  catch(java.io.IOException e){throw new ApiProblem(503,"PROVIDER_UNAVAILABLE");}
 }
}
