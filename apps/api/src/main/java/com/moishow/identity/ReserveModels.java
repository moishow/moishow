package com.moishow.identity;
import jakarta.persistence.*;import java.util.UUID;import java.time.Instant;
final class ReserveModels {
 @Entity(name="ReserveAccount") @Table(name="reserve_account") static class Account extends Models.Row {
  UUID clubId;UUID custodianId;String bankName;String last4;String holderName;@Column(columnDefinition="text")String accountCipher;String verificationReference;long balance;
 }
 @Entity(name="ReserveEntry") @Table(name="reserve_entry") static class Entry extends Models.Row {
  UUID accountId;UUID eventId;UUID createdBy;UUID sentBy;UUID confirmedBy;UUID recipientId;String kind;String status;long amount;String purpose;
  String sentReference;String confirmedReference;String actualRecordReason;UUID actualRecordedBy;long unbackedAtActualRecord;Instant actualRecordedAt;Instant createdAt;Instant sentAt;Instant actualAt;
 }
 @Entity(name="ResponsibilityHandover") @Table(name="responsibility_handover") static class Handover extends Models.Row {
  UUID eventId;UUID accountId;UUID proposerId;UUID candidateId;long inventoryAmount;String inventoryNote;@Column(columnDefinition="text")String inventorySnapshot;long snapshotVersion;boolean requiresReacceptance;String status="PROPOSED";
  String sentReference;String receivedReference;Instant createdAt;Instant sentAt;Instant receivedAt;
 }
 @Entity(name="ClubOwnerTransfer") @Table(name="club_owner_transfer") static class OwnerTransfer extends Models.Row {
  UUID clubId;UUID proposerId;UUID candidateId;String status="PROPOSED";Instant createdAt;
 }

 @Entity(name="HandoverReturn") @Table(name="handover_return") static class FundsReturn extends Models.Row {
  UUID handoverId;UUID eventId;UUID senderId;UUID recipientId;long amount;String kind="HANDOVER_RETURN";String status="REQUESTED";String reason;
  String sentReference;String receivedReference;Instant createdAt;Instant sentAt;Instant receivedAt;
 }
}
