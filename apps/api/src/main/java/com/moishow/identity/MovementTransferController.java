package com.moishow.identity;

import java.util.*;
import org.springframework.context.annotation.Profile;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.*;
import org.springframework.web.bind.annotation.*;
import static com.moishow.identity.ApiProblem.require;

/** Private, read-only instructions for a single still-unsent movement. */
@RestController @Profile("db") @RequestMapping("/api/v1")
@Transactional(readOnly=true,isolation=Isolation.REPEATABLE_READ)
class MovementTransferController {
 private final Store db;private final FinanceService finance;private final ReserveService reserve;private final AdvanceService advances;private final PersonalBankService bank;
 MovementTransferController(Store db,FinanceService finance,ReserveService reserve,AdvanceService advances,PersonalBankService bank){this.db=db;this.finance=finance;this.reserve=reserve;this.advances=advances;this.bank=bank;}
 ResponseEntity<Object> instructions(UUID recipient,long amount,String purpose,UUID event,UUID source,long bookVersion){
  var result=bank.transferAccount(recipient);result.put("amount",amount);result.put("purpose",purpose);result.put("eventId",event);result.put("sourceId",source);result.put("bookVersion",bookVersion);return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(result);
 }
 @GetMapping("/handovers/{id}/transfer-instructions")
 public ResponseEntity<Object> handover(@AuthenticationPrincipal Actor actor,@PathVariable UUID id){
  var h=db.find(ReserveModels.Handover.class,id);require(h.eventId!=null,404,"EVENT_HANDOVER_REQUIRED");require(h.proposerId.equals(actor.userId()),403,"PROPOSER_ONLY");
  require(h.status.equals("ACCEPTED"),409,"ACCEPTANCE_REQUIRED");require(h.inventoryAmount>0,409,"EXTERNAL_TRANSFER_NOT_REQUIRED");
  var event=db.find(Models.ClubEvent.class,h.eventId);var book=finance.book(event.id);require(event.responsibleId.equals(actor.userId()),403,"EVENT_RESPONSIBLE_REQUIRED");
  require(book.version==h.snapshotVersion&&h.inventorySnapshot!=null&&!h.requiresReacceptance,409,"STALE_INVENTORY");reserve.candidate(event.id,event.clubId,h.candidateId);
  var state=finance.reconcile(event.id);require(state.ready()&&state.actor(actor.userId()).cashHeld()==h.inventoryAmount&&reserve.unbackedEvent(event.id)==0,409,"STALE_INVENTORY");
  return instructions(h.candidateId,h.inventoryAmount,"HANDOVER",event.id,h.id,book.version);
 }
 @GetMapping("/custodian-handovers/{id}/transfer-instructions")
 public ResponseEntity<Object> custodian(@AuthenticationPrincipal Actor actor,@PathVariable UUID id){
  var h=db.find(ReserveModels.Handover.class,id);require(h.accountId!=null&&h.eventId==null,404,"CUSTODIAN_HANDOVER_REQUIRED");require(h.proposerId.equals(actor.userId()),403,"PROPOSER_ONLY");
  require(h.status.equals("ACCEPTED"),409,"ACCEPTANCE_REQUIRED");require(h.inventoryAmount>0,409,"EXTERNAL_TRANSFER_NOT_REQUIRED");var account=db.find(ReserveModels.Account.class,h.accountId);reserve.custodian(actor,account);
  require(account.version==h.snapshotVersion&&h.inventorySnapshot!=null&&!reserve.pending(account)&&account.balance==h.inventoryAmount&&reserve.unbacked(account)==0,409,"STALE_INVENTORY");
  require(db.admin(account.clubId,h.candidateId)&&db.find(Models.Account.class,h.candidateId).status.equals("ACTIVE"),403,"NEW_CUSTODIAN_ADMIN_REQUIRED");
  var result=bank.transferAccount(h.candidateId);result.put("purpose","CUSTODIAN_HANDOVER");result.put("sourceId",h.id);result.put("amount",h.inventoryAmount);result.put("clubId",account.clubId);result.put("reserveVersion",account.version);return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(result);
 }
 @GetMapping("/events/{eventId}/advances/repayments/{repaymentId}/transfer-instructions")
 public ResponseEntity<Object> repayment(@AuthenticationPrincipal Actor actor,@PathVariable UUID eventId,@PathVariable UUID repaymentId){
  var event=db.find(Models.ClubEvent.class,eventId);var row=db.find(AdvanceModels.Repayment.class,repaymentId);require(row.eventId.equals(eventId),404,"REPAYMENT_NOT_FOUND");require(event.responsibleId.equals(actor.userId()),403,"EVENT_RESPONSIBLE_REQUIRED");
  require(row.status.equals("REQUESTED")&&row.amount>0,409,"REPAYMENT_NOT_REQUESTED");require(!row.creditorId.equals(actor.userId()),409,"SELF_RECOVERY_REQUIRED");var state=finance.reconcile(eventId);
  require(state.ready(),409,"FUNDING_RECONCILIATION_REQUIRED");require(row.amount<=state.position(row.creditorId).advanceDue()-(advances.pending(eventId,row.creditorId)-row.amount),409,"REPAYMENT_EXCEEDS_ADVANCE");
  require(row.amount<=state.actor(actor.userId()).cashHeld()-(advances.reservedCash(eventId,actor.userId())-row.amount),409,"INSUFFICIENT_EVENT_CASH");return instructions(row.creditorId,row.amount,"ADVANCE_REPAYMENT",eventId,row.id,finance.book(eventId).version);
 }
 @GetMapping("/events/{eventId}/custody-transfers/{transferId}/transfer-instructions")
 public ResponseEntity<Object> custodyTransfer(@AuthenticationPrincipal Actor actor,@PathVariable UUID eventId,@PathVariable UUID transferId){
  var row=db.find(ReserveModels.FundsReturn.class,transferId);require(row.eventId.equals(eventId)&&row.handoverId==null&&row.kind.equals("CUSTODY_TRANSFER"),404,"TRANSFER_NOT_FOUND");return cashInstructions(actor,row);
 }
 @GetMapping("/handovers/{handoverId}/returns/{returnId}/transfer-instructions")
 public ResponseEntity<Object> fundsReturn(@AuthenticationPrincipal Actor actor,@PathVariable UUID handoverId,@PathVariable UUID returnId){
  var row=db.find(ReserveModels.FundsReturn.class,returnId);require(Objects.equals(row.handoverId,handoverId)&&row.kind.equals("HANDOVER_RETURN"),404,"RETURN_NOT_FOUND");return cashInstructions(actor,row);
 }
 ResponseEntity<Object> cashInstructions(Actor actor,ReserveModels.FundsReturn row){
  require(row.senderId.equals(actor.userId()),403,"RETURN_SENDER_ONLY");require(row.status.equals("REQUESTED")&&row.amount>0,409,"RETURN_NOT_REQUESTED");var state=finance.reconcile(row.eventId);require(state.unclassifiedExpenses().isEmpty(),409,"FUNDING_CLASSIFICATION_REQUIRED");
  long reserved=0;for(var pending:db.list(ReserveModels.FundsReturn.class,"from HandoverReturn where eventId=?1 and senderId=?2 and status='REQUESTED'",row.eventId,actor.userId()))if(!pending.id.equals(row.id))reserved=finance.add(reserved,pending.amount);
  require(row.amount<=state.actor(actor.userId()).cashHeld()-reserved,409,"TRANSFER_EXCEEDS_HELD_CASH");return instructions(row.recipientId,row.amount,row.kind,row.eventId,row.id,finance.book(row.eventId).version);
 }
}
