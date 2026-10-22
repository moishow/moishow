package com.moishow.identity;
import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

/** Persistence records stay internal; controllers return explicit views. */
final class Models {
 @MappedSuperclass static abstract class Row {
  @Id UUID id=UUID.randomUUID(); long version=0;
 }
 @Entity(name="Account") @Table(name="app_user") static class Account extends Row {
  String provider; String subject; String phone; String nickname; String status="PENDING";
 }
 @Entity(name="ServiceSession") @Table(name="service_session") static class ServiceSession {
  @Id String tokenHash; UUID userId; String scope; Instant expiresAt; boolean revoked;
 }
 @Entity(name="LoginNonce") @Table(name="login_nonce") static class LoginNonce extends Row {
  String nonce; Instant expiresAt; boolean consumed;
 }
 @Entity(name="SmsChallenge") @Table(name="sms_challenge") static class SmsChallenge extends Row {
  UUID userId; String phone; String codeHash; Instant createdAt; Instant expiresAt; Instant verifiedAt; int attempts; boolean consumed;
 }
 @Entity(name="Club") @Table(name="club") static class Club extends Row {
  String name; String joinMode; String status="ACTIVE"; UUID ownerId;
 }
 @Entity(name="Membership") @Table(name="membership") static class Membership extends Row {
  UUID clubId; UUID userId; String nickname; String role="MEMBER"; String status="NONE"; boolean expelledHistory; boolean blacklisted;
 }
 @Entity(name="Invitation") @Table(name="club_invitation") static class Invitation extends Row {
  UUID clubId; String tokenHash; Instant expiresAt;
 }
 @Entity(name="ClubEvent") @Table(name="club_event") static class ClubEvent extends Row {
  UUID clubId; UUID hostId; UUID responsibleId; String title; String kind; boolean publicEvent; Instant startsAt; Instant endsAt;
 }
 @Entity(name="EventRound") @Table(name="event_round") static class EventRound extends Row {
  UUID eventId; int capacity; Instant closesAt; long cancellationFee;
 }
 @Entity(name="Participation") @Table(name="participation") static class Participation extends Row {
  UUID roundId; UUID userId; String status; boolean everConfirmed; long agreedFee;
 }
 @Entity(name="CommandReceipt") @Table(name="command_receipt") static class CommandReceipt extends Row {
  UUID userId; String requestKey; String operation; String bodyHash; @Column(columnDefinition="text") String responseJson;
 }
}
