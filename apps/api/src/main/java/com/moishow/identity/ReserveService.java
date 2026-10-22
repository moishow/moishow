package com.moishow.identity;
import org.springframework.context.annotation.Profile;import org.springframework.stereotype.Service;import org.springframework.transaction.annotation.Transactional;
import java.util.*;import java.time.*;
import static com.moishow.identity.ApiProblem.require;
@Service @Profile("db")
class ReserveService {
 final Store db;final FinanceService finance;final AdvanceService advances;final BankOwnershipVerifier verifier;final BankData bank;final tools.jackson.databind.ObjectMapper json;
 ReserveService(Store db,FinanceService finance,AdvanceService advances,BankOwnershipVerifier verifier,BankData bank,tools.jackson.databind.ObjectMapper json){this.db=db;this.finance=finance;this.advances=advances;this.verifier=verifier;this.bank=bank;this.json=json;}
 long money(Long amount,boolean positive){require(amount!=null&&amount>=(positive?1:0)&&amount<=9007199254740991L,400,"INVALID_MONEY");return amount;}
 long add(long a,long b){try{return money(Math.addExact(a,b),false);}catch(ArithmeticException e){throw new ApiProblem(400,"MONEY_OVERFLOW");}}
 void actual(ReserveController.Form f){ClubService.text(f.reference(),200);require(f.actualAt()!=null&&!f.actualAt().isAfter(Instant.now()),400,"ACTUAL_TRANSACTION_REQUIRED");}
 ReserveModels.Account account(UUID club){var a=db.one(ReserveModels.Account.class,"from ReserveAccount where clubId=?1",club);require(a!=null,404,"RESERVE_NOT_CONFIGURED");return a;}
 Models.Club club(UUID id){var c=db.lock(Models.Club.class,id);require(c.status.equals("ACTIVE"),409,"CLUB_NOT_ACTIVE");return c;}
 void admin(Actor actor,UUID club){require(db.admin(club,actor.userId()),403,"CLUB_ADMIN_REQUIRED");}
 void custodian(Actor actor,ReserveModels.Account a){require(a.custodianId.equals(actor.userId())&&db.find(Models.Account.class,actor.userId()).status.equals("ACTIVE"),403,"RESERVE_CUSTODIAN_REQUIRED");}
 ReserveModels.Account write(Actor actor,UUID clubId,Long v,boolean custodian){club(clubId);var a=db.lock(ReserveModels.Account.class,account(clubId).id);if(custodian)custodian(actor,a);else admin(actor,clubId);ClubService.expected(a,v);require(!custodyInTransit(a),409,"CUSTODY_FUNDS_IN_TRANSIT");return a;}
 List<ReserveModels.Entry> entries(ReserveModels.Account a){return db.list(ReserveModels.Entry.class,"from ReserveEntry where accountId=?1 order by createdAt,id",a.id);}
 boolean pending(ReserveModels.Account a){return entries(a).stream().anyMatch(e->!Set.of("COMPLETED","CONFIRMED","CANCELLED").contains(e.status));}
 boolean custodyInTransit(ReserveModels.Account a){return !db.list(ReserveModels.Handover.class,"from ResponsibilityHandover where accountId=?1 and status='FUNDS_PENDING'",a.id).isEmpty();}
 long rawAvailable(ReserveModels.Account a){long held=0;for(var e:entries(a))if(Set.of("SPEND","DISSOLUTION","REVERSAL").contains(e.kind)&&e.status.equals("REQUESTED"))held=add(held,e.amount);return a.balance-held;}
 long available(ReserveModels.Account a){return custodyInTransit(a)||unbacked(a)>0?0:rawAvailable(a);}
 Object setup(Actor actor,UUID clubId,ReserveController.Form f){club(clubId);admin(actor,clubId);var a=db.one(ReserveModels.Account.class,"from ReserveAccount where clubId=?1",clubId);boolean fresh=a==null;
  if(a==null){require(f.version()!=null&&f.version()==0,409,"STALE_VERSION");a=new ReserveModels.Account();a.clubId=clubId;a.custodianId=actor.userId();}else{a=db.lock(ReserveModels.Account.class,a.id);custodian(actor,a);ClubService.expected(a,f.version());require(a.balance==0&&!pending(a),409,"CUSTODY_HANDOVER_REQUIRED");a.version++;}
  setBank(a,actor.userId(),f);if(fresh)db.save(a);return view(a);
 }
 void setBank(ReserveModels.Account a,UUID user,ReserveController.Form f){String name=ClubService.text(f.bankName(),100),holder=ClubService.text(f.holderName(),100),number=ClubService.text(f.accountNumber(),34);require(number.matches("[0-9]{4,34}"),400,"INVALID_ACCOUNT_NUMBER");bank.key();String proof=verifier.verify(user,name,number,holder);require(proof!=null&&!proof.isBlank(),503,"BANK_NOT_VERIFIED");a.bankName=name;a.holderName=holder;a.last4=number.substring(number.length()-4);a.accountCipher=bank.encrypt(number);a.verificationReference=proof;}
 Object deposit(Actor actor,UUID clubId,ReserveController.Form f){require(f.eventId()!=null,400,"EVENT_REQUIRED");var e=finance.locked(f.eventId());require(e.clubId.equals(clubId)&&e.responsibleId.equals(actor.userId()),403,"EVENT_RESPONSIBLE_REQUIRED");var b=db.lock(FinanceModels.Book.class,finance.book(e.id).id);var a=db.lock(ReserveModels.Account.class,account(clubId).id);require(db.find(Models.Club.class,clubId).status.equals("ACTIVE"),409,"CLUB_NOT_ACTIVE");ClubService.expected(a,f.version());require(!custodyInTransit(a),409,"CUSTODY_FUNDS_IN_TRANSIT");long amount=money(f.amount(),true),allocated=0;
  allocated=deposited(e.id,true);
  require(add(allocated,amount)<=finance.reserveAvailable(e.id),409,"AMOUNT_NOT_EARMARKED_FOR_RESERVE");var funding=finance.reconcile(e.id);require(funding.ready()&&amount<=funding.actor(actor.userId()).cashHeld()-advances.reservedCash(e.id,actor.userId()),409,"INSUFFICIENT_EVENT_CASH");
  var entry=new ReserveModels.Entry();entry.accountId=a.id;entry.eventId=e.id;entry.createdBy=actor.userId();entry.kind="DEPOSIT";entry.status="PROPOSED";entry.amount=amount;entry.purpose=ClubService.text(f.purpose(),255);entry.createdAt=Instant.now();db.save(entry);b.version++;a.version++;return entryResult(a,entry);
 }
 Object spend(Actor actor,UUID clubId,ReserveController.Form f){var a=write(actor,clubId,f.version(),false);long amount=money(f.amount(),true);require(amount<=available(a),409,"INSUFFICIENT_AVAILABLE_RESERVE");var entry=new ReserveModels.Entry();entry.accountId=a.id;entry.createdBy=actor.userId();entry.kind="SPEND";entry.status="REQUESTED";entry.amount=amount;entry.purpose=ClubService.text(f.purpose(),255);entry.createdAt=Instant.now();db.save(entry);a.version++;return entryResult(a,entry);}
 Object changeEntry(Actor actor,UUID clubId,UUID entryId,String action,ReserveController.Form f){
  // Resolve the source event before locking reserve, preserving global finance lock order.
  var original=db.find(ReserveModels.Entry.class,entryId);var initialAccount=account(clubId);require(original.accountId.equals(initialAccount.id),404,"NOT_FOUND");FinanceModels.Book book=null;
  if(original.eventId!=null){finance.locked(original.eventId);book=db.lock(FinanceModels.Book.class,finance.book(original.eventId).id);}else club(clubId);
  var a=db.lock(ReserveModels.Account.class,initialAccount.id);ClubService.expected(a,f.version());var entry=db.lock(ReserveModels.Entry.class,entryId);
  switch(action){
   case "sent"->{require(entry.kind.equals("DEPOSIT")&&entry.status.equals("PROPOSED"),409,"INVALID_ENTRY_STATE");require(db.find(Models.ClubEvent.class,entry.eventId).responsibleId.equals(actor.userId()),403,"EVENT_RESPONSIBLE_REQUIRED");actual(f);finance.claimTransaction(book,actor.userId(),entry.id,f.reference(),"MOVEMENT");entry.sentBy=actor.userId();entry.sentReference=f.reference();entry.sentAt=f.actualAt();entry.status="TRANSFER_PENDING";}
   case "confirm"->{
    require(entry.status.equals("TRANSFER_PENDING")&&Set.of("DEPOSIT","REVERSAL").contains(entry.kind),409,"ACTUAL_DEPOSIT_PENDING_REQUIRED");
    if(entry.kind.equals("DEPOSIT"))custodian(actor,a);else require(entry.recipientId.equals(actor.userId()),403,"RETURN_RECIPIENT_REQUIRED");
    actual(f);require(!f.actualAt().isBefore(entry.sentAt),400,"RECEIPT_BEFORE_SEND");entry.confirmedReference=ClubService.text(f.reference(),200);entry.actualAt=f.actualAt();entry.confirmedBy=actor.userId();
    if(entry.kind.equals("DEPOSIT")){a.balance=add(a.balance,entry.amount);entry.status="CONFIRMED";}else entry.status="COMPLETED";
   }
   case "execute","record-actual"->{
    custodian(actor,a);require(Set.of("SPEND","DISSOLUTION","REVERSAL").contains(entry.kind)&&entry.status.equals("REQUESTED"),409,"SPEND_REQUEST_REQUIRED");
    boolean recordActual=action.equals("record-actual");long deficit=unbacked(a);
    if(recordActual){require(Set.of("SPEND","DISSOLUTION").contains(entry.kind),409,"EXPLICIT_ACTUAL_RECORD_NOT_SUPPORTED");ClubService.text(f.actualRecordReason(),1000);require(f.amount()==null||f.amount()==entry.amount,400,"EXACT_ACTUAL_AMOUNT_REQUIRED");}
    else if(!entry.kind.equals("REVERSAL"))require(deficit==0,409,"RESERVE_SOURCE_DEFICIT");
    require(entry.amount<=a.balance,409,"INSUFFICIENT_RESERVE");actual(f);String reference=ClubService.text(f.reference(),200);finance.claimTransaction(book,actor.userId(),entry.id,reference,"MOVEMENT");
    entry.sentBy=actor.userId();entry.sentReference=reference;entry.sentAt=f.actualAt();entry.confirmedReference=reference;entry.actualAt=f.actualAt();entry.confirmedBy=actor.userId();
    if(recordActual){entry.actualRecordReason=ClubService.text(f.actualRecordReason(),1000);entry.actualRecordedAt=Instant.now();entry.actualRecordedBy=actor.userId();entry.unbackedAtActualRecord=deficit;}
    a.balance-=entry.amount;if(entry.kind.equals("REVERSAL")){entry.recipientId=db.find(Models.ClubEvent.class,entry.eventId).responsibleId;entry.status="TRANSFER_PENDING";}else entry.status="COMPLETED";
   }
   case "cancel"->{require(entry.status.equals("PROPOSED")||entry.status.equals("REQUESTED"),409,"TRANSACTION_ALREADY_STARTED");require((entry.eventId==null?entry.createdBy.equals(actor.userId()):db.find(Models.ClubEvent.class,entry.eventId).responsibleId.equals(actor.userId()))||a.custodianId.equals(actor.userId()),403,"ENTRY_ACTOR_REQUIRED");entry.status="CANCELLED";}
   default->throw new ApiProblem(404,"UNKNOWN_OPERATION");
  }
  a.version++;entry.version++;if(book!=null)book.version++;return entryResult(a,entry);
 }
 @Transactional(readOnly=true,isolation=org.springframework.transaction.annotation.Isolation.REPEATABLE_READ) public Object get(Actor actor,UUID clubId){var a=account(clubId);require(db.active(clubId,actor.userId())||a.custodianId.equals(actor.userId()),403,"CLUB_MEMBER_REQUIRED");var response=new LinkedHashMap<String,Object>(view(a));boolean backed=((Number)response.get("unbackedAmount")).longValue()==0;response.put("entries",entries(a).stream().map(entry->entryView(entry,actor,a,backed)).toList());var named=new HashSet<UUID>();named.add(a.custodianId);for(var entry:entries(a)){named.add(entry.createdBy);named.add(entry.sentBy);named.add(entry.confirmedBy);named.add(entry.recipientId);}response.put("names",AdvanceNames.map(db,clubId,named));return response;}
 @Transactional(readOnly=true) public Object instructions(Actor actor,UUID clubId){var a=account(clubId);boolean allowed=db.admin(clubId,actor.userId())||entries(a).stream().anyMatch(e->e.eventId!=null&&db.find(Models.ClubEvent.class,e.eventId).responsibleId.equals(actor.userId())&&e.kind.equals("DEPOSIT")&&Set.of("PROPOSED","TRANSFER_PENDING").contains(e.status));require(allowed,403,"TRANSFER_CONTEXT_REQUIRED");return Map.of("bankName",a.bankName,"holderName",a.holderName,"accountNumber",bank.decrypt(a.accountCipher));}
 Map<String,Object> view(ReserveModels.Account a){var m=new LinkedHashMap<String,Object>();m.put("id",a.id);m.put("clubId",a.clubId);m.put("custodianId",a.custodianId);m.put("bankName",a.bankName);m.put("maskedAccount","****"+a.last4);m.put("balance",a.balance);m.put("available",available(a));m.put("unbackedAmount",unbacked(a));m.put("fundsInTransit",custodyInTransit(a));m.put("version",a.version);m.put("custodianNickname",nickname(a.clubId,a.custodianId));return m;}
 String nickname(UUID club,UUID user){var m=db.member(club,user);if(m!=null&&m.nickname!=null){return m.nickname+(Set.of("LEFT","EXPELLED").contains(m.status)?" (탈퇴한 멤버)":"");}return db.find(Models.Account.class,user).nickname;}
 Map<String,Object> entryView(ReserveModels.Entry e,Actor actor,ReserveModels.Account a,boolean backed){var m=new LinkedHashMap<String,Object>();m.put("id",e.id);m.put("eventId",e.eventId);m.put("kind",e.kind);m.put("status",e.status);m.put("amount",e.amount);m.put("purpose",e.purpose);m.put("createdBy",e.createdBy);m.put("sentBy",e.sentBy);m.put("sentAt",e.sentAt);m.put("confirmedBy",e.confirmedBy);m.put("createdAt",e.createdAt);m.put("actualAt",e.actualAt);m.put("recipientId",e.recipientId);m.put("actualRecordReason",e.actualRecordReason);m.put("actualRecordedBy",e.actualRecordedBy);m.put("actualRecordedAt",e.actualRecordedAt);m.put("unbackedAtActualRecord",e.unbackedAtActualRecord);boolean owner=a.custodianId.equals(actor.userId());boolean handler=e.eventId!=null&&db.find(Models.ClubEvent.class,e.eventId).responsibleId.equals(actor.userId());m.put("canMarkSent",e.kind.equals("DEPOSIT")&&e.status.equals("PROPOSED")&&handler);m.put("canConfirm",e.status.equals("TRANSFER_PENDING")&&((e.kind.equals("DEPOSIT")&&owner)||(e.kind.equals("REVERSAL")&&actor.userId().equals(e.recipientId))));m.put("canExecute",owner&&Set.of("SPEND","DISSOLUTION","REVERSAL").contains(e.kind)&&e.status.equals("REQUESTED")&&e.amount<=a.balance&&(e.kind.equals("REVERSAL")||backed));m.put("canRecordActual",owner&&Set.of("SPEND","DISSOLUTION").contains(e.kind)&&e.status.equals("REQUESTED")&&e.amount<=a.balance);m.put("canCancel",Set.of("PROPOSED","REQUESTED").contains(e.status)&&(owner||(e.eventId==null?e.createdBy.equals(actor.userId()):handler)));return m;}
 Map<String,Object> entryResult(ReserveModels.Account a,ReserveModels.Entry e){return Map.of("id",e.id,"version",a.version,"balance",a.balance,"status",e.status);}
 Object propose(Actor actor,UUID eventId,ReserveController.Form f){var e=finance.locked(eventId);require(e.responsibleId.equals(actor.userId()),403,"EVENT_RESPONSIBLE_REQUIRED");ClubService.expected(e,f.version());var b=db.lock(FinanceModels.Book.class,finance.book(eventId).id);require(f.bookVersion()!=null&&f.bookVersion()==b.version,409,"STALE_INVENTORY");require(f.candidateId()!=null&&!f.candidateId().equals(actor.userId()),400,"INVALID_CANDIDATE");candidate(eventId,e.clubId,f.candidateId());
  require(unbackedEvent(eventId)==0,409,"RESERVE_SOURCE_DEFICIT");require(!pendingReturns(eventId),409,"HANDOVER_RETURN_PENDING");
  require(db.list(ReserveModels.Handover.class,"from ResponsibilityHandover where eventId=?1 and status='FUNDS_PENDING'",eventId).isEmpty(),409,"HANDOVER_FUNDS_PENDING");
  for(var prior:db.list(ReserveModels.Handover.class,"from ResponsibilityHandover where eventId=?1 and status='RECEIVED_STALE'",eventId))require(prior.candidateId.equals(f.candidateId()),409,"HELD_CASH_CANDIDATE_REQUIRED");
  var state=finance.reconcile(eventId);for(var holder:state.custody())if(!holder.actorId().equals(e.responsibleId)&&holder.cashHeld()>0)require(holder.actorId().equals(f.candidateId()),409,"HELD_CASH_CANDIDATE_REQUIRED");
  var h=new ReserveModels.Handover();h.eventId=eventId;h.proposerId=actor.userId();h.candidateId=f.candidateId();var inventory=inventory(e,h.candidateId);h.inventoryAmount=money(f.inventoryAmount(),false);require(h.inventoryAmount==((Number)inventory.get("cashHeld")).longValue(),409,"CASH_INVENTORY_MISMATCH");h.inventorySnapshot=json.writeValueAsString(inventory);h.inventoryNote=ClubService.text(f.inventoryNote(),1000);h.snapshotVersion=b.version;h.createdAt=Instant.now();db.save(h);return handoverView(h);
 }
 boolean candidateEligible(UUID event,UUID club,UUID candidate){return db.find(Models.Account.class,candidate).status.equals("ACTIVE")&&(db.admin(club,candidate)||!db.list(Models.Participation.class,"select p from Participation p,EventRound r where p.roundId=r.id and r.eventId=?1 and p.userId=?2 and p.everConfirmed=true",event,candidate).isEmpty());}
 void candidate(UUID event,UUID club,UUID candidate){require(candidateEligible(event,club,candidate),403,"CANDIDATE_RELATION_REQUIRED");}
 Object custodyPropose(Actor actor,UUID clubId,ReserveController.Form f){var a=write(actor,clubId,f.version(),true);require(!pending(a)&&!custodyInTransit(a)&&unbacked(a)==0,409,"PENDING_RESERVE_TRANSACTIONS");require(f.candidateId()!=null&&!f.candidateId().equals(actor.userId())&&db.admin(clubId,f.candidateId()),403,"NEW_CUSTODIAN_ADMIN_REQUIRED");var h=new ReserveModels.Handover();h.accountId=a.id;h.proposerId=actor.userId();h.candidateId=f.candidateId();h.inventoryAmount=a.balance;h.inventorySnapshot=json.writeValueAsString(Map.of("cashHeld",a.balance,"advanceLiabilities",List.of(),"ordinaryRefundLiabilities",List.of()));h.inventoryNote=ClubService.text(f.inventoryNote(),1000);h.snapshotVersion=a.version;h.createdAt=Instant.now();db.save(h);return handoverView(h);}

