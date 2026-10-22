package com.moishow.identity;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;
import java.nio.charset.StandardCharsets;
import java.util.*;

/** Store-only journal projection: never calls Finance and never synthesizes bank receipts. */
@Component @Profile("db")
class AdvanceFundingLedger implements FinanceFundingFacts {
 final Store db;
 AdvanceFundingLedger(Store db){this.db=db;}
 UUID movementId(UUID id,String direction){return UUID.nameUUIDFromBytes((id+":"+direction).getBytes(StandardCharsets.UTF_8));}
 public Snapshot facts(UUID event){
  var movements=new ArrayList<Movement>();var recoveries=new ArrayList<Recovery>();
  for(var h:db.list(ReserveModels.Handover.class,"from ResponsibilityHandover where eventId=?1",event)){
   if(h.inventoryAmount>0&&h.sentAt!=null)movements.add(new Movement(movementId(h.id,"HANDOVER_OUT"),h.proposerId,-h.inventoryAmount,"HANDOVER_SENT"));
   if(h.inventoryAmount>0&&h.receivedAt!=null)movements.add(new Movement(movementId(h.id,"HANDOVER_IN"),h.candidateId,h.inventoryAmount,"HANDOVER_RECEIVED"));
  }
  for(var e:db.list(ReserveModels.Entry.class,"from ReserveEntry where eventId=?1",event)){
   if(e.kind.equals("DEPOSIT")&&e.sentAt!=null)movements.add(new Movement(movementId(e.id,"RESERVE_OUT"),e.sentBy==null?e.createdBy:e.sentBy,-e.amount,"RESERVE_SENT"));
   if(e.kind.equals("REVERSAL")&&e.status.equals("COMPLETED"))movements.add(new Movement(movementId(e.id,"RESERVE_RETURN"),e.recipientId,e.amount,"RESERVE_RETURN_RECEIVED"));
  }
  for(var r:db.list(AdvanceModels.Repayment.class,"from AdvanceRepayment where eventId=?1",event))if(r.sentAt!=null){
   movements.add(new Movement(movementId(r.id,"ADVANCE_OUT"),r.payerId,-r.amount,"ADVANCE_SENT"));
   recoveries.add(new Recovery(r.id,r.creditorId,r.amount,"ADVANCE_SENT"));
  }
  for(var r:db.list(AdvanceModels.Recovery.class,"from AdvanceRecovery where eventId=?1",event)){
   movements.add(new Movement(movementId(r.id,"SELF_RECOVERY"),r.actorId,-r.amount,"SELF_RECOVERY"));recoveries.add(new Recovery(r.id,r.actorId,r.amount,"SELF_RECOVERY"));
  }
  for(var r:db.list(ReserveModels.FundsReturn.class,"from HandoverReturn where eventId=?1",event)){
   if(r.sentAt!=null)movements.add(new Movement(movementId(r.id,"HANDOVER_RETURN_OUT"),r.senderId,-r.amount,r.kind+"_SENT"));
   if(r.receivedAt!=null)movements.add(new Movement(movementId(r.id,"HANDOVER_RETURN_IN"),r.recipientId,r.amount,r.kind+"_RECEIVED"));
  }
  return new Snapshot(event,movements,recoveries);
 }

 public boolean hasFinancialRelationship(UUID event,UUID user){
  if(!db.list(ReserveModels.Handover.class,"from ResponsibilityHandover where eventId=?1 and (proposerId=?2 or candidateId=?2) and status in ('ACCEPTED','FUNDS_PENDING','RECEIVED_STALE','COMPLETED','SUPERSEDED','RETURNED')",event,user).isEmpty())return true;
  if(!db.list(ReserveModels.FundsReturn.class,"from HandoverReturn where eventId=?1 and (senderId=?2 or recipientId=?2)",event,user).isEmpty())return true;
  return !db.list(AdvanceModels.Repayment.class,"from AdvanceRepayment where eventId=?1 and (creditorId=?2 or payerId=?2)",event,user).isEmpty();
 }
}
