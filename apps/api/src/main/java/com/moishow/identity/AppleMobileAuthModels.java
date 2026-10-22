package com.moishow.identity;
import jakarta.persistence.*;import java.time.Instant;
final class AppleMobileAuthModels {
 @Entity(name="AppleMobileAuthAttempt") @Table(name="apple_mobile_auth_attempt")
 static class Attempt extends Models.Row {
  String stateHash;String nonce;String pkceChallenge;Instant expiresAt;boolean callbackConsumed;
  String ticketHash;String identitySubject;Instant ticketExpiresAt;boolean exchanged;
 }
}
