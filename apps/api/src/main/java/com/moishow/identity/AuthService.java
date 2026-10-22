package com.moishow.identity;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.jdbc.core.JdbcTemplate;
import java.sql.PreparedStatement;
import java.time.*;
import java.util.*;
import static com.moishow.identity.Models.*;
import static com.moishow.identity.ApiProblem.require;

@Service @Profile("db")
public class AuthService {
 private final Store db;private final SocialVerifier social;private final SmsGateway sms;private final JdbcTemplate jdbc;
 private final BCryptPasswordEncoder bcrypt=new BCryptPasswordEncoder();
 AuthService(Store db,SocialVerifier social,SmsGateway sms,JdbcTemplate jdbc){this.db=db;this.social=social;this.sms=sms;this.jdbc=jdbc;}
 @Transactional public Map<String,Object> challenge(){var n=new LoginNonce();n.nonce=Crypto.token();n.expiresAt=Instant.now().plusSeconds(300);db.save(n);return Map.of("challengeId",n.id,"nonce",n.nonce);}
 @Transactional public Map<String,Object> login(String provider,String token,UUID challengeId){
  require(provider!=null&&Set.of("GOOGLE","APPLE","KAKAO").contains(provider),400,"INVALID_PROVIDER");
  require(token!=null&&!token.isBlank()&&token.length()<=16384,400,"INVALID_TOKEN");
  String nonce=null;
  if(!provider.equals("KAKAO")){
   require(challengeId!=null,400,"CHALLENGE_REQUIRED");var n=db.lock(LoginNonce.class,challengeId);
   require(!n.consumed&&n.expiresAt.isAfter(Instant.now()),401,"INVALID_CHALLENGE");nonce=n.nonce;n.consumed=true;
  }
  var identity=social.verify(provider,token,nonce);
  require(identity!=null&&provider.equals(identity.provider())&&identity.subject()!=null&&!identity.subject().isBlank()&&identity.subject().length()<=255,401,"INVALID_SOCIAL_IDENTITY");
  var user=db.one(Account.class,"from Account where provider=?1 and subject=?2",provider,identity.subject());
  if(user==null){user=new Account();user.provider=provider;user.subject=identity.subject();db.save(user);}
  require(!user.status.equals("DELETED"),403,"ACCOUNT_UNAVAILABLE");
  return issue(user,user.status.equals("ACTIVE")?"ACTIVE":"ONBOARDING");
 }
 Map<String,Object> issue(Account user,String scope){
  var session=new ServiceSession();String raw=Crypto.token();session.tokenHash=Crypto.hash(raw);session.userId=user.id;session.scope=scope;session.expiresAt=Instant.now().plusSeconds(scope.equals("ACTIVE")?28800:900);db.save(session);
  return Map.of("token",raw,"scope",scope,"expiresAt",session.expiresAt,"userId",user.id);
 }
 @Transactional(readOnly=true) public Actor resolve(String token){
  if(token==null||token.length()>128)return null;
  var s=db.session(Crypto.hash(token));if(s==null||s.revoked||!s.expiresAt.isAfter(Instant.now()))return null;
  var user=db.find(Account.class,s.userId);if(user==null||user.status.equals("DELETED"))return null;
  if(s.scope.equals("ACTIVE")&&!user.status.equals("ACTIVE"))return null;
  return new Actor(s.userId,s.scope,s.tokenHash);
 }
 @Transactional public Map<String,Object> sendSms(Actor actor,String phone){
  require(actor.scope().equals("ONBOARDING"),403,"ONBOARDING_ONLY");db.lock(Account.class,actor.userId());
  require(phone!=null&&phone.matches("\\+[1-9][0-9]{7,14}"),400,"INVALID_PHONE");
  // A transaction-scoped phone lock also prevents concurrent users bypassing cooldown.
  jdbc.execute((org.springframework.jdbc.core.ConnectionCallback<Void>) con->{try(PreparedStatement p=con.prepareStatement("select pg_advisory_xact_lock(hashtextextended(?,0))")){p.setString(1,phone);p.execute();}return null;});
  var recent=db.list(SmsChallenge.class,"from SmsChallenge where (phone=?1 or userId=?2) and createdAt>?3",phone,actor.userId(),Instant.now().minusSeconds(60));
  require(recent.isEmpty(),429,"SMS_COOLDOWN");
  require(db.list(SmsChallenge.class,"from SmsChallenge where userId=?1 and createdAt>?2",actor.userId(),Instant.now().minusSeconds(3600)).size()<5,429,"SMS_HOURLY_LIMIT");
  String code=String.format("%06d",Crypto.RANDOM.nextInt(1000000));
  var c=new SmsChallenge();c.userId=actor.userId();c.phone=phone;c.codeHash=bcrypt.encode(code);c.createdAt=Instant.now();c.expiresAt=c.createdAt.plusSeconds(300);
  sms.send(phone,code);db.save(c);return Map.of("id",c.id,"expiresAt",c.expiresAt);
 }
 @Transactional public boolean verifySms(Actor actor,UUID id,String code){
  var c=db.lock(SmsChallenge.class,id);require(c.userId.equals(actor.userId()),403,"NOT_YOUR_CHALLENGE");
  require(!c.consumed&&c.expiresAt.isAfter(Instant.now())&&c.attempts<5,400,"INVALID_CHALLENGE");
  if(c.verifiedAt!=null)return true;
  c.attempts++;boolean correct=code!=null&&code.matches("[0-9]{6}")&&bcrypt.matches(code,c.codeHash);if(correct)c.verifiedAt=Instant.now();return correct;
 }
 @Transactional public Map<String,Object> register(Actor actor,UUID verificationId,String nickname){
  require(actor.scope().equals("ONBOARDING"),403,"ONBOARDING_ONLY");var user=db.lock(Account.class,actor.userId());
  require(user.status.equals("PENDING"),409,"ALREADY_REGISTERED");
  require(nickname!=null&&!nickname.isBlank()&&nickname.length()<=50,400,"INVALID_NICKNAME");
  var c=db.lock(SmsChallenge.class,verificationId);
  require(c.userId.equals(user.id)&&!c.consumed&&c.verifiedAt!=null&&c.expiresAt.isAfter(Instant.now()),400,"PHONE_VERIFICATION_REQUIRED");
  require(db.one(Account.class,"from Account where phone=?1",c.phone)==null,409,"PHONE_ALREADY_REGISTERED");
  user.phone=c.phone;user.nickname=nickname.strip();user.status="ACTIVE";user.version++;c.consumed=true;
  for(var s:db.list(ServiceSession.class,"from ServiceSession where userId=?1 and scope='ONBOARDING'",user.id))s.revoked=true;
  db.flush();return issue(user,"ACTIVE");
 }
 @Transactional(readOnly=true) public Map<String,Object> me(Actor actor){var user=db.find(Account.class,actor.userId());return Map.of("id",user.id,"nickname",user.nickname,"phone",user.phone,"version",user.version);}
 @Transactional public Map<String,Object> logout(Actor actor){db.session(actor.sessionHash()).revoked=true;return Map.of("loggedOut",true);}
}