 Object handover(Actor actor,UUID id,String action,ReserveController.Form f){
  var original=db.find(ReserveModels.Handover.class,id);Models.ClubEvent event=null;FinanceModels.Book book=null;ReserveModels.Account account=null;
  if(original.eventId!=null){event=finance.locked(original.eventId);book=db.lock(FinanceModels.Book.class,finance.book(event.id).id);}
  else{var a=db.find(ReserveModels.Account.class,original.accountId);db.lock(Models.Club.class,a.clubId);account=db.lock(ReserveModels.Account.class,a.id);}
  var h=db.lock(ReserveModels.Handover.class,id);ClubService.expected(h,f.version());
  boolean stale=event!=null? !event.responsibleId.equals(h.proposerId)||book.version!=h.snapshotVersion : !account.custodianId.equals(h.proposerId)||account.version!=h.snapshotVersion||pending(account);
  switch(action){
   case "decline"->{require(h.candidateId.equals(actor.userId()),403,"CANDIDATE_ONLY");require(h.status.equals("PROPOSED"),409,"NOT_PROPOSED");h.status="DECLINED";}
   case "cancel"->{require(h.proposerId.equals(actor.userId()),403,"PROPOSER_ONLY");require(Set.of("PROPOSED","ACCEPTED").contains(h.status),409,"TRANSACTION_ALREADY_STARTED");h.status="CANCELLED";}
   case "accept"->{
    require(h.candidateId.equals(actor.userId()),403,"CANDIDATE_ONLY");require(h.status.equals("PROPOSED"),409,"NOT_PROPOSED");require(!stale&&h.inventorySnapshot!=null,409,"STALE_INVENTORY");
    if(event!=null)candidate(event.id,event.clubId,h.candidateId);else admin(actor,account.clubId);h.status="ACCEPTED";
   }
   case "sent"->{
    require(h.proposerId.equals(actor.userId()),403,"PROPOSER_ONLY");require(h.status.equals("ACCEPTED")&&h.inventoryAmount>0,409,"ACCEPTANCE_REQUIRED");
    if(event!=null){require(event.responsibleId.equals(h.proposerId),409,"STALE_RESPONSIBILITY");candidate(event.id,event.clubId,h.candidateId);h.requiresReacceptance=stale;}
    else{require(!stale,409,"STALE_INVENTORY");require(db.admin(account.clubId,h.candidateId)&&db.find(Models.Account.class,h.candidateId).status.equals("ACTIVE"),403,"NEW_CUSTODIAN_ADMIN_REQUIRED");}
    actual(f);finance.claimTransaction(book,actor.userId(),h.id,f.reference(),"MOVEMENT");h.sentReference=f.reference();h.sentAt=f.actualAt();h.status="FUNDS_PENDING";
    if(book!=null){book.version++;h.snapshotVersion=book.version;}else{account.version++;h.snapshotVersion=account.version;}
   }
   case "confirm"->{
    require(h.candidateId.equals(actor.userId()),403,"CANDIDATE_ONLY");boolean cashSent=h.status.equals("FUNDS_PENDING")&&h.inventoryAmount>0;
    require(cashSent||(h.inventoryAmount==0&&h.status.equals("ACCEPTED")),409,"ACTUAL_HANDOVER_PENDING");
    require(f.confirmedAmount()!=null&&f.confirmedAmount()==h.inventoryAmount,400,"EXACT_INVENTORY_CONFIRMATION_REQUIRED");
    if(!cashSent)require(!stale&&!h.requiresReacceptance,409,"STALE_INVENTORY");actual(f);
    if(cashSent)require(!f.actualAt().isBefore(h.sentAt),400,"RECEIPT_BEFORE_SEND");
    require(db.find(Models.Account.class,h.candidateId).status.equals("ACTIVE"),403,"CANDIDATE_ACCOUNT_REQUIRED");
    if(event!=null){
     boolean fresh=!stale&&!h.requiresReacceptance&&finance.reconcile(event.id).ready()&&unbackedEvent(event.id)==0&&candidateEligible(event.id,event.clubId,h.candidateId);
     if(fresh){
      candidate(event.id,event.clubId,h.candidateId);require(!pendingReturns(event.id),409,"HANDOVER_RETURN_PENDING");
      event.responsibleId=h.candidateId;event.version++;h.status="COMPLETED";
      for(var previous:db.list(ReserveModels.Handover.class,"from ResponsibilityHandover where eventId=?1 and status='RECEIVED_STALE'",event.id)){previous.status="SUPERSEDED";previous.version++;}
     }else{require(cashSent,409,"STALE_INVENTORY");h.status="RECEIVED_STALE";h.requiresReacceptance=true;}
     book.version++;
    }else{
     if(!cashSent)admin(actor,account.clubId);
     setBank(account,h.candidateId,f);account.custodianId=h.candidateId;account.version++;h.status="COMPLETED";
    }
    h.receivedReference=f.reference();h.receivedAt=f.actualAt();
   }
   default->throw new ApiProblem(404,"UNKNOWN_OPERATION");
  }
  h.version++;return handoverView(h);
 }

