package com.moishow.identity;
import org.springframework.stereotype.Service;import org.springframework.context.annotation.Profile;import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.ObjectMapper;
import java.util.*;import java.util.function.Supplier;
import static com.moishow.identity.Models.*;import static com.moishow.identity.ApiProblem.require;
@Service @Profile("db")
class Commands {
 private final Store db;private final ObjectMapper json;
 Commands(Store db,ObjectMapper json){this.db=db;this.json=json;}
 @Transactional Object run(Actor actor,String operation,String key,Object body,Supplier<Object> action){
  require(key!=null&&key.matches("[0-9a-fA-F-]{36}"),400,"IDEMPOTENCY_KEY_REQUIRED");
  try{UUID.fromString(key);}catch(IllegalArgumentException e){throw new ApiProblem(400,"INVALID_IDEMPOTENCY_KEY");}
  var user=db.lock(Account.class,actor.userId());require(user.status.equals("ACTIVE"),403,"ACTIVE_ACCOUNT_REQUIRED");
  String fingerprint=Crypto.hash(json.writeValueAsString(body));
  var old=db.one(CommandReceipt.class,"from CommandReceipt where userId=?1 and operation=?2 and requestKey=?3",actor.userId(),operation,key);
  if(old!=null){require(old.bodyHash.equals(fingerprint),409,"IDEMPOTENCY_CONFLICT");return json.readTree(old.responseJson);}
  var result=action.get();var receipt=new CommandReceipt();receipt.userId=actor.userId();receipt.operation=operation;receipt.requestKey=key;receipt.bodyHash=fingerprint;receipt.responseJson=json.writeValueAsString(result);db.save(receipt);db.flush();return result;
 }
}
