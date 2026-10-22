package com.moishow.identity;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.auth.oauth2.ServiceAccountCredentials;
import org.springframework.beans.factory.annotation.*;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;
import tools.jackson.databind.ObjectMapper;
import java.io.*;import java.net.*;import java.net.http.*;import java.nio.file.*;import java.time.Duration;import java.util.*;

/** FCM HTTP v1 authenticated with a deployment-owned service account, never a client-supplied bearer. */
@Component @Profile("db")
class PlatformFcmClient implements PlatformPushGateway {
 private final ObjectMapper json;private final String project;private final String credentialsFile;private final URI endpoint;private final HttpClient http;
 private GoogleCredentials credentials;
 @Autowired PlatformFcmClient(ObjectMapper json,@Value("${moishow.fcm.project-id:${FCM_PROJECT_ID:}}")String project,@Value("${moishow.fcm.credentials-file:${FCM_SERVICE_ACCOUNT_FILE:}}")String file){this(json,project,file,URI.create("https://fcm.googleapis.com"));}
 /** Package constructor enables local HTTP contract tests without a production endpoint override. */
 PlatformFcmClient(ObjectMapper json,String project,String file,URI endpoint){this.json=json;this.project=project;this.credentialsFile=file;this.endpoint=endpoint;this.http=HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).followRedirects(HttpClient.Redirect.NEVER).build();}
 public boolean configured(){return project!=null&&project.matches("[A-Za-z0-9][A-Za-z0-9:_-]{1,127}")&&credentialsFile!=null&&!credentialsFile.isBlank();}
 private synchronized String bearer()throws IOException{
  if(credentials==null)try(var in=Files.newInputStream(Path.of(credentialsFile))){credentials=ServiceAccountCredentials.fromStream(in).createScoped(List.of("https://www.googleapis.com/auth/firebase.messaging"));}
  credentials.refreshIfExpired();return credentials.getAccessToken().getTokenValue();
 }
 public Result send(String token,UUID notificationId,String kind,String platform){
  if(!configured())return new Result("RETRY","PUSH_PROVIDER_NOT_CONFIGURED",null);
  final String access;try{access=bearer();}catch(Exception unavailable){return new Result("RETRY","FCM_CREDENTIALS_UNAVAILABLE",null);}
  try{
   var message=new LinkedHashMap<String,Object>();message.put("token",token);message.put("notification",Map.of("title","모이쇼","body","새 알림이 있습니다. 앱에서 확인해 주세요."));message.put("data",Map.of("notificationId",notificationId.toString(),"kind",kind));
   if(platform.equals("ANDROID"))message.put("android",Map.of("notification",Map.of("tag",notificationId.toString())));
   if(platform.equals("IOS"))message.put("apns",Map.of("headers",Map.of("apns-collapse-id",notificationId.toString())));
   var request=HttpRequest.newBuilder(endpoint.resolve("/v1/projects/"+project+"/messages:send")).timeout(Duration.ofSeconds(10)).header("Authorization","Bearer "+access).header("Content-Type","application/json").POST(HttpRequest.BodyPublishers.ofString(json.writeValueAsString(Map.of("message",message)))).build();
   var response=http.send(request,HttpResponse.BodyHandlers.ofString());var body=json.readTree(response.body());
   if(response.statusCode()>=200&&response.statusCode()<300){String name=body.path("name").asText();if(name.startsWith("projects/"+project+"/messages/")&&name.length()<=255)return new Result("SENT",null,name);return new Result("RETRY","FCM_INVALID_RESPONSE",null);}
   for(var detail:body.path("error").path("details"))if(detail.path("errorCode").asText().equals("UNREGISTERED"))return new Result("INVALID","FCM_UNREGISTERED",null);
   return new Result("RETRY","FCM_HTTP_"+response.statusCode(),null);
  }catch(InterruptedException interrupted){Thread.currentThread().interrupt();return new Result("RETRY","FCM_INTERRUPTED",null);}catch(Exception unavailable){return new Result("RETRY","FCM_TRANSPORT_UNAVAILABLE",null);}
 }
}
