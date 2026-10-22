package com.moishow.identity;
import org.springframework.context.annotation.Profile;import org.springframework.stereotype.Service;import org.springframework.core.env.Environment;import org.springframework.transaction.annotation.Transactional;
import java.net.*;import java.nio.charset.StandardCharsets;import java.security.*;import java.time.*;import java.util.*;
import com.nimbusds.jwt.JWTParser;
import static com.moishow.identity.ApiProblem.require;
@Service @Profile("db")
class AppleMobileAuthService {
 final Store db;final SocialVerifier verifier;final AuthService auth;final Environment env;
 AppleMobileAuthService(Store db,SocialVerifier verifier,AuthService auth,Environment env){this.db=db;this.verifier=verifier;this.auth=auth;this.env=env;}
 record Settings(String clientId,String callback){}
 Settings settings(){String id=env.getProperty("APPLE_MOBILE_SERVICE_ID",""),callback=env.getProperty("APPLE_MOBILE_CALLBACK_URL","");
  require(!id.isBlank()&&!callback.isBlank(),503,"APPLE_MOBILE_NOT_CONFIGURED");
  URI uri;try{uri=URI.create(callback);}catch(IllegalArgumentException e){throw new ApiProblem(503,"APPLE_MOBILE_NOT_CONFIGURED");}
  require("https".equals(uri.getScheme())&&uri.getHost()!=null&&uri.getRawUserInfo()==null&&uri.getRawQuery()==null&&uri.getRawFragment()==null&&"/api/v1/auth/apple/mobile/callback".equals(uri.getPath()),503,"APPLE_MOBILE_NOT_CONFIGURED");
  var clients=new HashSet<String>();for(String client:env.getProperty("AUTH_APPLE_CLIENT_IDS",env.getProperty("AUTH_APPLE_CLIENT_ID","")).split(",")){clients.add(client.trim());}
  require(clients.contains(id),503,"APPLE_MOBILE_AUDIENCE_NOT_CONFIGURED");return new Settings(id,callback);
 }
 static String enc(String text){return URLEncoder.encode(text,StandardCharsets.UTF_8);}
 static String s256(String text){try{return Base64.getUrlEncoder().withoutPadding().encodeToString(MessageDigest.getInstance("SHA-256").digest(text.getBytes(StandardCharsets.US_ASCII)));}catch(NoSuchAlgorithmException e){throw new IllegalStateException(e);}}
 @Transactional public Map<String,Object> start(String challenge){var config=settings();require(challenge!=null&&challenge.matches("[A-Za-z0-9_-]{43}"),400,"INVALID_PKCE_CHALLENGE");String state=Crypto.token();var a=new AppleMobileAuthModels.Attempt();a.stateHash=Crypto.hash(state);a.nonce=Crypto.token();a.pkceChallenge=challenge;a.expiresAt=Instant.now().plusSeconds(300);db.save(a);
  String url="https://appleid.apple.com/auth/authorize?client_id="+enc(config.clientId())+"&redirect_uri="+enc(config.callback())+"&response_type=code%20id_token&response_mode=form_post&scope=email&state="+enc(state)+"&nonce="+enc(a.nonce);
  return Map.of("authorizeUrl",url,"state",state,"expiresAt",a.expiresAt);
 }
 @Transactional public String callback(String state,String token){var config=settings();require(state!=null&&state.length()<=128&&token!=null&&token.length()<=16384,401,"INVALID_APPLE_CALLBACK");var found=db.one(AppleMobileAuthModels.Attempt.class,"from AppleMobileAuthAttempt where stateHash=?1",Crypto.hash(state));require(found!=null,401,"INVALID_APPLE_STATE");var a=db.lock(AppleMobileAuthModels.Attempt.class,found.id);require(!a.callbackConsumed&&a.expiresAt.isAfter(Instant.now()),401,"INVALID_APPLE_STATE");
  var identity=verifier.verify("APPLE",token,a.nonce);require(identity!=null&&identity.provider().equals("APPLE")&&identity.subject()!=null&&!identity.subject().isBlank()&&identity.subject().length()<=255,401,"INVALID_SOCIAL_IDENTITY");
  // The exact same token has already passed the trusted signature/issuer/nonce
  // verifier. Constrain its audience additionally to this web Services ID.
  try{var claims=JWTParser.parse(token).getJWTClaimsSet();require(claims.getAudience().contains(config.clientId())&&"https://appleid.apple.com".equals(claims.getIssuer())&&a.nonce.equals(claims.getStringClaim("nonce"))&&claims.getExpirationTime()!=null&&claims.getExpirationTime().toInstant().isAfter(Instant.now()),401,"INVALID_SOCIAL_TOKEN");}catch(java.text.ParseException e){throw new ApiProblem(401,"INVALID_SOCIAL_TOKEN");}
  String ticket=Crypto.token();a.callbackConsumed=true;a.identitySubject=identity.subject();a.ticketHash=Crypto.hash(ticket);a.ticketExpiresAt=Instant.now().plusSeconds(120);a.version++;
  return "moishow://apple/callback?ticket="+enc(ticket)+"&state="+enc(state);
 }
 @Transactional public Map<String,Object> exchange(String ticket,String codeVerifier){settings();require(ticket!=null&&ticket.length()<=128&&codeVerifier!=null&&codeVerifier.matches("[A-Za-z0-9._~-]{43,128}"),401,"INVALID_APPLE_TICKET");var found=db.one(AppleMobileAuthModels.Attempt.class,"from AppleMobileAuthAttempt where ticketHash=?1",Crypto.hash(ticket));require(found!=null,401,"INVALID_APPLE_TICKET");var a=db.lock(AppleMobileAuthModels.Attempt.class,found.id);require(a.callbackConsumed&&!a.exchanged&&a.ticketExpiresAt!=null&&a.ticketExpiresAt.isAfter(Instant.now())&&MessageDigest.isEqual(a.pkceChallenge.getBytes(StandardCharsets.US_ASCII),s256(codeVerifier).getBytes(StandardCharsets.US_ASCII)),401,"INVALID_APPLE_TICKET");a.exchanged=true;a.version++;return auth.issueVerifiedApple(new SocialVerifier.Identity("APPLE",a.identitySubject));}
}