 Map<String,Object> handoverView(ReserveModels.Handover h){
  var m=new LinkedHashMap<String,Object>();m.put("id",h.id);m.put("eventId",h.eventId);m.put("accountId",h.accountId);m.put("proposerId",h.proposerId);m.put("candidateId",h.candidateId);m.put("inventoryAmount",h.inventoryAmount);m.put("inventoryNote",h.inventoryNote);
  UUID club=h.eventId!=null?db.find(Models.ClubEvent.class,h.eventId).clubId:db.find(ReserveModels.Account.class,h.accountId).clubId;
  var displayInventory=new LinkedHashMap<String,Object>();if(h.inventorySnapshot!=null)displayInventory.putAll(json.readValue(h.inventorySnapshot,Map.class));
  var parties=new HashSet<UUID>();parties.add(h.proposerId);parties.add(h.candidateId);if(displayInventory.get("names") instanceof Map<?,?> savedNames)for(var id:savedNames.keySet())parties.add(UUID.fromString(id.toString()));
  var names=AdvanceNames.map(db,club,parties);displayInventory.put("names",names);m.put("inventory",displayInventory);m.put("names",names);m.put("proposerNickname",AdvanceNames.view(db,club,h.proposerId).get("nickname"));m.put("candidateNickname",AdvanceNames.view(db,club,h.candidateId).get("nickname"));
  m.put("status",h.status);m.put("requiresReproposal",h.status.equals("RECEIVED_STALE"));m.put("sentAt",h.sentAt);m.put("receivedAt",h.receivedAt);m.put("returns",returns(h.id).stream().map(this::returnView).toList());m.put("version",h.version);
  if(h.eventId!=null){var funding=finance.reconcile(h.eventId);m.put("bookVersion",finance.book(h.eventId).version);m.put("currentInventory",Map.of("proposerCashHeld",funding.actor(h.proposerId).cashHeld(),"candidateCashHeld",funding.actor(h.candidateId).cashHeld(),"ready",funding.ready(),"unbackedAmount",unbackedEvent(h.eventId)));}return m;
 }
 @Transactional(readOnly=true) public Object handovers(Actor actor,UUID eventId){return db.list(ReserveModels.Handover.class,"from ResponsibilityHandover where eventId=?1 and (proposerId=?2 or candidateId=?2) order by createdAt",eventId,actor.userId()).stream().map(this::handoverView).toList();}
 @Transactional(readOnly=true) public Object mine(Actor actor){return db.list(ReserveModels.Handover.class,"from ResponsibilityHandover where (proposerId=?1 or candidateId=?1) and status not in ('COMPLETED','DECLINED','CANCELLED','SUPERSEDED','RETURNED') order by createdAt",actor.userId()).stream().map(this::handoverView).toList();}
 Object ownerPropose(Actor actor,UUID clubId,ReserveController.Form f){var c=club(clubId);require(c.ownerId.equals(actor.userId()),403,"OWNER_REQUIRED");ClubService.expected(c,f.version());require(f.candidateId()!=null&&!f.candidateId().equals(actor.userId())&&db.active(clubId,f.candidateId()),403,"ACTIVE_CANDIDATE_REQUIRED");var t=new ReserveModels.OwnerTransfer();t.clubId=clubId;t.proposerId=actor.userId();t.candidateId=f.candidateId();t.createdAt=Instant.now();db.save(t);return Map.of("id",t.id,"version",t.version,"status",t.status);}
 Object ownerAccept(Actor actor,UUID id,ReserveController.Form f){var original=db.find(ReserveModels.OwnerTransfer.class,id);var c=club(original.clubId);var t=db.lock(ReserveModels.OwnerTransfer.class,id);ClubService.expected(t,f.version());require(t.candidateId.equals(actor.userId()),403,"CANDIDATE_ONLY");require(t.status.equals("PROPOSED")&&c.ownerId.equals(t.proposerId)&&db.active(c.id,actor.userId()),409,"STALE_OWNER_TRANSFER");var previous=db.member(c.id,t.proposerId);var a=db.one(ReserveModels.Account.class,"from ReserveAccount where clubId=?1",c.id);previous.role=a!=null&&a.custodianId.equals(previous.userId)?"ADMIN":"MEMBER";previous.version++;var next=db.member(c.id,t.candidateId);next.role="OWNER";next.version++;c.ownerId=t.candidateId;c.version++;t.version++;t.status="COMPLETED";return Map.of("id",t.id,"version",t.version,"clubVersion",c.version,"status",t.status);}
 Object dissolutionPayout(Actor actor,UUID clubId,ReserveController.Form f){var c=club(clubId);require(c.ownerId.equals(actor.userId()),403,"OWNER_REQUIRED");var a=db.lock(ReserveModels.Account.class,account(clubId).id);ClubService.expected(a,f.version());require(!pending(a)&&!custodyInTransit(a)&&unbacked(a)==0&&a.balance>0,409,"RESERVE_MUST_BE_CONFIRMED");var e=new ReserveModels.Entry();e.accountId=a.id;e.createdBy=actor.userId();e.recipientId=c.ownerId;e.kind="DISSOLUTION";e.status="REQUESTED";e.amount=a.balance;e.purpose="해산 잔여 적립금 모임장 귀속";e.createdAt=Instant.now();db.save(e);a.version++;return entryResult(a,e);}
 Object dissolve(Actor actor,UUID clubId,ReserveController.Form f){var c=club(clubId);require(c.ownerId.equals(actor.userId()),403,"OWNER_REQUIRED");require(Boolean.TRUE.equals(f.ownerReceiptConfirmed()),400,"OWNER_RECEIPT_CONFIRMATION_REQUIRED");var a=db.one(ReserveModels.Account.class,"from ReserveAccount where clubId=?1",clubId);
  if(a!=null){a=db.lock(ReserveModels.Account.class,a.id);ClubService.expected(a,f.version());require(a.balance==0&&!pending(a)&&!custodyInTransit(a)&&unbacked(a)==0,409,"RESERVE_NOT_CLEARED");}
  else ClubService.expected(c,f.version());
  for(var e:db.list(Models.ClubEvent.class,"from ClubEvent where clubId=?1",clubId)){var b=db.one(FinanceModels.Book.class,"from SettlementBook where eventId=?1",e.id);require(b!=null&&b.status.equals("CLOSED")&&db.find(Models.Account.class,e.responsibleId).status.equals("ACTIVE"),409,"CALCULATION_AND_RESPONSIBLE_REQUIRED");require(deposited(e.id,false)>=finance.reserveAvailable(e.id),409,"SOURCE_RESERVE_NOT_TRANSFERRED");}
  c.status="DISSOLVED";c.version++;return Map.of("id",c.id,"status",c.status,"version",c.version);
 }
  long deposited(UUID event,boolean includePending){long total=0;for(var e:db.list(ReserveModels.Entry.class,"from ReserveEntry where eventId=?1",event)){if(e.kind.equals("DEPOSIT")&&(includePending?!e.status.equals("CANCELLED"):e.status.equals("CONFIRMED")))total=add(total,e.amount);if(e.kind.equals("REVERSAL")&&e.status.equals("COMPLETED"))total-=e.amount;}return total;}
 Object reversal(Actor actor,UUID clubId,ReserveController.Form f){require(f.eventId()!=null,400,"EVENT_REQUIRED");var event=finance.locked(f.eventId());require(event.clubId.equals(clubId),404,"NOT_FOUND");var b=db.lock(FinanceModels.Book.class,finance.book(event.id).id);var a=db.lock(ReserveModels.Account.class,account(clubId).id);admin(actor,clubId);ClubService.expected(a,f.version());long amount=money(f.amount(),true);long held=entries(a).stream().filter(e->e.kind.equals("REVERSAL")&&Set.of("REQUESTED","TRANSFER_PENDING").contains(e.status)&&event.id.equals(e.eventId)).mapToLong(e->e.amount).sum();require(!custodyInTransit(a)&&amount<=rawAvailable(a)&&amount<=deposited(event.id,false)-held,409,"REVERSAL_EXCEEDS_SOURCE_RESERVE");var entry=new ReserveModels.Entry();entry.accountId=a.id;entry.eventId=event.id;entry.recipientId=event.responsibleId;entry.createdBy=actor.userId();entry.kind="REVERSAL";entry.status="REQUESTED";entry.amount=amount;entry.purpose=ClubService.text(f.purpose(),255);entry.createdAt=Instant.now();db.save(entry);a.version++;b.version++;return entryResult(a,entry);}
 @org.springframework.context.event.EventListener public void guardFinancialChange(DomainSignals.FinancialChanged signal){if(signal.reason()!=DomainSignals.FinancialChangeReason.FACT_CORRECTION)require(deposited(signal.eventId(),true)<=finance.reserveAvailable(signal.eventId()),409,"RESERVE_REVERSAL_REQUIRED");}
 @Transactional(readOnly=true) public Object ownerTransfers(Actor actor){return db.list(ReserveModels.OwnerTransfer.class,"from ClubOwnerTransfer where (candidateId=?1 or proposerId=?1) and status='PROPOSED' order by createdAt",actor.userId()).stream().map(t->Map.of("id",t.id,"clubId",t.clubId,"proposerId",t.proposerId,"candidateId",t.candidateId,"status",t.status,"version",t.version)).toList();}
 Object delete(Actor actor){
  require(db.list(ReserveModels.Entry.class,"from ReserveEntry where kind='REVERSAL' and status='TRANSFER_PENDING' and recipientId=?1",actor.userId()).isEmpty(),409,"RESERVE_RETURN_RECEIPT_REMAINS");
  require(db.list(FinanceModels.Refund.class,"from FinanceRefund where userId=?1 and status in ('REQUESTED','SENT')",actor.userId()).isEmpty(),409,"REFUND_RECEIPT_REMAINS");
  require(db.list(ReserveModels.Handover.class,"from ResponsibilityHandover where (proposerId=?1 or candidateId=?1) and status in ('ACCEPTED','FUNDS_PENDING','RECEIVED_STALE')",actor.userId()).isEmpty(),409,"HANDOVER_RESPONSIBILITY_REMAINS");
  require(db.list(ReserveModels.FundsReturn.class,"from HandoverReturn where (senderId=?1 or recipientId=?1) and status in ('REQUESTED','SENT')",actor.userId()).isEmpty(),409,"HANDOVER_RETURN_REMAINS");
  require(db.list(AdvanceModels.Repayment.class,"from AdvanceRepayment where (creditorId=?1 or payerId=?1) and status='SENT'",actor.userId()).isEmpty(),409,"ADVANCE_RECEIPT_REMAINS");
  for(var book:db.list(FinanceModels.Book.class,"from SettlementBook")){
   var state=finance.reconcile(book.eventId);
   require(state.position(actor.userId()).advanceDue()==0&&state.actor(actor.userId()).cashHeld()==0,409,"ADVANCE_OR_EVENT_CASH_REMAINS");
   for(var id:state.unclassifiedExpenses()){var expense=db.find(FinanceModels.Expense.class,id);require(!actor.userId().equals(expense.paidByUserId),409,"FUNDING_CLASSIFICATION_REQUIRED");}
  }
require(db.list(Models.Club.class,"from Club where ownerId=?1 and status<>'DISSOLVED'",actor.userId()).isEmpty(),409,"CLUB_OWNER_TRANSFER_REQUIRED");
  for(var a:db.list(ReserveModels.Account.class,"from ReserveAccount where custodianId=?1",actor.userId()))require(db.find(Models.Club.class,a.clubId).status.equals("DISSOLVED")&&a.balance==0&&!pending(a),409,"RESERVE_CUSTODY_REMAINS");
  for(var e:db.list(Models.ClubEvent.class,"from ClubEvent where responsibleId=?1",actor.userId()))require(!finance.hasOutstanding(e.id)&&deposited(e.id,false)>=finance.reserveAvailable(e.id),409,"SETTLEMENT_RESPONSIBILITY_REMAINS");
  var user=db.lock(Models.Account.class,actor.userId());for(var m:db.list(Models.Membership.class,"from Membership where userId=?1 and status in ('ACTIVE','PENDING')",actor.userId())){m.status="LEFT";m.role="MEMBER";m.version++;}user.status="DELETED";user.phone=null;user.version++;for(var s:db.list(Models.ServiceSession.class,"from ServiceSession where userId=?1",actor.userId()))s.revoked=true;return Map.of("deleted",true);
 }

