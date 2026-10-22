package com.moishow.identity;

import java.time.Instant;
import java.util.*;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import static com.moishow.identity.ApiProblem.require;

@Service @Profile("db")
class PersonalBankService {
 private final Store db;
 private final BankData secrets;
 private final BankOwnershipVerifier verifier;
 PersonalBankService(Store db,BankData secrets,BankOwnershipVerifier verifier){this.db=db;this.secrets=secrets;this.verifier=verifier;}

 PersonalBankModels.Account current(UUID user){return db.one(PersonalBankModels.Account.class,"from PersonalBankAccount where userId=?1 and current=true",user);}

 @Transactional(readOnly=true)
 public Object get(Actor actor){return view(current(actor.userId()));}

 Object register(Actor actor,PersonalBankController.Form form){
  var previous=current(actor.userId());long expected=previous==null?0:previous.version;
  require(form.version()!=null&&form.version()==expected,409,"STALE_VERSION");
  String bank=ClubService.text(form.bankName(),100),holder=ClubService.text(form.holderName(),100);
  String number=ClubService.text(form.accountNumber(),40).replace("-","").replace(" ","");
  require(number.matches("[0-9]{6,30}"),400,"INVALID_ACCOUNT_NUMBER");
  secrets.key();
  String proof=verifier.verify(actor.userId(),bank,number,holder);
  require(proof!=null&&!proof.isBlank()&&proof.length()<=500,503,"BANK_VERIFICATION_FAILED");
  var next=new PersonalBankModels.Account();next.userId=actor.userId();next.version=expected+1;
  next.bankName=bank;next.accountCipher=secrets.encrypt(number);next.holderCipher=secrets.encrypt(holder);
  next.verificationReference=proof;next.verifiedAt=Instant.now().truncatedTo(java.time.temporal.ChronoUnit.MICROS);
  if(previous!=null){previous.current=false;db.flush();}
  db.save(next);return view(next);
 }

 /** Internal only: callers must establish the exact outgoing transfer relationship first. */
 Map<String,Object> transferAccount(UUID recipient){
  var account=current(recipient);require(account!=null,409,"RECIPIENT_BANK_ACCOUNT_REQUIRED");
  var result=new LinkedHashMap<String,Object>();result.put("recipientId",recipient);result.put("accountId",account.id);result.put("accountVersion",account.version);
  result.put("bankName",account.bankName);result.put("accountNumber",secrets.decrypt(account.accountCipher));result.put("holderName",secrets.decrypt(account.holderCipher));result.put("verifiedAt",account.verifiedAt);return result;
 }

 Map<String,Object> view(PersonalBankModels.Account account){
  if(account==null)return Map.of("registered",false,"version",0);
  String number=secrets.decrypt(account.accountCipher),holder=secrets.decrypt(account.holderCipher);
  var result=new LinkedHashMap<String,Object>();result.put("registered",true);result.put("id",account.id);result.put("version",account.version);
  result.put("bankName",account.bankName);result.put("accountMasked","*".repeat(number.length()-4)+number.substring(number.length()-4));
  int count=holder.codePointCount(0,holder.length());
  result.put("holderMasked",count<=1?"*":new String(Character.toChars(holder.codePointAt(0)))+"*".repeat(count-1));
  result.put("verifiedAt",account.verifiedAt);return result;
 }
}
