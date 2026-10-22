package com.moishow.identity;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.Instant;
import java.util.*;
import static com.moishow.identity.ApiProblem.require;

@Service @Profile("db")
class AdvanceService {
 final Store db; final FinanceService finance; final EventService events;
 AdvanceService(Store db,FinanceService finance,EventService events){this.db=db;this.finance=finance;this.events=events;}
 List<AdvanceModels.Repayment> repayments(UUID event){return db.list(AdvanceModels.Repayment.class,"from AdvanceRepayment where eventId=?1 order by createdAt,id",event);}
 List<AdvanceModels.Recovery> recoveries(UUID event){return db.list(AdvanceModels.Recovery.class,"from AdvanceRecovery where eventId=?1 order by createdAt,id",event);}
 long pending(UUID event,UUID creditor){long sum=0;for(var r:repayments(event))if(r.status.equals("REQUESTED")&&(creditor==null||r.creditorId.equals(creditor)))sum=finance.add(sum,r.amount);return sum;}
 void actual(AdvanceController.Form f){ClubService.text(f.reference(),200);require(f.actualAt()!=null&&!f.actualAt().isAfter(Instant.now()),400,"ACTUAL_TRANSACTION_REQUIRED");}
 Map<String,Object> result(FinanceModels.Book book,UUID id,String status){finance.result(book,id,Set.of("SENT","CONFIRMED","SELF_RECOVERY").contains(status)?DomainSignals.FinancialChangeReason.FACT_CORRECTION:DomainSignals.FinancialChangeReason.ALLOCATION_CHANGE);return Map.of("id",id,"version",book.version,"status",status);}
 Object recover(Actor actor,UUID event,AdvanceController.Form f){
  var book=finance.write(actor,event,f.version(),true);var state=finance.reconcile(event);require(state.ready(),409,"FUNDING_RECONCILIATION_REQUIRED");
  long amount=finance.money(f.amount(),true);var position=state.position(actor.userId());var held=state.actor(actor.userId());
  require(amount<=position.advanceDue()&&amount<=held.cashHeld()-reservedCash(event,actor.userId()),409,"RECOVERY_EXCEEDS_AVAILABLE_ADVANCE");
  var row=new AdvanceModels.Recovery();row.eventId=event;row.actorId=actor.userId();row.amount=amount;row.reason=ClubService.text(f.reason(),1000);row.createdAt=Instant.now();db.save(row);
  return result(book,row.id,row.kind);
 }
 Object request(Actor actor,UUID event,AdvanceController.Form f){
  var book=finance.write(actor,event,f.version(),true);var state=finance.reconcile(event);require(state.ready(),409,"FUNDING_RECONCILIATION_REQUIRED");
  require(f.creditorId()!=null&&!f.creditorId().equals(actor.userId()),400,"EXTERNAL_CREDITOR_REQUIRED");
  long amount=finance.money(f.amount(),true);require(amount<=state.position(f.creditorId()).advanceDue()-pending(event,f.creditorId()),409,"REPAYMENT_EXCEEDS_ADVANCE");
  require(amount<=state.actor(actor.userId()).cashHeld()-reservedCash(event,actor.userId()),409,"INSUFFICIENT_EVENT_CASH");
  var row=new AdvanceModels.Repayment();row.eventId=event;row.creditorId=f.creditorId();row.createdBy=actor.userId();row.amount=amount;row.reason=ClubService.text(f.reason(),1000);row.createdAt=Instant.now();db.save(row);
  return result(book,row.id,row.status);
 }
 Object change(Actor actor,UUID event,UUID id,String action,AdvanceController.Form f){
  var e=finance.locked(event);var book=db.lock(FinanceModels.Book.class,finance.book(event).id);ClubService.expected(book,f.version());
  var r=db.lock(AdvanceModels.Repayment.class,id);require(r.eventId.equals(event),404,"NOT_FOUND");
  switch(action){
   case "sent"->{finance.manager(actor,e);require(r.status.equals("REQUESTED"),409,"REPAYMENT_NOT_REQUESTED");require(!r.creditorId.equals(actor.userId()),409,"SELF_RECOVERY_REQUIRED");actual(f);finance.claimTransaction(book,actor.userId(),r.id,f.reference(),"MOVEMENT");r.sentReference=f.reference();r.sentAt=f.actualAt();r.payerId=actor.userId();r.status="SENT";}
   case "confirm"->{require(r.creditorId.equals(actor.userId()),403,"CREDITOR_ONLY");require(r.status.equals("SENT"),409,"ACTUAL_REPAYMENT_PENDING");actual(f);require(!f.actualAt().isBefore(r.sentAt),400,"RECEIPT_BEFORE_SEND");r.receivedReference=f.reference();r.confirmedAt=f.actualAt();r.status="CONFIRMED";}
   case "cancel"->{finance.manager(actor,e);require(r.status.equals("REQUESTED"),409,"TRANSACTION_ALREADY_STARTED");r.status="CANCELLED";}
   default->throw new ApiProblem(404,"UNKNOWN_OPERATION");
  }
  r.version++;return result(book,r.id,r.status);
 }
 List<Map<String,Object>> liabilities(UUID event){return finance.reconcile(event).positions().stream().filter(p->p.advanceDue()>0).map(p->Map.<String,Object>of("creditorId",p.userId(),"amount",p.advanceDue())).toList();}
 boolean pendingDuty(UUID event){return repayments(event).stream().anyMatch(r->Set.of("REQUESTED","SENT").contains(r.status));}
 @Transactional(readOnly=true,isolation=org.springframework.transaction.annotation.Isolation.REPEATABLE_READ) public Object get(Actor actor,UUID event){
  var e=db.find(Models.ClubEvent.class,event);require(events.financial(actor,e),403,"FINANCE_ACCESS_DENIED");var state=finance.reconcile(event);boolean all=e.responsibleId.equals(actor.userId())||db.active(e.clubId,actor.userId());
  var response=new LinkedHashMap<String,Object>();response.put("eventId",event);response.put("version",finance.book(event).version);response.put("responsibleId",e.responsibleId);response.put("ready",state.ready());
  response.put("liabilities",liabilities(event).stream().filter(p->all||p.get("creditorId").equals(actor.userId())).toList());
  response.put("custody",state.custody().stream().filter(p->all||p.actorId().equals(actor.userId())).toList());
  response.put("repayments",repayments(event).stream().filter(r->all||r.creditorId.equals(actor.userId())||actor.userId().equals(r.payerId)||r.createdBy.equals(actor.userId())).map(r->repaymentView(r,actor,e)).toList());
  var namedUsers=new HashSet<UUID>();namedUsers.add(e.responsibleId);for(var position:state.positions())if(all||position.userId().equals(actor.userId()))namedUsers.add(position.userId());for(var r:repayments(event))if(all||r.creditorId.equals(actor.userId())||actor.userId().equals(r.payerId)||r.createdBy.equals(actor.userId())){namedUsers.add(r.creditorId);namedUsers.add(r.payerId);namedUsers.add(r.createdBy);}for(var r:recoveries(event))if(all||r.actorId.equals(actor.userId()))namedUsers.add(r.actorId);response.put("names",AdvanceNames.map(db,e.clubId,namedUsers));
  response.put("recoveries",recoveries(event).stream().filter(r->all||r.actorId.equals(actor.userId())).map(r->Map.of("id",r.id,"eventId",r.eventId,"actorId",r.actorId,"amount",r.amount,"kind",r.kind,"createdAt",r.createdAt)).toList());return response;
 }
 Map<String,Object> repaymentView(AdvanceModels.Repayment r,Actor actor,Models.ClubEvent e){
  var m=new LinkedHashMap<String,Object>();m.put("id",r.id);m.put("eventId",r.eventId);m.put("creditorId",r.creditorId);m.put("payerId",r.payerId);m.put("createdBy",r.createdBy);m.put("amount",r.amount);m.put("status",r.status);m.put("createdAt",r.createdAt);m.put("sentAt",r.sentAt);m.put("confirmedAt",r.confirmedAt);
  if(e.responsibleId.equals(actor.userId())||r.creditorId.equals(actor.userId())||actor.userId().equals(r.payerId)){m.put("reason",r.reason);m.put("sentReference",r.sentReference);m.put("receivedReference",r.receivedReference);}return m;
 }

 long reservedCash(UUID event,UUID actor){
  long total=pending(event,null);var book=finance.book(event);
  for(var r:finance.refunds(book))if(r.status.equals("REQUESTED"))total=finance.add(total,r.amount);
  for(var r:db.list(ReserveModels.Entry.class,"from ReserveEntry where eventId=?1 and kind='DEPOSIT' and status='PROPOSED'",event))total=finance.add(total,r.amount);
  for(var r:db.list(ReserveModels.FundsReturn.class,"from HandoverReturn where eventId=?1 and senderId=?2 and status='REQUESTED'",event,actor))total=finance.add(total,r.amount);
  return total;
 }

 boolean canRead(Actor actor,UUID event){return events.financial(actor,db.find(Models.ClubEvent.class,event));}
}
