package com.moishow.identity;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.*;import org.springframework.transaction.support.TransactionTemplate;
import java.util.*;
/** Per-outbox durable lock and per-device acceptance records limit repeated sends after partial failure. */
@Service @Profile("db")
class PlatformOutbox {
 final JdbcTemplate sql;final PlatformPushGateway push;final TransactionTemplate transaction;
 PlatformOutbox(JdbcTemplate sql,PlatformPushGateway push,PlatformTransactionManager manager){this.sql=sql;this.push=push;transaction=new TransactionTemplate(manager);transaction.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);}
 void dispatch(){
  for(UUID id:sql.queryForList("select id from platform_outbox where status in ('PENDING','RETRY') and next_attempt_at<=now() order by id limit 100",UUID.class))transaction.executeWithoutResult(tx->deliver(id));
 }
 void retry(UUID id,String code){sql.update("update platform_outbox set status='RETRY',attempts=attempts+1,last_error=?,next_attempt_at=now()+interval '15 minutes' where id=?",code,id);}
 void deliver(UUID id){
  var rows=sql.queryForList("select o.id,n.id as notification_id,n.user_id,n.kind from platform_outbox o join platform_notification n on n.id=o.notification_id where o.id=? and o.status in ('PENDING','RETRY') and o.next_attempt_at<=now() for update of o skip locked",id);if(rows.isEmpty())return;var out=rows.getFirst();UUID user=(UUID)out.get("user_id");
  boolean enabled=Boolean.TRUE.equals(sql.queryForObject("select coalesce((select push_enabled from platform_preference where user_id=?),true)",Boolean.class,user));
  if(!enabled){sql.update("update platform_outbox set status='SUPPRESSED',last_error='PUSH_DISABLED' where id=?",id);return;}
  if(!push.configured()){retry(id,"PUSH_PROVIDER_NOT_CONFIGURED");return;}
  var devices=sql.queryForList("select * from platform_push_device where user_id=? and revoked_at is null order by id for update",user);if(devices.isEmpty()){retry(id,"NO_ACTIVE_DEVICE");return;}
  boolean retry=false;String error=null;int accepted=0;
  for(var device:devices){UUID deviceId=(UUID)device.get("id");sql.update("insert into platform_push_delivery(outbox_id,device_id,status) values(?,?,'RETRY') on conflict do nothing",id,deviceId);String previous=sql.queryForObject("select status from platform_push_delivery where outbox_id=? and device_id=?",String.class,id,deviceId);if(previous.equals("SENT")){accepted++;continue;}if(previous.equals("INVALID"))continue;
   var result=push.send((String)device.get("token"),(UUID)out.get("notification_id"),(String)out.get("kind"),(String)device.get("platform"));
   sql.update("update platform_push_delivery set status=?,attempts=attempts+1,last_error=?,provider_message_id=?,sent_at=case when ?='SENT' then now() else sent_at end where outbox_id=? and device_id=?",result.status(),result.code(),result.providerMessageId(),result.status(),id,deviceId);
   if(result.status().equals("SENT"))accepted++;else if(result.status().equals("INVALID"))sql.update("update platform_push_device set token=null,revoked_at=now(),updated_at=now() where id=?",deviceId);else{retry=true;error=result.code();}
  }
  if(retry){retry(id,error);return;}if(accepted==0){retry(id,"NO_ACTIVE_DEVICE");return;}
  sql.update("update platform_outbox set status='SENT',attempts=attempts+1,last_error=null where id=?",id);
 }
}
