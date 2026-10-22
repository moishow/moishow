package com.moishow.identity;
import org.springframework.context.annotation.*;
import org.springframework.messaging.*;
import org.springframework.messaging.simp.*;
import org.springframework.messaging.simp.config.*;
import org.springframework.messaging.simp.stomp.*;
import org.springframework.messaging.support.*;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.*;
import org.springframework.web.socket.config.annotation.*;
import java.util.*;import java.util.concurrent.*;

@Configuration @Profile("db") @EnableWebSocketMessageBroker
class CommunitySocket implements WebSocketMessageBrokerConfigurer {
 final AuthService auth;final CommunityService community;final tools.jackson.databind.ObjectMapper json;final Map<String,Actor> sessions=new ConcurrentHashMap<>();
 final String[] allowedOrigins;
 CommunitySocket(AuthService auth,CommunityService community,tools.jackson.databind.ObjectMapper json,@org.springframework.beans.factory.annotation.Value("${CHAT_ALLOWED_ORIGINS:}") String origins){this.auth=auth;this.community=community;this.json=json;this.allowedOrigins=origins(origins);}
 static String[] origins(String configured){
  if(configured==null||configured.isBlank())return new String[0];var exact=new LinkedHashSet<String>();
  for(String value:configured.split(",",-1)){String origin=value.trim();try{var uri=new java.net.URI(origin);if(!Set.of("http","https").contains(uri.getScheme())||uri.getHost()==null||uri.getRawUserInfo()!=null||uri.getRawQuery()!=null||uri.getRawFragment()!=null||!uri.getRawPath().isEmpty()||uri.getPort()==0||uri.getPort()>65535||origin.contains("*"))throw new IllegalArgumentException();exact.add(origin);}catch(Exception ex){throw new IllegalArgumentException("CHAT_ALLOWED_ORIGINS requires exact http(s) origins",ex);}}
  return exact.toArray(String[]::new);
 }
 @Override public void registerStompEndpoints(StompEndpointRegistry registry){var endpoint=registry.addEndpoint("/api/v1/chat/socket");if(allowedOrigins.length>0)endpoint.setAllowedOrigins(allowedOrigins);}
 @Override public void configureMessageBroker(MessageBrokerRegistry registry){registry.enableSimpleBroker("/topic/chat/");registry.setApplicationDestinationPrefixes("/app");}
 @Override public void configureWebSocketTransport(WebSocketTransportRegistration registry){registry.setMessageSizeLimit(32768).setSendBufferSizeLimit(131072).setSendTimeLimit(10000);}
 static UUID roomId(String destination){if(destination==null||!destination.startsWith("/topic/chat/"))throw new MessageDeliveryException("INVALID_DESTINATION");String tail=destination.substring("/topic/chat/".length());try{UUID id=UUID.fromString(tail);if(!id.toString().equals(tail))throw new IllegalArgumentException();return id;}catch(IllegalArgumentException ex){throw new MessageDeliveryException("INVALID_DESTINATION");}}
 @Override public void configureClientInboundChannel(ChannelRegistration registration){registration.interceptors(new ChannelInterceptor(){
  @Override public Message<?> preSend(Message<?> message,MessageChannel channel){var h=MessageHeaderAccessor.getAccessor(message,StompHeaderAccessor.class);if(h==null)return message;String sid=h.getSessionId();var command=h.getCommand();
   if(command==StompCommand.CONNECT){String header=h.getFirstNativeHeader("Authorization");Actor a=header!=null&&header.startsWith("Bearer ")?auth.resolve(header.substring(7)):null;if(a==null||!a.scope().equals("ACTIVE"))throw new MessageDeliveryException("ACTIVE_SESSION_REQUIRED");sessions.put(sid,a);h.setUser(a);return message;}
   if(command==StompCommand.DISCONNECT){sessions.remove(sid);return message;}
   if(command==StompCommand.SEND)throw new MessageDeliveryException("REST_WRITES_ONLY");
   if(command==StompCommand.SUBSCRIBE){var a=sessions.get(sid);if(!community.deliveryAllowed(a,roomId(h.getDestination())))throw new MessageDeliveryException("ROOM_ACCESS_DENIED");}
   return message;
  }
 });}
 @Override public void configureClientOutboundChannel(ChannelRegistration registration){registration.interceptors(new ChannelInterceptor(){
  @Override public Message<?> preSend(Message<?> message,MessageChannel channel){var h=MessageHeaderAccessor.getAccessor(message,SimpMessageHeaderAccessor.class);if(h!=null&&h.getMessageType()==SimpMessageType.MESSAGE){var a=sessions.get(h.getSessionId());try{Object payload=message.getPayload();String messageId=payload instanceof byte[] bytes?json.readTree(bytes).path("id").asText():payload instanceof Map<?,?> map?String.valueOf(map.get("id")):json.readTree(payload.toString()).path("id").asText();if(!community.messageDeliveryAllowed(a,roomId(h.getDestination()),UUID.fromString(messageId)))return null;}catch(RuntimeException ex){return null;}}return message;}
 });}
 @org.springframework.context.event.EventListener public void closed(org.springframework.web.socket.messaging.SessionDisconnectEvent e){sessions.remove(e.getSessionId());}
}
@Component @Profile("db")
class CommunityBroadcast {
 final SimpMessagingTemplate messaging;CommunityBroadcast(SimpMessagingTemplate messaging){this.messaging=messaging;}
 @TransactionalEventListener(phase=TransactionPhase.AFTER_COMMIT) public void committed(CommunityService.MessageCreated e){messaging.convertAndSend("/topic/chat/"+e.roomId(),(Object)e.message());}
}
