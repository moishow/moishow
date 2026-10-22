package com.moishow.identity;
import java.util.UUID;
/** Trusted assignment bridge; read retention does not grant new resolution authority. */
public interface FinanceCaseAccess {
 boolean assigned(UUID actorId,UUID eventId,UUID disputeId);
 default boolean canRead(UUID actorId,UUID eventId,UUID disputeId){return assigned(actorId,eventId,disputeId);}
 default boolean canResolve(UUID actorId,UUID eventId,UUID disputeId){return assigned(actorId,eventId,disputeId);}
}
