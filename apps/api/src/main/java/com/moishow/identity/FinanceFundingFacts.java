package com.moishow.identity;
import java.util.*;
/** Trusted immutable facts from the handover/reserve/advance ledger, never caller-supplied math. */
public interface FinanceFundingFacts {
 record Movement(UUID id,UUID actorId,long amount,String kind){}
 record Recovery(UUID id,UUID creditorId,long amount,String kind){}
 record Snapshot(UUID eventId,List<Movement> movements,List<Recovery> recoveries){
  public Snapshot { Objects.requireNonNull(eventId);movements=List.copyOf(movements);recoveries=List.copyOf(recoveries); }
  public static Snapshot empty(UUID eventId){return new Snapshot(eventId,List.of(),List.of());}
 }
 Snapshot facts(UUID eventId);
 default boolean hasFinancialRelationship(UUID eventId,UUID actorId){return false;}
}
