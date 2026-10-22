package com.moishow.identity;
import java.util.UUID;
final class PlatformModels {
 record Preferences(Boolean pushEnabled){}
 record Device(String token,String platform){}
 record Request(UUID eventId,String reason,UUID financialDisputeId){}
 record Report(UUID clubId,UUID eventId,UUID targetUserId,String type,String reason,UUID contentId,String contentType){}
 record Version(Long version){}
 record Decision(Long version,String action,String reason){}
}