 Map<String,Object> inventory(Models.ClubEvent e,UUID candidate){
  var state=finance.reconcile(e.id);require(state.ready(),409,"FUNDING_RECONCILIATION_REQUIRED");
  long cash=state.actor(e.responsibleId).cashHeld();require(cash>=0,409,"NEGATIVE_CASH_INVENTORY");
  var m=new LinkedHashMap<String,Object>();m.put("cashHeld",cash);m.put("proposerCashHeld",cash);m.put("candidateCashHeld",state.actor(candidate).cashHeld());m.put("custody",state.custody());
  m.put("advanceLiabilities",advances.liabilities(e.id));m.put("collectionDuties",state.positions().stream().filter(p->p.additional()>0).map(p->Map.of("userId",p.userId(),"amount",p.additional())).toList());m.put("calculationStatus",finance.book(e.id).status);m.put("finalDeadline",finance.book(e.id).finalDeadline);m.put("ordinaryRefundLiabilities",state.positions().stream().filter(p->p.ordinaryRefundDue()>0).map(p->Map.of("userId",p.userId(),"amount",p.ordinaryRefundDue())).toList());
  var pending=new ArrayList<Map<String,Object>>();
  for(var r:advances.repayments(e.id))if(Set.of("REQUESTED","SENT").contains(r.status))pending.add(Map.of("id",r.id,"kind","ADVANCE_REPAYMENT","status",r.status,"amount",r.amount,"creditorId",r.creditorId));
  for(var r:finance.reports(finance.book(e.id)))if(r.status.equals("PENDING"))pending.add(Map.of("id",r.id,"kind","RECEIPT_REPORT","status",r.status,"amount",r.reportedAmount,"userId",r.userId));
  for(var r:finance.refunds(finance.book(e.id)))if(!r.status.equals("CONFIRMED"))pending.add(Map.of("id",r.id,"kind","ORDINARY_REFUND","status",r.status,"amount",r.amount,"userId",r.userId));
  for(var r:db.list(ReserveModels.Entry.class,"from ReserveEntry where eventId=?1",e.id))if(!Set.of("COMPLETED","CONFIRMED","CANCELLED").contains(r.status))pending.add(Map.of("id",r.id,"kind",r.kind,"status",r.status,"amount",r.amount));
  var namedUsers=new HashSet<UUID>();namedUsers.add(e.responsibleId);namedUsers.add(candidate);for(var p:state.positions())namedUsers.add(p.userId());for(var holder:state.custody())namedUsers.add(holder.actorId());m.put("names",AdvanceNames.map(db,e.clubId,namedUsers));m.put("pendingTransactions",pending);m.put("openDisputes",db.list(FinanceModels.Dispute.class,"from FinanceDispute where bookId=?1 and status in ('OPEN','REVIEWING')",finance.book(e.id).id).stream().map(d->Map.of("id",d.id,"status",d.status)).toList());return m;
 }

