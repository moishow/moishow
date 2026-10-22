package com.moishow.identity;
import org.springframework.context.annotation.Profile;import org.springframework.stereotype.Service;import org.springframework.transaction.annotation.Transactional;
import java.time.*;import java.util.*;
import static com.moishow.identity.Models.*;import static com.moishow.identity.ApiProblem.require;
@Service @Profile("db")
class EventService {
 final Store db;final ClubService clubs;EventService(Store db,ClubService clubs){this.db=db;this.clubs=clubs;}
 Object create(Actor actor,UUID clubId,IdentityController.EventForm b){
  var c=clubs.open(clubId);require(db.active(clubId,actor.userId()),403,"CLUB_MEMBER_REQUIRED");ClubService.expected(c,b.version());
  require(b.kind()!=null&&Set.of("REGULAR","LIGHTNING").contains(b.kind()),400,"INVALID_EVENT_KIND");
  if(b.kind().equals("REGULAR"))clubs.admin(actor,clubId);
  require(!b.publicEvent()||b.kind().equals("LIGHTNING"),400,"ONLY_LIGHTNING_CAN_BE_PUBLIC");
  require(b.startsAt()!=null&&b.endsAt()!=null&&b.endsAt().isAfter(b.startsAt())&&b.endsAt().isAfter(Instant.now()),400,"INVALID_EVENT_TIME");
  var e=new ClubEvent();e.clubId=clubId;e.hostId=actor.userId();e.responsibleId=actor.userId();e.title=ClubService.text(b.title(),100);e.kind=b.kind();e.publicEvent=b.publicEvent();e.startsAt=b.startsAt();e.endsAt=b.endsAt();db.save(e);c.version++;return eventView(e,actor);
 }
 Object round(Actor actor,UUID eventId,IdentityController.RoundForm b){
  var original=db.find(ClubEvent.class,eventId);clubs.open(original.clubId);var e=db.lock(ClubEvent.class,eventId);host(actor,e);ClubService.expected(e,b.version());
  require(b.capacity()!=null&&b.capacity()>=1&&b.capacity()<=10000&&b.closesAt()!=null&&!b.closesAt().isAfter(e.endsAt),400,"INVALID_ROUND");
  long fee=b.cancellationFee()==null?0:b.cancellationFee();require(fee>=0&&fee<=9007199254740991L,400,"INVALID_FEE");
  var r=new EventRound();r.eventId=eventId;r.capacity=b.capacity();r.closesAt=b.closesAt();r.cancellationFee=fee;db.save(r);e.version++;var response=new LinkedHashMap<String,Object>(roundView(r));response.put("eventVersion",e.version);return response;
 }
 void host(Actor actor,ClubEvent e){require(e.hostId.equals(actor.userId())&&db.active(e.clubId,actor.userId()),403,"EVENT_HOST_REQUIRED");}
 boolean historical(UUID eventId,UUID user){return !db.list(Participation.class,"select p from Participation p, EventRound r where p.roundId=r.id and r.eventId=?1 and p.userId=?2 and p.everConfirmed=true",eventId,user).isEmpty();}
 boolean financial(Actor actor,ClubEvent e){return e.responsibleId.equals(actor.userId())||db.active(e.clubId,actor.userId())||historical(e.id,actor.userId());}
 void visible(Actor actor,ClubEvent e){require(e.publicEvent||financial(actor,e),403,"EVENT_ACCESS_DENIED");}
 @Transactional(readOnly=true) public Object get(Actor actor,UUID id){var e=db.find(ClubEvent.class,id);visible(actor,e);return eventView(e,actor);}
 @Transactional(readOnly=true) public Object access(Actor actor,UUID id){var e=db.find(ClubEvent.class,id);visible(actor,e);return Map.of("viewSettlement",financial(actor,e),"manageSettlement",e.responsibleId.equals(actor.userId()),"manageEvent",e.hostId.equals(actor.userId())&&db.active(e.clubId,actor.userId()));}
 Map<String,Object> eventView(ClubEvent e,Actor actor){return Map.of("id",e.id,"clubId",e.clubId,"title",e.title,"kind",e.kind,"publicEvent",e.publicEvent,"version",e.version,"rounds",db.list(EventRound.class,"from EventRound where eventId=?1 order by id",e.id).stream().map(this::roundView).toList());}
 Map<String,Object> roundView(EventRound r){return Map.of("id",r.id,"eventId",r.eventId,"capacity",r.capacity,"closesAt",r.closesAt,"cancellationFee",r.cancellationFee,"version",r.version);}
 Object participate(Actor actor,UUID roundId,Long version){
  var original=db.find(EventRound.class,roundId);var e=db.find(ClubEvent.class,original.eventId);clubs.open(e.clubId);var r=db.lock(EventRound.class,roundId);ClubService.expected(r,version);
  var m=db.member(e.clubId,actor.userId());require(m==null||!m.blacklisted,403,"CLUB_BLACKLISTED");require(e.publicEvent||db.active(e.clubId,actor.userId()),403,"EVENT_MEMBER_REQUIRED");
  require(e.endsAt.isAfter(Instant.now()),409,"EVENT_ENDED");require(db.one(Participation.class,"from Participation where roundId=?1 and userId=?2",roundId,actor.userId())==null,409,"PARTICIPATION_EXISTS");
  var p=new Participation();p.roundId=roundId;p.userId=actor.userId();p.agreedFee=r.cancellationFee;
  p.status=r.closesAt.isAfter(Instant.now())?(hasSpace(r)?"CONFIRMED":"WAITLISTED"):"LATE_REQUESTED";p.everConfirmed=p.status.equals("CONFIRMED");db.save(p);r.version++;return participantView(p,r);
 }
 Object changeParticipation(Actor actor,UUID roundId,UUID participantId,String action,Long version){
  var initial=db.find(EventRound.class,roundId);var e=db.find(ClubEvent.class,initial.eventId);db.lock(Club.class,e.clubId);var r=db.lock(EventRound.class,roundId);ClubService.expected(r,version);var p=db.find(Participation.class,participantId);require(p.roundId.equals(roundId),404,"NOT_FOUND");
  if(action.equals("approve")){
   host(actor,e);require(db.find(Club.class,e.clubId).status.equals("ACTIVE")&&e.endsAt.isAfter(Instant.now()),409,"EVENT_ENDED");var m=db.member(e.clubId,p.userId);
   require(m==null||!m.blacklisted,403,"CLUB_BLACKLISTED");require(e.publicEvent||db.active(e.clubId,p.userId),403,"EVENT_MEMBER_REQUIRED");
   require(p.status.equals("LATE_REQUESTED")&&hasSpace(r),409,"NOT_APPROVABLE");p.status="CONFIRMED";p.everConfirmed=true;
  }else if(action.equals("cancel")){require(p.userId.equals(actor.userId()),403,"OWN_PARTICIPATION_ONLY");require(!p.status.equals("CANCELLED"),409,"ALREADY_CANCELLED");p.status="CANCELLED";}
  else throw new ApiProblem(404,"UNKNOWN_OPERATION");
  p.version++;r.version++;return participantView(p,r);
 }
 @Transactional(readOnly=true) public Object ownParticipation(Actor actor,UUID roundId){
  var round=db.find(EventRound.class,roundId);var p=db.one(Participation.class,"from Participation where roundId=?1 and userId=?2",roundId,actor.userId());
  require(p!=null,404,"PARTICIPATION_NOT_FOUND");return participantView(p,round);
 }
 @Transactional(readOnly=true) public Object participants(Actor actor,UUID eventId){
  var e=db.find(ClubEvent.class,eventId);
  require(e.responsibleId.equals(actor.userId())||(e.hostId.equals(actor.userId())&&db.active(e.clubId,actor.userId())),403,"EVENT_HOST_REQUIRED");
  return db.list(Participation.class,"select p from Participation p, EventRound r where p.roundId=r.id and r.eventId=?1 order by p.id",eventId).stream().map(p->{
   var result=new LinkedHashMap<String,Object>(participantView(p,db.find(EventRound.class,p.roundId)));var member=db.member(e.clubId,p.userId);
   boolean hasClubName=member!=null&&member.nickname!=null&&Set.of("ACTIVE","LEFT","EXPELLED").contains(member.status);
   result.put("nickname",hasClubName?member.nickname:db.find(Account.class,p.userId).nickname);
   result.put("departed",member!=null&&Set.of("LEFT","EXPELLED").contains(member.status));return result;
  }).toList();
 }
 boolean hasSpace(EventRound r){return db.list(Participation.class,"from Participation where roundId=?1 and status='CONFIRMED'",r.id).size()<r.capacity;}
 Map<String,Object> participantView(Participation p,EventRound r){return Map.of("id",p.id,"roundId",p.roundId,"userId",p.userId,"status",p.status,"agreedFee",p.agreedFee,"version",r.version);}
}
