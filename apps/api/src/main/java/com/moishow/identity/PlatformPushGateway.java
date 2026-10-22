package com.moishow.identity;
import java.util.UUID;
/** Provider acceptance only; a successful result never proves device delivery or a bank transfer. */
interface PlatformPushGateway {
 record Result(String status,String code,String providerMessageId){}
 boolean configured();
 Result send(String token,UUID notificationId,String kind,String platform);
}