 long unbackedEvent(UUID event){return Math.max(0,deposited(event,true)-finance.reserveAvailable(event));}
 long unbacked(ReserveModels.Account a){long total=0;var events=new HashSet<UUID>();for(var entry:entries(a))if(entry.eventId!=null&&entry.kind.equals("DEPOSIT"))events.add(entry.eventId);for(var event:events)total=add(total,unbackedEvent(event));return total;}
 List<ReserveModels.FundsReturn> returns(UUID handover){return db.list(ReserveModels.FundsReturn.class,"from HandoverReturn where handoverId=?1 order by createdAt,id",handover);}
 boolean pendingReturns(UUID event){return !db.list(ReserveModels.FundsReturn.class,"from HandoverReturn where eventId=?1 and status in ('REQUESTED','SENT')",event).isEmpty();}
 Map<String,Object> returnView(ReserveModels.FundsReturn r){var m=new LinkedHashMap<String,Object>();m.put("id",r.id);m.put("eventId",r.eventId);m.put("senderId",r.senderId);m.put("kind",r.kind);m.put("recipientId",r.recipientId);m.put("amount",r.amount);m.put("status",r.status);m.put("createdAt",r.createdAt);m.put("sentAt",r.sentAt);m.put("receivedAt",r.receivedAt);return m;}
 Object requestReturn(Actor actor,UUID handover,ReserveController.ReturnForm f){
  var h=db.find(ReserveModels.Handover.class,handover);require(h.eventId!=null,400,"EVENT_HANDOVER_REQUIRED");finance.locked(h.eventId);var book=db.lock(FinanceModels.Book.class,finance.book(h.eventId).id);ClubService.expected(book,f.version());h=db.lock(ReserveModels.Handover.class,h.id);
  require(h.candidateId.equals(actor.userId()),403,"CANDIDATE_ONLY");require(h.status.equals("RECEIVED_STALE")&&h.receivedAt!=null,409,"STALE_RECEIPT_REQUIRED");
  long amount=money(f.amount(),true),committed=0;for(var r:returns(h.id))if(!r.status.equals("CANCELLED"))committed=add(committed,r.amount);
  var state=finance.reconcile(h.eventId);require(state.unclassifiedExpenses().isEmpty(),409,"FUNDING_CLASSIFICATION_REQUIRED");long held=state.actor(actor.userId()).cashHeld(),reserved=0;for(var pending:db.list(ReserveModels.FundsReturn.class,"from HandoverReturn where eventId=?1 and senderId=?2 and status='REQUESTED'",h.eventId,actor.userId()))reserved=add(reserved,pending.amount);require(amount<=h.inventoryAmount-committed&&amount<=held-reserved,409,"RETURN_EXCEEDS_HELD_CASH");
  var r=new ReserveModels.FundsReturn();r.handoverId=h.id;r.eventId=h.eventId;r.senderId=actor.userId();r.recipientId=h.proposerId;r.amount=amount;r.reason=ClubService.text(f.reason(),1000);r.createdAt=Instant.now();db.save(r);book.version++;return Map.of("id",r.id,"version",book.version,"status",r.status);
 }

