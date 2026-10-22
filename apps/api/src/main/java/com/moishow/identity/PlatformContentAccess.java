package com.moishow.identity;
import java.util.UUID;
/** Community owns visibility rules; moderation receives access only to an explicitly reported item. */
public interface PlatformContentAccess {
 boolean canReadRoom(Actor actor,UUID roomId);
 boolean canReadPost(Actor actor,UUID postId);
 default boolean canReadMessage(Actor actor,UUID messageId){return false;}
}
