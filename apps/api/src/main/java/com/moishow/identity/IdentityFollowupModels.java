package com.moishow.identity;
import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;
final class IdentityFollowupModels {
 @Entity(name="RequestDecision") @Table(name="identity_request_decision") static class Decision extends Models.Row {
  UUID clubId; UUID roundId; UUID userId; String kind; String status;
  @Column(length=1000) String memo="";
  @Column(length=1000) String reason="";
  Instant createdAt; UUID createdBy;
 }
}