 Object changeReturn(Actor actor,UUID handover,UUID id,String action,ReserveController.ReturnForm f){
  var h=db.find(ReserveModels.Handover.class,handover);require(h.eventId!=null,400,"EVENT_HANDOVER_REQUIRED");return changeCashRecord(actor,h.eventId,handover,id,action,f);
 }
 Object changeCashRecord(Actor actor,UUID event,UUID handover,UUID id,String action,ReserveController.ReturnForm f){
  finance.locked(event);var book=db.lock(FinanceModels.Book.class,finance.book(event).id);ClubService.expected(book,f.version());var r=db.lock(ReserveModels.FundsReturn.class,id);require(r.eventId.equals(event)&&Objects.equals(r.handoverId,handover),404,"NOT_FOUND");
  if(handover==null)require(r.kind.equals("CUSTODY_TRANSFER"),404,"NOT_FOUND");
  switch(action){
   case "sent"->{require(r.senderId.equals(actor.userId()),403,"RETURN_SENDER_ONLY");require(r.status.equals("REQUESTED"),409,"RETURN_NOT_REQUESTED");actualReturn(f);finance.claimTransaction(book,actor.userId(),r.id,f.reference(),"MOVEMENT");r.sentReference=f.reference();r.sentAt=f.actualAt();r.status="SENT";}
   case "confirm"->{require(r.recipientId.equals(actor.userId()),403,"RETURN_RECIPIENT_ONLY");require(r.status.equals("SENT"),409,"ACTUAL_RETURN_PENDING");actualReturn(f);require(!f.actualAt().isBefore(r.sentAt),400,"RECEIPT_BEFORE_SEND");r.receivedReference=f.reference();r.receivedAt=f.actualAt();r.status="CONFIRMED";
    if(handover!=null){var h=db.lock(ReserveModels.Handover.class,handover);long received=0;for(var prior:returns(handover))if(prior.status.equals("CONFIRMED"))received=add(received,prior.amount);if(received==h.inventoryAmount){h.status="RETURNED";h.version++;}}
   }
   case "cancel"->{require(r.senderId.equals(actor.userId()),403,"RETURN_SENDER_ONLY");require(r.status.equals("REQUESTED"),409,"TRANSACTION_ALREADY_STARTED");r.status="CANCELLED";}
   default->throw new ApiProblem(404,"UNKNOWN_OPERATION");
  }
  r.version++;book.version++;return Map.of("id",r.id,"version",book.version,"status",r.status);
 }
 Object requestCashTransfer(Actor actor,UUID event,ReserveController.ReturnForm f){
  var book=finance.write(actor,event,f.version(),false);var e=db.find(Models.ClubEvent.class,event);require(!e.responsibleId.equals(actor.userId()),409,"RESPONSIBLE_ALREADY_HOLDS_CASH");var state=finance.reconcile(event);require(state.unclassifiedExpenses().isEmpty(),409,"FUNDING_CLASSIFICATION_REQUIRED");
  long amount=money(f.amount(),true),reserved=0;for(var r:db.list(ReserveModels.FundsReturn.class,"from HandoverReturn where eventId=?1 and senderId=?2 and status='REQUESTED'",event,actor.userId()))reserved=add(reserved,r.amount);
  require(amount<=state.actor(actor.userId()).cashHeld()-reserved,409,"TRANSFER_EXCEEDS_HELD_CASH");require(db.find(Models.Account.class,e.responsibleId).status.equals("ACTIVE"),409,"ACTIVE_RESPONSIBLE_REQUIRED");
  var r=new ReserveModels.FundsReturn();r.eventId=event;r.senderId=actor.userId();r.recipientId=e.responsibleId;r.kind="CUSTODY_TRANSFER";r.amount=amount;r.reason=ClubService.text(f.reason(),1000);r.createdAt=Instant.now();db.save(r);book.version++;return Map.of("id",r.id,"version",book.version,"status",r.status);
 }
 @Transactional(readOnly=true,isolation=org.springframework.transaction.annotation.Isolation.REPEATABLE_READ) public Object cashTransfers(Actor actor,UUID event){
  var e=db.find(Models.ClubEvent.class,event);require(advances.canRead(actor,event),403,"FINANCE_ACCESS_DENIED");boolean all=e.responsibleId.equals(actor.userId())||db.active(e.clubId,actor.userId());var visible=db.list(ReserveModels.FundsReturn.class,"from HandoverReturn where eventId=?1 and kind='CUSTODY_TRANSFER' order by createdAt,id",event).stream().filter(r->all||r.senderId.equals(actor.userId())||r.recipientId.equals(actor.userId())).toList();var named=new HashSet<UUID>();for(var row:visible){named.add(row.senderId);named.add(row.recipientId);}
  return Map.of("eventId",event,"responsibleId",e.responsibleId,"version",finance.book(event).version,"transfers",visible.stream().map(this::returnView).toList(),"names",AdvanceNames.map(db,e.clubId,named));
 }
 void actualReturn(ReserveController.ReturnForm f){ClubService.text(f.reference(),200);require(f.actualAt()!=null&&!f.actualAt().isAfter(Instant.now()),400,"ACTUAL_TRANSACTION_REQUIRED");}

