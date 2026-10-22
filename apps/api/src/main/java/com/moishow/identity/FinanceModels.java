package com.moishow.identity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

/** Internal persistence only. Explicit views enforce financial/evidence access. */
final class FinanceModels {
 @Entity(name="SettlementBook") @Table(name="settlement_book") static class Book extends Models.Row {
  UUID eventId; String status="OPEN"; String mode; Instant firstRegisteredAt; Instant finalDeadline;
 }
 @Entity(name="RoundBilling") @Table(name="round_billing") static class RoundBilling extends Models.Row {
  UUID bookId; UUID roundId; long amount; Instant deadline; boolean closed;
 }
 @Entity(name="BillingHistory") @Table(name="billing_history") static class BillingHistory extends Models.Row {
  UUID bookId; UUID roundId; long amount; Instant deadline; Instant createdAt; UUID createdBy;
 }
 @Entity(name="RequestExtension") @Table(name="request_extension") static class Extension extends Models.Row {
  UUID bookId; UUID requestId; Instant previousDeadline; Instant deadline; String reason; UUID createdBy; Instant createdAt;
 }
 @Entity(name="PaymentRequest") @Table(name="payment_request") static class Request extends Models.Row {
  UUID bookId; UUID roundId; UUID userId; long amount; long lastAdditional; Instant deadline; String status="ACTIVE";
 }
 @Entity(name="PaymentReport") @Table(name="payment_report") static class Report extends Models.Row {
  UUID bookId; UUID requestId; UUID userId; long reportedAmount; long amount; String status="PENDING";
  @Column(columnDefinition="text") String evidence; String reason; String transactionReference;
  Instant reportedAt; Instant actualReceivedAt; Instant processedAt; UUID processedBy;
 }
 @Entity(name="ReceiptCorrection") @Table(name="receipt_correction") static class ReceiptCorrection extends Models.Row {
  UUID bookId; UUID reportId; UUID revisionId; long amount; Instant actualReceivedAt;
  String reason; UUID createdBy; Instant createdAt; long sequence;
 }
 @Entity(name="ReceiptAllocation") @Table(name="receipt_allocation") static class ReceiptAllocation extends Models.Row {
  UUID bookId; UUID reportId; UUID correctionId; UUID roundId; String kind; long amount;
 }
 @Entity(name="FinanceBankTransaction") @Table(name="finance_bank_transaction") static class BankTransaction extends Models.Row {
  String reference; String accountScope; String scopeKind; UUID actualActorId; UUID cashAccountId; UUID bookId; UUID recordId; String kind;
 }
 @Entity(name="FinanceExpense") @Table(name="finance_expense") static class Expense extends Models.Row {
  UUID bookId; UUID roundId; UUID revisionId; UUID paidByUserId; String title; long amount;
  @Column(columnDefinition="text") String evidence; Instant createdAt; UUID createdBy;
 }
 @Entity(name="ExpenseFunding") @Table(name="finance_expense_funding") static class ExpenseFunding extends Models.Row {
  UUID bookId; UUID expenseId; UUID paidByUserId; UUID revisionId; String source; long amount;
  Instant actualPaidAt; Instant createdAt; UUID createdBy;
 }
 @Entity(name="FinanceRevision") @Table(name="finance_revision") static class Revision extends Models.Row {
  UUID bookId; String reason; @Column(columnDefinition="text") String snapshot;
  @Column(columnDefinition="text") String afterSnapshot; Instant createdAt; UUID createdBy;
 }
 @Entity(name="FinanceAdjustment") @Table(name="finance_adjustment") static class Adjustment extends Models.Row {
  UUID bookId; UUID revisionId; UUID roundId; UUID userId; long amount;
 }
 @Entity(name="FinanceRefund") @Table(name="finance_refund") static class Refund extends Models.Row {
  UUID bookId; UUID userId; long amount; long sentAmount; String status="REQUESTED";
  Instant requestedAt; UUID requestedBy; Instant sentAt; UUID sentBy; Instant confirmedAt; String transactionReference;
 }
 @Entity(name="FinanceFeeCredit") @Table(name="finance_fee_credit") static class FeeCredit extends Models.Row {
  UUID bookId; UUID participationId; long baseline; long creditedLate; long reservedLate;
 }
 @Entity(name="FinanceDispute") @Table(name="finance_dispute") static class Dispute extends Models.Row {
  UUID bookId; UUID userId; String status="OPEN"; @Column(columnDefinition="text") String reason;
  @Column(columnDefinition="text") String evidence; String resolution; String publicResult;
  long correctionAmount; UUID revisionId; UUID requestedParticipationId; String requestedStatus; UUID counterpartyId; Instant createdAt; Instant resolvedAt; UUID resolvedBy;
 }
 @Entity(name="FinanceCaseTransition") @Table(name="finance_case_transition") static class CaseTransition extends Models.Row {
  UUID disputeId; String status; String reason; Instant createdAt; UUID createdBy;
 }
 @Entity(name="RoundFeeTerm") @Table(name="round_fee_term") static class FeeTerm extends Models.Row {
  UUID roundId; long termVersion; long fee; Instant createdAt; UUID createdBy; String reason;
 }
 @Entity(name="ParticipationConsent") @Table(name="participation_consent") static class Consent extends Models.Row {
  UUID participationId; String kind; long termVersion; String decision; long fee; Instant createdAt; UUID createdBy;
 }
 @Entity(name="ParticipationChange") @Table(name="participation_change") static class ParticipationChange extends Models.Row {
  UUID eventId; UUID participationId; UUID revisionId; String oldStatus; String newStatus;
  long oldFee; long newFee; long feeVersion; String waivedReason; String reason; Instant createdAt; UUID createdBy;
 }
 @Entity(name="EventScheduleChange") @Table(name="event_schedule_change") static class ScheduleChange extends Models.Row {
  UUID eventId; long termVersion; Instant oldStartsAt; Instant oldEndsAt; Instant startsAt; Instant endsAt;
  String reason; Instant createdAt; UUID createdBy;
 }
}
