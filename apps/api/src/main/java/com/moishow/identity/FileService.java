package com.moishow.identity;
import org.springframework.context.annotation.Profile;import org.springframework.stereotype.Service;import org.springframework.transaction.annotation.Transactional;import org.springframework.beans.factory.ObjectProvider;import org.springframework.jdbc.core.JdbcTemplate;
import java.util.*;import java.time.Instant;import java.security.*;
import static com.moishow.identity.ApiProblem.require;
@Service @Profile("db")
class FileService implements AttachmentAccess {
 final Store db;final FileBlobStore storage;final EventService events;final ObjectProvider<PlatformContentAccess> content;final ObjectProvider<PlatformService> platform;final ObjectProvider<FinanceCaseAccess> cases;final JdbcTemplate sql;
 FileService(Store db,FileBlobStore storage,EventService events,ObjectProvider<PlatformContentAccess> content,ObjectProvider<PlatformService> platform,ObjectProvider<FinanceCaseAccess> cases,JdbcTemplate sql){this.db=db;this.storage=storage;this.events=events;this.content=content;this.platform=platform;this.cases=cases;this.sql=sql;}
 static String digest(byte[] bytes){try{return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));}catch(NoSuchAlgorithmException e){throw new IllegalStateException(e);}}
 static String type(byte[] b){
  if(b.length>=8&&Arrays.equals(Arrays.copyOf(b,8),new byte[]{(byte)137,80,78,71,13,10,26,10}))return "image/png";
  if(b.length>=3&&b[0]==(byte)255&&b[1]==(byte)216&&b[2]==(byte)255)return "image/jpeg";
  if(b.length>=12&&new String(b,0,4,java.nio.charset.StandardCharsets.US_ASCII).equals("RIFF")&&new String(b,8,4,java.nio.charset.StandardCharsets.US_ASCII).equals("WEBP"))return "image/webp";
  if(b.length>=5&&new String(b,0,5,java.nio.charset.StandardCharsets.US_ASCII).equals("%PDF-"))return "application/pdf";
  throw new ApiProblem(400,"UNSUPPORTED_FILE_CONTENT");
 }
 Object upload(Actor actor,String scope,UUID club,UUID event,String declared,byte[] bytes){
  require(scope!=null&&Set.of("POST","PAYMENT","EXPENSE","DISPUTE").contains(scope),400,"INVALID_FILE_SCOPE");require(bytes.length>0&&bytes.length<=10*1024*1024,413,"INVALID_FILE_SIZE");String type=type(bytes);
  require(declared==null||declared.equals("application/octet-stream")||declared.equals(type)||(declared.equals("image/jpg")&&type.equals("image/jpeg")),400,"FILE_CONTENT_TYPE_MISMATCH");
  if(scope.equals("POST")){require(event==null&&type.startsWith("image/"),400,"POST_IMAGE_REQUIRED");if(club!=null)require(db.active(club,actor.userId()),403,"CLUB_MEMBER_REQUIRED");}
  else{require(event!=null&&club==null,400,"EVENT_REQUIRED");var e=db.find(Models.ClubEvent.class,event);require(events.financial(actor,e),403,"FINANCE_ACCESS_DENIED");if(scope.equals("EXPENSE"))require(e.responsibleId.equals(actor.userId()),403,"SETTLEMENT_RESPONSIBLE_REQUIRED");}
  var f=new FileModels.Blob();f.ownerId=actor.userId();f.clubId=club;f.eventId=event;f.scope=scope;f.contentType=type;f.size=bytes.length;f.checksum=digest(bytes);f.createdAt=Instant.now();f.objectKey="private/"+f.id;storage.put(f.objectKey,type,bytes);db.save(f);return Map.of("id",f.id,"reference","file:"+f.id,"displayUrl","/api/v1/files/"+f.id,"size",f.size,"contentType",f.contentType);
 }
 @Override @Transactional(readOnly=true) public void requirePostPhoto(Actor a,UUID id,UUID club){var f=db.find(FileModels.Blob.class,id);require(!f.status.equals("DELETED")&&f.ownerId.equals(a.userId())&&f.scope.equals("POST")&&Objects.equals(f.clubId,club),403,"POST_PHOTO_CONTEXT_DENIED");}
 @Override @Transactional(readOnly=true) public void requireEvidence(Actor a,String reference,String scope,UUID event){if(reference==null||!reference.startsWith("file:"))return;UUID id;try{id=UUID.fromString(reference.substring(5));}catch(IllegalArgumentException e){throw new ApiProblem(400,"INVALID_FILE_REFERENCE");}var f=db.find(FileModels.Blob.class,id);require(!f.status.equals("DELETED")&&f.ownerId.equals(a.userId())&&f.scope.equals(scope)&&event.equals(f.eventId),403,"FILE_EVIDENCE_CONTEXT_DENIED");}
 record Download(byte[] bytes,String contentType){}
 @Transactional(readOnly=true) public Download read(Actor a,UUID id){var f=db.find(FileModels.Blob.class,id);require(!f.status.equals("DELETED"),404,"FILE_NOT_FOUND");require(f.ownerId.equals(a.userId())||linkedAccess(a,f),403,"FILE_ACCESS_DENIED");return new Download(storage.get(f.objectKey),f.contentType);}
 boolean linkedAccess(Actor a,FileModels.Blob f){
  if(f.scope.equals("POST")){
   var reader=content.getIfAvailable();var moderation=platform.getIfAvailable();if(moderation!=null&&moderation.assignedFileEvidence(a,f.id))return true;if(reader==null)return false;
   for(UUID post:sql.queryForList("select post_id from community_post_photo where file_id=?",UUID.class,f.id))if(reader.canReadPost(a,post))return true;return false;
  }
  if(f.eventId==null)return false;var event=db.find(Models.ClubEvent.class,f.eventId);String reference="file:"+f.id;
  if(f.scope.equals("EXPENSE")){
   var rounds=sql.queryForList("select x.round_id from finance_expense x join settlement_book b on b.id=x.book_id where b.event_id=? and x.evidence=?",UUID.class,f.eventId,reference);if(rounds.isEmpty())return false;
   if(event.responsibleId.equals(a.userId())||db.active(event.clubId,a.userId()))return true;
   for(UUID round:rounds)if(!db.list(Models.Participation.class,"from Participation where roundId=?1 and userId=?2 and everConfirmed=true",round,a.userId()).isEmpty())return true;return false;
  }
  if(f.scope.equals("PAYMENT"))return !sql.queryForList("select r.id from payment_report r join settlement_book b on b.id=r.book_id where b.event_id=? and r.evidence=? and (r.user_id=? or r.processed_by=? or ?=?)",UUID.class,f.eventId,reference,a.userId(),a.userId(),event.responsibleId,a.userId()).isEmpty();
  for(var dispute:sql.queryForList("select d.id,d.user_id,d.counterparty_id from finance_dispute d join settlement_book b on b.id=d.book_id where b.event_id=? and d.evidence=?",f.eventId,reference)){
   if(event.responsibleId.equals(a.userId())||a.userId().equals(dispute.get("user_id"))||a.userId().equals(dispute.get("counterparty_id")))return true;var assigned=cases.getIfAvailable();if(assigned!=null&&assigned.canRead(a.userId(),event.id,(UUID)dispute.get("id")))return true;
  }return false;
 }
}
