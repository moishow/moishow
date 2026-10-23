package com.moishow.identity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

final class BankVerificationModels {
 @Entity(name="BankVerification") @Table(name="bank_verification")
 static class Challenge extends Models.Row {
  UUID userId;String purpose;UUID contextId;String bankId;String bankName;
  @Column(columnDefinition="text") String accountCipher;
  @Column(columnDefinition="text") String holderCipher;
  String last4;int accountLength;String accountFingerprint;String bindingHash;
  String status="PENDING";String codeHash;String providerReference;int attempts;
  Instant createdAt;Instant phaseAt;Instant expiresAt;Instant verifiedAt;Instant consumedAt;
 }
}
