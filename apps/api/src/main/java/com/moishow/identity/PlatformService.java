package com.moishow.identity;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import java.time.*;import java.sql.Timestamp;import java.util.*;
import static com.moishow.identity.ApiProblem.require;
import static com.moishow.identity.Models.*;

/** Durable platform workflows. Financial completion is exclusively owned by finance/reserve services. */
@Service @Profile("db")
public class PlatformService implements FinanceCaseAccess {
 final Store db; final JdbcTemplate sql; final EventService events; final PlatformOutbox outbox; final org.springframework.beans.factory.ObjectProvider<FinanceScoreSource> scoreSource; final org.springframework.beans.factory.ObjectProvider<PlatformContentAccess> contentAccess; final org.springframework.transaction.support.TransactionTemplate reconcileTx;
 PlatformService(Store db,JdbcTemplate sql,EventService events,PlatformOutbox outbox,org.springframework.beans.factory.ObjectProvider<FinanceScoreSource> scoreSource,org.springframework.beans.factory.ObjectProvider<PlatformContentAccess> contentAccess,org.springframework.transaction.PlatformTransactionManager manager){this.db=db;this.sql=sql;this.events=events;this.outbox=outbox;this.scoreSource=scoreSource;this.contentAccess=contentAccess;this.reconcileTx=new org.springframework.transaction.support.TransactionTemplate(manager);this.reconcileTx.setPropagationBehavior(org.springframework.transaction.TransactionDefinition.PROPAGATION_REQUIRES_NEW);}
 static String text(String value){require(value!=null&&!value.isBlank()&&value.length()<=4000,400,"REASON_REQUIRED");return value.trim();}
 boolean operator(UUID user){return Boolean.TRUE.equals(sql.queryForObject("select exists(select 1 from platform_operator where user_id=?)",Boolean.class,user));}
 static UUID uuid(Map<String,Object> row,String key){return (UUID)row.get(key);}
 Map<String,Object> row(UUID id,boolean lock){var rows=sql.queryForList("select * from platform_case where id=?"+(lock?" for update":""),id);require(!rows.isEmpty(),404,"CASE_NOT_FOUND");return rows.getFirst();}
 boolean eligible(Actor a,Map<String,Object> c){
  if(!db.find(Account.class,a.userId()).status.equals("ACTIVE"))return false;
  if(a.userId().equals(uuid(c,"requester_id")))return false;
  if(c.get("case_type").equals("REPORT")&&a.userId().equals(uuid(c,"target_user_id")))return false;
  UUID club=uuid(c,"club_id");return switch((String)c.get("route")){
   case "OPERATOR"->operator(a.userId());
   case "OWNER"->db.find(Club.class,club).ownerId.equals(a.userId());
   case "CLUB"->db.admin(club,a.userId());
   case "HOST"->db.find(ClubEvent.class,uuid(c,"event_id")).responsibleId.equals(a.userId());
   default->false;};
 }
 boolean processor(Actor a,Map<String,Object> c){return a.userId().equals(uuid(c,"handler_id"))&&eligible(a,c);}
 @Override @Transactional(readOnly=true) public boolean assigned(UUID actor,UUID event,UUID dispute){
  return sql.queryForList("select * from platform_case where handler_id=? and event_id=? and financial_dispute_id=? and status<>'RESOLVED'",actor,event,dispute).stream().anyMatch(c->processor(new Actor(actor,"ACTIVE","internal"),c));
 }
 @Override @Transactional(readOnly=true) public boolean canRead(UUID actor,UUID event,UUID dispute){
  return sql.queryForList("select * from platform_case where handler_id=? and event_id=? and financial_dispute_id=?",actor,event,dispute).stream().anyMatch(c->processor(new Actor(actor,"ACTIVE","internal"),c));
 }
 @Override @Transactional(readOnly=true) public boolean canResolve(UUID actor,UUID event,UUID dispute){return assigned(actor,event,dispute);}
 @Transactional(readOnly=true) public boolean assignedContentEvidence(Actor actor,UUID contentId,String contentType){
  if(actor==null||!actor.scope().equals("ACTIVE")||contentId==null||contentType==null)return false;
  return sql.queryForList("select * from platform_case where handler_id=? and content_id=? and content_type=?",actor.userId(),contentId,contentType).stream().anyMatch(c->processor(actor,c));
 }
 @Transactional(readOnly=true) public boolean assignedFileEvidence(Actor actor,UUID fileId){
  if(actor==null||!actor.scope().equals("ACTIVE")||fileId==null)return false;
  return sql.queryForList("select c.* from platform_case c join platform_case_photo p on p.case_id=c.id where p.file_id=? and c.handler_id=?",fileId,actor.userId()).stream().anyMatch(c->processor(actor,c));
 }
 boolean visible(Actor a,Map<String,Object> c){return a.userId().equals(uuid(c,"requester_id"))||a.userId().equals(uuid(c,"target_user_id"))||processor(a,c);}
 Map<String,Object> view(Map<String,Object> raw){var result=new LinkedHashMap<String,Object>();raw.forEach((key,value)->{String[] parts=key.split("_");StringBuilder name=new StringBuilder(parts[0]);for(int i=1;i<parts.length;i++)name.append(Character.toUpperCase(parts[i].charAt(0))).append(parts[i].substring(1));result.put(name.toString(),value instanceof Timestamp t?t.toInstant():value);});return result;}
 @Transactional(readOnly=true) public Object inbox(Actor a){return sql.queryForList("select id,kind,event_id,group_key,body,item_count as count,is_read as read,created_at from platform_notification where user_id=? order by created_at desc,id",a.userId()).stream().map(this::view).toList();}
 public Object read(Actor a,UUID id){require(sql.update("update platform_notification set is_read=true where id=? and user_id=?",id,a.userId())==1,404,"NOTIFICATION_NOT_FOUND");return Map.of("id",id,"read",true);}
 @Transactional(readOnly=true) public Object devices(Actor a){return sql.queryForList("select id,platform,created_at,updated_at from platform_push_device where user_id=? and revoked_at is null order by id",a.userId()).stream().map(this::view).toList();}
 public Object device(Actor a,PlatformModels.Device b){require(b.token()!=null&&!b.token().isBlank()&&b.token().length()<=4096&&b.token().chars().noneMatch(Character::isWhitespace),400,"INVALID_DEVICE_TOKEN");require(Set.of("ANDROID","IOS","WEB").contains(b.platform()==null?"":b.platform()),400,"INVALID_DEVICE_PLATFORM");sql.queryForList("select pg_advisory_xact_lock(hashtextextended(?,0))",b.token());var old=sql.queryForList("select id,user_id from platform_push_device where token=? for update",b.token());UUID id;if(!old.isEmpty()){require(a.userId().equals(uuid(old.getFirst(),"user_id")),409,"DEVICE_ALREADY_REGISTERED");id=uuid(old.getFirst(),"id");sql.update("update platform_push_device set platform=?,updated_at=now() where id=?",b.platform(),id);}else{id=UUID.randomUUID();sql.update("insert into platform_push_device(id,user_id,token,platform) values(?,?,?,?)",id,a.userId(),b.token(),b.platform());}return Map.of("id",id,"platform",b.platform());}
 public Object deleteDevice(Actor a,UUID id){require(sql.update("update platform_push_device set token=null,revoked_at=now(),updated_at=now() where id=? and user_id=? and revoked_at is null",id,a.userId())==1,404,"DEVICE_NOT_FOUND");return Map.of("id",id,"removed",true);}
 @Transactional(readOnly=true) public Object preferences(Actor a){var rows=sql.queryForList("select push_enabled from platform_preference where user_id=?",a.userId());return Map.of("pushEnabled",rows.isEmpty()||Boolean.TRUE.equals(rows.getFirst().get("push_enabled")));}
 public Object preferences(Actor a,PlatformModels.Preferences b){require(b.pushEnabled()!=null,400,"PUSH_PREFERENCE_REQUIRED");sql.update("insert into platform_preference(user_id,push_enabled) values(?,?) on conflict(user_id) do update set push_enabled=excluded.push_enabled",a.userId(),b.pushEnabled());if(!b.pushEnabled())sql.update("update platform_outbox set status='SUPPRESSED',last_error='PUSH_DISABLED' where status in ('PENDING','RETRY') and notification_id in (select id from platform_notification where user_id=?)",a.userId());return preferences(a);}
 /** Internal trusted event callback. There is intentionally no client notification insertion endpoint. */
 @Transactional public void notify(UUID user,String kind,UUID eventId,String group,String body){
  require(Set.of("SOCIAL","MONEY","REFUND","DISPUTE","SUPPORT").contains(kind),400,"INVALID_NOTIFICATION_KIND");body=text(body);UUID id=UUID.randomUUID();
  if(kind.equals("SOCIAL")&&group!=null){require(group.length()<=255,400,"INVALID_GROUP_KEY");id=sql.queryForObject("insert into platform_notification(id,user_id,kind,event_id,group_key,body) values(?,?,?,?,?,?) on conflict(user_id,group_key) where kind='SOCIAL' and group_key is not null and not is_read do update set item_count=platform_notification.item_count+1,body=excluded.body,created_at=now() returning id",UUID.class,id,user,kind,eventId,group,body);}
  else sql.update("insert into platform_notification(id,user_id,kind,event_id,group_key,body) values(?,?,?,?,?,?)",id,user,kind,eventId,null,body);
  boolean enabled=Boolean.TRUE.equals(sql.queryForObject("select coalesce((select push_enabled from platform_preference where user_id=?),true)",Boolean.class,user));
  sql.update("insert into platform_outbox(id,notification_id,status,last_error) values(?,?,?,?)",UUID.randomUUID(),id,enabled?"PENDING":"SUPPRESSED",enabled?null:"PUSH_DISABLED");
 }
 @Transactional public void assessLevel(UUID eventId,UUID user,String role,String outcome,String reason){
  require(Set.of("HOST","PARTICIPANT").contains(role)&&Set.of("ON_TIME","LATE","RECOVERED","HOLD","ERROR_CORRECTED").contains(outcome),400,"INVALID_LEVEL_ASSESSMENT");text(reason);var event=db.find(ClubEvent.class,eventId);
  require(role.equals("HOST")?(event.hostId.equals(user)||event.responsibleId.equals(user)||Boolean.TRUE.equals(sql.queryForObject("select exists(select 1 from finance_revision r join settlement_book b on b.id=r.book_id where b.event_id=? and r.reason='INITIAL' and r.created_by=?)",Boolean.class,eventId,user))):events.historical(eventId,user),400,"LEVEL_ROLE_RELATION_REQUIRED");
  if(role.equals("HOST")&&!event.hostId.equals(user)){assessLevel(eventId,event.hostId,"HOST","HOLD","인계 후 등록의 주최 점수 귀속 판정 보류");return;}
  UUID id=UUID.randomUUID();sql.update("insert into platform_level(id,event_id,user_id,role,outcome,delta,reason) values(?,?,?,?,'HOLD',0,?) on conflict(event_id,user_id,role) do nothing",id,eventId,user,role,reason);
  var old=sql.queryForMap("select * from platform_level where event_id=? and user_id=? and role=? for update",eventId,user,role);id=uuid(old,"id");String before=(String)old.get("outcome");
  if(before.equals(outcome))return;
  if(outcome.equals("ON_TIME")&&Set.of("ON_TIME","RECOVERED").contains(before))return;
  if(outcome.equals("LATE")&&Set.of("ON_TIME","RECOVERED").contains(before))return;
  if(outcome.equals("RECOVERED")&&before.equals("ON_TIME"))return;
  if(outcome.equals("ON_TIME")&&before.equals("LATE"))outcome="RECOVERED";
  int delta=switch(outcome){case "ON_TIME"->role.equals("HOST")?2:1;case "LATE"->role.equals("HOST")?-4:-2;case "RECOVERED"->role.equals("HOST")?-2:-1;default->0;};
  sql.update("update platform_level set outcome=?,delta=?,reason=?,updated_at=now() where id=?",outcome,delta,reason,id);
  sql.update("insert into platform_level_audit(id,level_id,outcome,delta,reason) values(?,?,?,?,?)",UUID.randomUUID(),id,outcome,delta,reason);
 }
 @Transactional(readOnly=true) public Object level(Actor a,UUID clubId,UUID user){
  db.find(Club.class,clubId);db.find(Account.class,user);boolean clubRelation=db.active(clubId,a.userId())&&db.active(clubId,user);
  boolean shared=Boolean.TRUE.equals(sql.queryForObject("select exists(select 1 from club_event e where e.club_id=? and (e.host_id=? or exists(select 1 from event_round r join participation p on p.round_id=r.id where r.event_id=e.id and p.user_id=? and p.ever_confirmed)) and (e.host_id=? or exists(select 1 from event_round r join participation p on p.round_id=r.id where r.event_id=e.id and p.user_id=? and p.ever_confirmed)))",Boolean.class,clubId,a.userId(),a.userId(),user,user));
  require(clubRelation||shared,403,"LEVEL_RELATION_REQUIRED");var history=sql.queryForList("select l.event_id,l.role,l.outcome,l.delta,l.reason,l.updated_at from platform_level l join club_event e on e.id=l.event_id where e.club_id=? and l.user_id=? order by l.updated_at,l.id",clubId,user);
  int total=history.stream().mapToInt(h->((Number)h.get("delta")).intValue()).sum();return Map.of("score",Math.max(0,Math.min(100,50+total)),"historyLabel",history.isEmpty()?"이력 없음":"참여 이력","history",history.stream().map(this::view).toList());
 }
 public Object request(Actor a,PlatformModels.Request b){
  require(b.eventId()!=null,400,"EVENT_REQUIRED");var e=db.find(ClubEvent.class,b.eventId());require(events.financial(a,e),403,"EVENT_RELATION_REQUIRED");require(!a.userId().equals(e.responsibleId),400,"OWN_PROCESSING_REQUEST");
  if(b.financialDisputeId()!=null){var disputes=sql.queryForList("select d.user_id,b.event_id from finance_dispute d join settlement_book b on b.id=d.book_id where d.id=?",b.financialDisputeId());require(!disputes.isEmpty()&&b.eventId().equals(uuid(disputes.getFirst(),"event_id")),404,"DISPUTE_NOT_FOUND");require(a.userId().equals(uuid(disputes.getFirst(),"user_id")),403,"DISPUTE_PARTY_REQUIRED");var existing=sql.queryForList("select id from platform_case where financial_dispute_id=? and status<>'RESOLVED'",b.financialDisputeId());if(!existing.isEmpty())return caseView(a,uuid(existing.getFirst(),"id"));}
  var club=db.find(Club.class,e.clubId);return create(a,"REQUEST",e.clubId,e.id,e.responsibleId,club.ownerId.equals(e.responsibleId)?"OPERATOR":"HOST",b.reason(),null,null,b.financialDisputeId(),null);
 }
 public Object report(Actor a,PlatformModels.Report b){
  require(b.targetUserId()!=null&&Set.of("CLUB_CONTENT","PERSONAL_CONTENT","USER").contains(b.type()==null?"":b.type()),400,"INVALID_REPORT");db.find(Account.class,b.targetUserId());UUID club=b.clubId();if(club!=null)db.find(Club.class,club);
  if(b.eventId()!=null){var e=db.find(ClubEvent.class,b.eventId());require(events.financial(a,e),403,"EVENT_RELATION_REQUIRED");require(club==null||club.equals(e.clubId),400,"EVENT_CLUB_MISMATCH");club=e.clubId;}
  String snapshot=null;if(b.type().equals("CLUB_CONTENT")){require(club!=null&&db.active(club,a.userId()),403,"CLUB_MEMBER_REQUIRED");snapshot=validateContent(a,b,club);}
  else if(b.type().equals("PERSONAL_CONTENT")){require(club==null,400,"PERSONAL_CONTENT_HAS_NO_CLUB");snapshot=validateContent(a,b,null);}
  else require(b.contentId()==null&&b.contentType()==null,400,"USER_REPORT_CONTENT_NOT_ALLOWED");
  String route=b.type().equals("CLUB_CONTENT")&&!db.admin(club,b.targetUserId())?"CLUB":"OPERATOR";
  return create(a,"REPORT",club,b.eventId(),b.targetUserId(),route,b.reason(),b.contentId(),b.contentType(),null,snapshot);
 }
 String validateContent(Actor a,PlatformModels.Report b,UUID club){
  require(b.contentId()!=null,400,"CONTENT_REQUIRED");String type=b.contentType()==null?"POST":b.contentType();require(Set.of("POST","COMMENT","MESSAGE").contains(type),400,"INVALID_CONTENT_TYPE");var access=contentAccess.getIfAvailable();require(access!=null,503,"COMMUNITY_ACCESS_UNAVAILABLE");
  String query=switch(type){case "POST"->"select p.club_id,p.user_id,p.body,p.id as post_id from community_post p where p.id=? and p.status='ACTIVE' for update of p";case "COMMENT"->"select p.club_id,c.user_id,c.body,p.id as post_id from community_comment c join community_post p on p.id=c.post_id where c.id=? and c.status='ACTIVE' and p.status='ACTIVE'";default->"select null::uuid as club_id,m.user_id,m.body,m.room_id from community_message m where m.id=? and m.status='ACTIVE'";};
  var rows=sql.queryForList(query,b.contentId());require(!rows.isEmpty(),404,"CONTENT_NOT_FOUND");var item=rows.getFirst();require(Objects.equals(club,item.get("club_id"))&&b.targetUserId().equals(item.get("user_id")),400,"CONTENT_REPORT_MISMATCH");
  if(type.equals("MESSAGE")){require(b.type().equals("PERSONAL_CONTENT"),400,"MESSAGE_OPERATOR_REPORT_REQUIRED");require(access.canReadMessage(a,b.contentId()),403,"ROOM_ACCESS_DENIED");}else require(access.canReadPost(a,uuid(item,"post_id")),403,"CONTENT_ACCESS_DENIED");return (String)item.get("body");
 }
 Object create(Actor a,String type,UUID club,UUID event,UUID target,String route,String reason,UUID content,String contentType,UUID dispute,String snapshot){UUID id=UUID.randomUUID();sql.update("insert into platform_case(id,case_type,club_id,event_id,requester_id,target_user_id,route,reason,content_id,content_type,financial_dispute_id,content_snapshot) values(?,?,?,?,?,?,?,?,?,?,?,?)",id,type,club,event,a.userId(),target,route,text(reason),content,content==null?null:(contentType==null?"POST":contentType),dispute,snapshot);if(content!=null&&(contentType==null||contentType.equals("POST")))sql.update("insert into platform_case_photo(case_id,file_id,position) select ?,file_id,position from community_post_photo where post_id=?",id,content);history(id,a.userId(),"CREATED","처리 요청 접수");notifyProcessors(row(id,false),"새 처리 요청이 도착했습니다.");return caseView(a,id);}
 Map<String,Object> capabilities(Actor a,Map<String,Object> c,Map<String,Object> result){
  boolean open=!c.get("status").equals("RESOLVED");UUID handler=uuid(c,"handler_id");
  boolean claim=open&&eligible(a,c)&&!a.userId().equals(handler)&&(handler==null||!eligible(new Actor(handler,"ACTIVE","internal"),c));
  result.put("isRequester",a.userId().equals(uuid(c,"requester_id")));result.put("canReadDetails",visible(a,c));result.put("canClaim",claim);result.put("canDecide",open&&processor(a,c));return result;
 }
 @Transactional(readOnly=true) public Object cases(Actor a,boolean operatorsOnly){if(operatorsOnly)require(operator(a.userId()),403,"OPERATOR_REQUIRED");return sql.queryForList("select * from platform_case order by created_at desc,id").stream().filter(c->operatorsOnly?c.get("route").equals("OPERATOR")&&eligible(a,c):visible(a,c)||eligible(a,c)).map(c->{var summary=new LinkedHashMap<String,Object>();for(String key:List.of("id","version","case_type","route","status","created_at","activity_at","handler_id"))summary.put(key,c.get(key));return capabilities(a,c,view(summary));}).toList();}
 @Transactional(readOnly=true) public Object caseView(Actor a,UUID id){var c=row(id,false);require(visible(a,c),403,"CASE_ACCESS_DENIED");var result=capabilities(a,c,view(c));result.put("photoIds",sql.queryForList("select file_id from platform_case_photo where case_id=? order by position",UUID.class,id));result.put("history",sql.queryForList("select * from platform_case_history where case_id=? order by created_at,id",id).stream().map(this::view).toList());return result;}
 @Transactional(readOnly=true) public Object publicResults(Actor a,UUID eventId){var event=db.find(ClubEvent.class,eventId);boolean member=db.active(event.clubId,a.userId());require(member||events.financial(a,event),403,"EVENT_RELATION_REQUIRED");return sql.queryForList("select c.id,c.status,c.financial_dispute_id,d.status as dispute_status,d.public_result as result,d.correction_amount,d.revision_id from platform_case c join finance_dispute d on d.id=c.financial_dispute_id where c.event_id=? and (? or c.requester_id=?) order by c.created_at,c.id",eventId,member,a.userId()).stream().map(this::view).toList();}
 void expected(Map<String,Object> c,Long version){require(version!=null&&version==((Number)c.get("version")).longValue(),409,"STALE_VERSION");require(!c.get("status").equals("RESOLVED"),409,"CASE_RESOLVED");}
 public Object claim(Actor a,UUID id,PlatformModels.Version b){var c=row(id,true);require(eligible(a,c),403,"CASE_PROCESSOR_REQUIRED");expected(c,b.version());UUID handler=uuid(c,"handler_id");if(a.userId().equals(handler))return caseView(a,id);if(handler!=null)require(!eligible(new Actor(handler,"ACTIVE","internal"),c),409,"CASE_ALREADY_ASSIGNED");sql.update("update platform_case set handler_id=?,assigned_at=now(),version=version+1 where id=?",a.userId(),id);history(id,a.userId(),handler==null?"CLAIM":"RECLAIM","정확한 사건 담당자 할당");return caseView(a,id);}
 public Object escalate(Actor a,UUID id,PlatformModels.Version b){var c=row(id,true);require(a.userId().equals(uuid(c,"requester_id")),403,"REQUESTER_REQUIRED");expected(c,b.version());require(((Timestamp)c.get("activity_at")).toInstant().plus(Duration.ofHours(72)).isBefore(Instant.now()),409,"ESCALATION_NOT_DUE");String route=(String)c.get("route");require(!route.equals("OPERATOR"),409,"ALREADY_OPERATOR");String next=route.equals("HOST")?"OWNER":"OPERATOR";sql.update("update platform_case set route=?,handler_id=null,assigned_at=null,status='OPEN',version=version+1,activity_at=now(),reminded=false where id=?",next,id);history(id,a.userId(),"ESCALATE","72시간 무응답 상향 요청");notifyProcessors(row(id,false),"무응답 처리 요청이 상향되었습니다.");return caseView(a,id);}
 public Object decide(Actor a,UUID id,PlatformModels.Decision b){var c=row(id,true);require(processor(a,c),403,"CASE_PROCESSOR_REQUIRED");expected(c,b.version());require(Set.of("PROGRESS","RESOLVE","WARN","RESTRICT","CORRECTION_REQUEST","HANDOVER_REQUEST","CONTENT_REMOVE").contains(b.action()==null?"":b.action()),400,"INVALID_DECISION");String reason=text(b.reason());
  if(Set.of("RESTRICT","WARN","CORRECTION_REQUEST","HANDOVER_REQUEST").contains(b.action()))require(c.get("route").equals("OPERATOR"),403,"OPERATOR_ACTION_REQUIRED");
  if(b.action().equals("RESTRICT"))sql.update("insert into platform_restriction(user_id,case_id,reason) values(?,?,?) on conflict(user_id) do update set case_id=excluded.case_id,reason=excluded.reason,created_at=now()",uuid(c,"target_user_id"),id,reason);
  if(b.action().equals("CONTENT_REMOVE"))removeContent(c);
  boolean resolved=Set.of("RESOLVE","WARN","RESTRICT","CONTENT_REMOVE").contains(b.action());sql.update("update platform_case set status=?,version=version+1,activity_at=now(),reminded=false where id=?",resolved?"RESOLVED":"PROGRESS",id);history(id,a.userId(),b.action(),reason);notify(uuid(c,"requester_id"),"SUPPORT",uuid(c,"event_id"),null,"처리 요청의 진행 상태가 변경되었습니다.");if(Set.of("CORRECTION_REQUEST","HANDOVER_REQUEST","WARN","RESTRICT").contains(b.action()))notify(uuid(c,"target_user_id"),"SUPPORT",uuid(c,"event_id"),null,"운영자가 처리 안내를 등록했습니다.");return caseView(a,id);
 }
 void removeContent(Map<String,Object> c){require(c.get("case_type").equals("REPORT")&&c.get("content_id")!=null,400,"REPORTED_CONTENT_REQUIRED");UUID id=uuid(c,"content_id"),target=uuid(c,"target_user_id"),club=uuid(c,"club_id");String type=(String)c.get("content_type");int changed=switch(type){case "COMMENT"->sql.update("update community_comment set status='REMOVED',version=version+1 where id=? and user_id=? and status='ACTIVE' and post_id in(select id from community_post where club_id is not distinct from cast(? as uuid))",id,target,club);case "MESSAGE"->{require(c.get("route").equals("OPERATOR"),403,"OPERATOR_ACTION_REQUIRED");yield sql.update("update community_message set status='REMOVED',version=version+1 where id=? and user_id=? and status='ACTIVE'",id,target);}default->sql.update("update community_post set status='REMOVED',version=version+1 where id=? and user_id=? and club_id is not distinct from cast(? as uuid) and status='ACTIVE'",id,target,club);};require(changed==1,409,"CONTENT_ALREADY_CHANGED");}
 void history(UUID id,UUID actor,String action,String reason){sql.update("insert into platform_case_history(id,case_id,actor_id,action,reason) values(?,?,?,?,?)",UUID.randomUUID(),id,actor,action,reason);}
 void notifyProcessors(Map<String,Object> c,String body){List<UUID> users=switch((String)c.get("route")){case "OPERATOR"->sql.queryForList("select user_id from platform_operator",UUID.class);case "OWNER"->List.of(db.find(Club.class,uuid(c,"club_id")).ownerId);case "HOST"->List.of(db.find(ClubEvent.class,uuid(c,"event_id")).responsibleId);default->sql.queryForList("select user_id from membership where club_id=? and status='ACTIVE' and not blacklisted and role in ('OWNER','ADMIN')",UUID.class,uuid(c,"club_id"));};for(UUID user:users)if(eligible(new Actor(user,"ACTIVE","internal"),c))notify(user,"SUPPORT",uuid(c,"event_id"),null,body);}
 /** Quartz calls a transactional proxy; rows/locks persist across restarts and cluster nodes. */
 @Transactional public void tick(){
  reconcileLevels();
  for(var c:sql.queryForList("select * from platform_case where status<>'RESOLVED' and not reminded and activity_at<=now()-interval '24 hours' order by id for update skip locked")){notifyProcessors(c,"처리 요청에 24시간 동안 진행 안내가 없습니다.");notify(uuid(c,"requester_id"),"SUPPORT",uuid(c,"event_id"),null,"처리 요청을 다시 안내했습니다. 72시간 무응답이면 상향을 요청할 수 있습니다.");sql.update("update platform_case set reminded=true where id=?",uuid(c,"id"));history(uuid(c,"id"),null,"REMINDER","24시간 무응답 재안내");}
  outbox.dispatch();
 }
 /** Reconciles trusted committed finance records, under the same club→event→book lock order. */
 void reconcileLevels(){
  var books=sql.queryForList("select b.id,e.id as event_id,e.club_id from settlement_book b join club_event e on e.id=b.event_id order by e.club_id,e.id");
  for(var candidate:books)reconcileTx.executeWithoutResult(status->{
   db.lock(Club.class,uuid(candidate,"club_id"));var event=db.lock(ClubEvent.class,uuid(candidate,"event_id"));var book=sql.queryForMap("select * from settlement_book where id=? for update",uuid(candidate,"id"));
   Timestamp registered=(Timestamp)book.get("first_registered_at");Instant due=event.endsAt.plus(Duration.ofHours(72));
   if(registered!=null){var registrants=sql.queryForList("select created_by from finance_revision where book_id=? and reason='INITIAL' order by created_at,id limit 1",UUID.class,uuid(candidate,"id"));if(!registrants.isEmpty()){UUID actor=registrants.getFirst();boolean originalHost=actor.equals(event.hostId);assessLevel(event.id,event.hostId,"HOST",originalHost?(!registered.toInstant().isAfter(due)?"ON_TIME":"RECOVERED"):"HOLD",originalHost?"최초 정산 등록 시각 기준":"인계 후 등록의 주최 점수 귀속 판정 보류");}}
   else if(!due.isAfter(Instant.now()))assessLevel(event.id,event.hostId,"HOST",event.hostId.equals(event.responsibleId)?"LATE":"HOLD",event.hostId.equals(event.responsibleId)?"최초 정산 등록 72시간 경과":"담당자 인계로 판정 보류");
   var canonical=scoreSource.getIfAvailable();if(canonical!=null)canonical.reassess(event.id);
  });
 }}
