package com.moishow.identity;
import org.springframework.context.annotation.Profile;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
/** Synchronous events join the originating transaction, preserving financial state + inbox atomically. */
@Component @Profile("db")
class PlatformSignals {
 private final PlatformService platform;
 PlatformSignals(PlatformService platform){this.platform=platform;}
 @EventListener public void notification(DomainSignals.Notification e){platform.notify(e.recipientId(),e.kind(),e.eventId(),e.groupKey(),e.body());}
 @EventListener public void level(DomainSignals.Level e){platform.assessLevel(e.eventId(),e.userId(),e.role(),e.outcome(),e.reason());}
}
