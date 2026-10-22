package com.moishow.identity;
import java.util.UUID;
/** Trusted in-process events, never a public HTTP scoring/notification command. */
public final class DomainSignals {
 private DomainSignals(){}
 public record Notification(UUID recipientId,String kind,UUID eventId,String groupKey,String body){}
 public enum FinancialChangeReason { ALLOCATION_CHANGE, FACT_CORRECTION }
 public record FinancialChanged(UUID eventId,FinancialChangeReason reason){
  public FinancialChanged(UUID eventId){this(eventId,FinancialChangeReason.ALLOCATION_CHANGE);}
 }
 public record Level(UUID eventId,UUID userId,String role,String outcome,String reason){}
}
