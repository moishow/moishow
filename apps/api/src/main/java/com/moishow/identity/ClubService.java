package com.moishow.identity;
import org.springframework.context.annotation.Profile;import org.springframework.stereotype.Service;import org.springframework.transaction.annotation.Transactional;
import java.time.*;import java.util.*;
import static com.moishow.identity.Models.*;import static com.moishow.identity.ApiProblem.require;
@Service @Profile("db")
class ClubService {
 final Store db;ClubService(Store db){this.db=db;}
 static void expected(Row row,Long version){require(version!=null&&version==row.version,409,"STALE_VERSION");}
 static String text(String value,int max){require(value!=null&&!value.isBlank()&&value.length()<=max,400,"INVALID_TEXT");return value.strip();}
 Club open(UUID clubId){var c=db.lock(Club.class,clubId);require(c.status.equals("ACTIVE"),409,"CLUB_NOT_ACTIVE");return c;}
 void admin(Actor actor,UUID club){require(db.admin(club,actor.userId()),403,"CLUB_ADMIN_REQUIRED");}
 Object create(Actor actor,IdentityController.ClubForm b){
  require(b.joinMode()!=null&&Set.of("IMMEDIATE","APPROVAL").contains(b.joinMode()),400,"INVALID_JOIN_MODE");
  var c=new Club();c.name=text(b.name(),100);c.joinMode=b.joinMode();c.ownerId=actor.userId();db.save(c);
  var m=new Membership();m.clubId=c.id;m.userId=actor.userId();m.nickname=db.find(Account.class,actor.userId()).nickname;m.role="OWNER";m.status="ACTIVE";db.save(m);return clubView(c,m);
 }
 Object join(Actor actor,UUID clubId,IdentityController.JoinForm b){
  var c=open(clubId);expected(c,b.version());var m=db.member(clubId,actor.userId());
  require(m==null||!m.blacklisted,403,"CLUB_BLACKLISTED");require(m==null||!Set.of("ACTIVE","PENDING").contains(m.status),409,"MEMBERSHIP_EXISTS");
  boolean invited=false;
  if(b.inviteToken()!=null){var i=db.one(Invitation.class,"from Invitation where tokenHash=?1 and clubId=?2",Crypto.hash(b.inviteToken()),clubId);require(i!=null&&i.expiresAt.isAfter(Instant.now()),400,"INVALID_INVITATION");invited=true;}
  if(m==null){m=new Membership();m.clubId=clubId;m.userId=actor.userId();db.save(m);}
  m.nickname=text(b.nickname(),50);m.role="MEMBER";m.status=!m.expelledHistory&&(c.joinMode.equals("IMMEDIATE")||invited)?"ACTIVE":"PENDING";m.version++;c.version++;return clubView(c,m);
 }
 Object manage(Actor actor,UUID clubId,UUID target,String action,IdentityController.ChangeForm b){
  var c=open(clubId);admin(actor,clubId);expected(c,b.version());require(!target.equals(c.ownerId),403,"OWNER_PROTECTED");db.find(Account.class,target);
  var m=db.member(clubId,target);
  if(m==null){require(action.equals("blacklist"),404,"MEMBERSHIP_NOT_FOUND");m=new Membership();m.userId=target;m.clubId=clubId;db.save(m);}
  if(m.role.equals("ADMIN"))require(c.ownerId.equals(actor.userId()),403,"OWNER_REQUIRED");
  switch(action){
   case "approve"->{require(m.status.equals("PENDING")&&!m.blacklisted,409,"NOT_APPROVABLE");m.status="ACTIVE";}
   case "expel"->{require(m.status.equals("ACTIVE"),409,"NOT_MEMBER");m.status="EXPELLED";m.expelledHistory=true;m.role="MEMBER";}
   case "blacklist"->{require(b.enabled()!=null,400,"ENABLED_REQUIRED");m.blacklisted=b.enabled();if(m.blacklisted&&m.status.equals("ACTIVE")){m.expelledHistory=true;m.status="EXPELLED";m.role="MEMBER";}else if(m.blacklisted&&m.status.equals("PENDING"))m.status="NONE";}
   case "role"->{require(c.ownerId.equals(actor.userId()),403,"OWNER_REQUIRED");require(m.status.equals("ACTIVE")&&b.role()!=null&&Set.of("ADMIN","MEMBER").contains(b.role()),400,"INVALID_ROLE");m.role=b.role();}
   default->throw new ApiProblem(404,"UNKNOWN_OPERATION");
  }
  m.version++;c.version++;return clubView(c,m);
 }
 Object invite(Actor actor,UUID clubId,Long version){var c=open(clubId);admin(actor,clubId);expected(c,version);var i=new Invitation();String token=Crypto.token();i.clubId=clubId;i.tokenHash=Crypto.hash(token);i.expiresAt=Instant.now().plusSeconds(604800);db.save(i);c.version++;return Map.of("id",i.id,"inviteToken",token,"version",c.version,"expiresAt",i.expiresAt);}
 Object leave(Actor actor,UUID clubId,Long version){var c=open(clubId);expected(c,version);require(!c.ownerId.equals(actor.userId()),403,"OWNER_TRANSFER_REQUIRED");var m=db.member(clubId,actor.userId());require(m!=null&&Set.of("ACTIVE","PENDING").contains(m.status),409,"NOT_MEMBER");m.status="LEFT";m.role="MEMBER";m.version++;c.version++;return clubView(c,m);}
 @Transactional(readOnly=true) public Object get(Actor actor,UUID clubId){var c=db.find(Club.class,clubId);return clubView(c,db.member(clubId,actor.userId()));}
 @Transactional(readOnly=true) public Object mine(Actor actor){return db.list(Membership.class,"from Membership where userId=?1 and status='ACTIVE' order by id",actor.userId()).stream().map(m->clubView(db.find(Club.class,m.clubId),m)).toList();}
 @Transactional(readOnly=true) public Object members(Actor actor,UUID clubId){require(db.active(clubId,actor.userId()),403,"CLUB_MEMBER_REQUIRED");return db.list(Membership.class,"from Membership where clubId=?1 and status='ACTIVE' order by id",clubId).stream().map(m->Map.of("userId",m.userId,"nickname",m.nickname,"role",m.role)).toList();}
 @Transactional(readOnly=true) public Object requests(Actor actor,UUID clubId){
  var club=db.find(Club.class,clubId);admin(actor,clubId);
  return db.list(Membership.class,"from Membership where clubId=?1 and status='PENDING' and blacklisted=false order by id",clubId).stream()
   .map(m->Map.of("userId",m.userId,"nickname",m.nickname,"status",m.status,"version",club.version)).toList();
 }
 private Map<String,Object> clubView(Club c,Membership m){var v=new LinkedHashMap<String,Object>();v.put("id",c.id);v.put("name",c.name);v.put("joinMode",c.joinMode);v.put("status",c.status);v.put("version",c.version);v.put("membershipStatus",m==null?"NONE":m.status);v.put("role",m==null?"NONE":m.role);return v;}
}
