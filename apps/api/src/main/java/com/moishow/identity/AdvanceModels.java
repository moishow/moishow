package com.moishow.identity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

/** Actual repayments and explicit noncash recoveries. Outstanding claims belong to Finance.reconcile. */
final class AdvanceModels {
 @Entity(name="AdvanceRepayment") @Table(name="advance_repayment")
 static class Repayment extends Models.Row {
  UUID eventId; UUID creditorId; UUID payerId; UUID createdBy;
  long amount; String status="REQUESTED"; String reason;
  String sentReference; String receivedReference;
  Instant createdAt; Instant sentAt; Instant confirmedAt;
 }
 @Entity(name="AdvanceRecovery") @Table(name="advance_recovery")
 static class Recovery extends Models.Row {
  UUID eventId; UUID actorId; long amount; String kind="SELF_RECOVERY"; String reason; Instant createdAt;
 }
}
