package com.moishow.identity;
import java.util.UUID;
/** Internal attachment checks; staged blobs are never public merely by knowing their UUID. */
public interface AttachmentAccess {
 void requirePostPhoto(Actor actor,UUID fileId,UUID clubId);
 void requireEvidence(Actor actor,String reference,String scope,UUID eventId);
}
