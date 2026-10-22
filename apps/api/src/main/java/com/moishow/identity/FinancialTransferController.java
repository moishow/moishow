package com.moishow.identity;

import java.util.*;
import org.springframework.context.annotation.Profile;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.*;
import org.springframework.web.bind.annotation.*;
import static com.moishow.identity.ApiProblem.require;

/** Read-only bank details for the exact current sender; never executes a bank transfer. */
@RestController @Profile("db") @RequestMapping("/api/v1/events/{eventId}/finance")
class FinancialTransferController {
 private final Store db;private final FinanceService finance;private final PersonalBankService bank;
 FinancialTransferController(Store db,FinanceService finance,PersonalBankService bank){this.db=db;this.finance=finance;this.bank=bank;}

 @GetMapping("/requests/{requestId}/transfer-instructions")
 @Transactional(readOnly=true,isolation=Isolation.REPEATABLE_READ)
 public ResponseEntity<Object> payment(@AuthenticationPrincipal Actor actor,@PathVariable UUID eventId,@PathVariable UUID requestId){
  var event=db.find(Models.ClubEvent.class,eventId);var request=db.find(FinanceModels.Request.class,requestId);var book=db.find(FinanceModels.Book.class,request.bookId);
  require(book.eventId.equals(eventId),404,"REQUEST_NOT_FOUND");require(request.userId.equals(actor.userId()),403,"OWN_REQUEST_ONLY");
  var position=finance.requestView(book,request);long amount=((Number)position.get("remaining")).longValue();
  require(request.status.equals("ACTIVE")&&amount>0,409,"NO_PAYMENT_DUE");
  var result=bank.transferAccount(event.responsibleId);result.put("purpose","PAYMENT");result.put("eventId",eventId);result.put("requestId",requestId);result.put("amount",amount);result.put("bookVersion",book.version);
  result.put("pendingVerification",position.get("status").equals("PENDING"));return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(result);
 }

 @GetMapping("/refunds/{refundId}/transfer-instructions")
 @Transactional(readOnly=true,isolation=Isolation.REPEATABLE_READ)
 public ResponseEntity<Object> refund(@AuthenticationPrincipal Actor actor,@PathVariable UUID eventId,@PathVariable UUID refundId){
  var event=db.find(Models.ClubEvent.class,eventId);var refund=db.find(FinanceModels.Refund.class,refundId);var book=db.find(FinanceModels.Book.class,refund.bookId);
  require(book.eventId.equals(eventId),404,"REFUND_NOT_FOUND");require(event.responsibleId.equals(actor.userId()),403,"EVENT_RESPONSIBLE_REQUIRED");
  require(refund.status.equals("REQUESTED")&&refund.amount>0,409,"REFUND_NOT_REQUESTED");
  long due=book.firstRegisteredAt==null?finance.earlyRefund(book,refund.userId):finance.position(book,refund.userId).refund();
  require(refund.amount<=due,409,"REFUND_EXCEEDS_CURRENT_DUE");
  var result=bank.transferAccount(refund.userId);result.put("purpose","REFUND");result.put("eventId",eventId);result.put("refundId",refundId);result.put("amount",refund.amount);result.put("bookVersion",book.version);
  return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(result);
 }
}