 @Transactional(readOnly=true,isolation=org.springframework.transaction.annotation.Isolation.REPEATABLE_READ) public Object candidates(Actor actor,UUID event){
  var e=db.find(Models.ClubEvent.class,event);require(e.responsibleId.equals(actor.userId()),403,"EVENT_RESPONSIBLE_REQUIRED");
  var ids=new TreeSet<UUID>();for(var member:db.list(Models.Membership.class,"from Membership where clubId=?1 and status='ACTIVE' and role in ('OWNER','ADMIN')",e.clubId))ids.add(member.userId);
  for(var participant:finance.participants(event))ids.add(participant.userId);ids.remove(actor.userId());
  var choices=new ArrayList<Map<String,Object>>();for(var id:ids)if(candidateEligible(event,e.clubId,id)){var member=db.member(e.clubId,id);boolean departed=member!=null&&Set.of("LEFT","EXPELLED").contains(member.status);String display=member!=null&&member.nickname!=null&&Set.of("ACTIVE","LEFT","EXPELLED").contains(member.status)?member.nickname:db.find(Models.Account.class,id).nickname;choices.add(Map.of("id",id,"nickname",display,"departed",departed));}return choices;
 }

 @Transactional(readOnly=true,isolation=org.springframework.transaction.annotation.Isolation.REPEATABLE_READ) public Object transferContext(Actor actor,UUID event){
  var e=db.find(Models.ClubEvent.class,event);require(e.responsibleId.equals(actor.userId()),403,"EVENT_RESPONSIBLE_REQUIRED");var a=account(e.clubId);var state=finance.reconcile(event);
  long source=Math.max(0,finance.reserveAvailable(event)-deposited(event,true));long cash=Math.max(0,state.actor(actor.userId()).cashHeld()-advances.reservedCash(event,actor.userId()));boolean canDeposit=db.find(Models.Club.class,e.clubId).status.equals("ACTIVE")&&!custodyInTransit(a)&&state.ready()&&source>0&&cash>0;
  return Map.of("clubId",e.clubId,"reserveVersion",a.version,"bankName",a.bankName,"maskedAccount","****"+a.last4,"sourceAvailable",source,"maxTransferable",Math.min(source,cash),"canDeposit",canDeposit);
 }
}
