package com.moishow.identity;

import java.nio.ByteBuffer;
import java.security.MessageDigest;
import java.time.*;
import java.util.*;
import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.*;
import org.springframework.transaction.annotation.*;
import org.springframework.transaction.support.*;
import static com.moishow.identity.ApiProblem.require;

@Service @Profile("db")
class BankVerificationService {
 private static final Set<String> PURPOSES=Set.of("PERSONAL","RESERVE","RESERVE_HANDOVER");
 private static final Set<String> IN_FLIGHT=Set.of("PENDING","HOLDER_CHECK","TRANSFER_DISPATCHED");
 private static final ZoneId DAY_ZONE=ZoneId.of("Asia/Seoul");
 private final Store db;private final JdbcTemplate sql;private final BankData secrets;private final CodefGateway gateway;private final tools.jackson.databind.ObjectMapper json;private final TransactionTemplate transaction;
 @jakarta.persistence.PersistenceContext private jakarta.persistence.EntityManager em;
 BankVerificationService(Store db,JdbcTemplate sql,BankData secrets,CodefGateway gateway,tools.jackson.databind.ObjectMapper json,PlatformTransactionManager manager){this.db=db;this.sql=sql;this.secrets=secrets;this.gateway=gateway;this.json=json;transaction=new TransactionTemplate(manager);transaction.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);}
 Map<String,Object> fingerprint(String operation,Object input){return Map.of("inputHmac",secrets.hmac("bank-verification-command:"+operation,json.writeValueAsString(input)));}
 private Instant now(){return Instant.now().truncatedTo(java.time.temporal.ChronoUnit.MICROS);}
 private boolean live(){if(!gateway.live())return false;try{secrets.key();return true;}catch(ApiProblem ex){return false;}}
 public Object banks(){return Map.of("available",live(),"banks",gateway.banks().stream().map(bank->Map.of("id",bank.id(),"name",bank.name())).toList());}
 private void purpose(String purpose,UUID context){require(purpose!=null&&PURPOSES.contains(purpose),400,"INVALID_BANK_VERIFICATION_PURPOSE");require(purpose.equals("PERSONAL")?context==null:context!=null,400,"BANK_VERIFICATION_CONTEXT_REQUIRED");}
 private void relation(Actor actor,String purpose,UUID context){
  if(purpose.equals("PERSONAL"))return;
  if(purpose.equals("RESERVE")){
   var club=db.find(Models.Club.class,context);require(club.status.equals("ACTIVE"),409,"CLUB_NOT_ACTIVE");require(db.admin(context,actor.userId()),403,"CLUB_ADMIN_REQUIRED");
   var account=db.one(ReserveModels.Account.class,"from ReserveAccount where clubId=?1",context);if(account!=null){require(account.custodianId.equals(actor.userId()),403,"RESERVE_CUSTODIAN_REQUIRED");require(account.balance==0&&db.list(ReserveModels.Entry.class,"from ReserveEntry where accountId=?1 and status not in ('COMPLETED','CONFIRMED','CANCELLED')",account.id).isEmpty(),409,"CUSTODY_HANDOVER_REQUIRED");}
   return;
  }
  var handover=db.find(ReserveModels.Handover.class,context);require(handover.accountId!=null&&handover.eventId==null,400,"CUSTODIAN_HANDOVER_REQUIRED");require(handover.candidateId.equals(actor.userId()),403,"CANDIDATE_ONLY");require(Set.of("ACCEPTED","FUNDS_PENDING").contains(handover.status),409,"ACTUAL_HANDOVER_PENDING");
  // After actual funds are sent, the candidate must retain the receipt obligation.
  if(handover.status.equals("ACCEPTED")){var account=db.find(ReserveModels.Account.class,handover.accountId);require(db.admin(account.clubId,actor.userId()),403,"CLUB_ADMIN_REQUIRED");}
 }
 private String binding(UUID user,String purpose,UUID context,String bank,String account,String holder){return secrets.hmac("bank-verification-proof",json.writeValueAsString(List.of(user.toString(),purpose,context==null?"":context.toString(),bank,account,holder)));}
 private void accountLock(String fingerprint){
  long id=ByteBuffer.wrap(HexFormat.of().parseHex(fingerprint)).getLong();
  sql.execute((ConnectionCallback<Void>) connection->{try(var statement=connection.prepareStatement("select pg_advisory_xact_lock(?)")){statement.setLong(1,id);statement.execute();}return null;});
 }
 @Transactional(propagation=Propagation.MANDATORY)
 public Object create(Actor actor,BankVerificationController.Begin form){
  require(live(),503,"BANK_PROVIDER_NOT_CONFIGURED");purpose(form.purpose(),form.contextId());relation(actor,form.purpose(),form.contextId());var bank=gateway.bank(form.bankId());
  String account=ClubService.text(form.accountNumber(),40);if(form.purpose().equals("PERSONAL"))account=account.replace("-","").replace(" ","");require(account.matches(form.purpose().equals("PERSONAL")?"[0-9]{6,30}":"[0-9]{4,34}"),400,"INVALID_ACCOUNT_NUMBER");String holder=ClubService.text(form.holderName(),100);require(form.identity()!=null&&form.identity().matches("[0-9]{6}"),400,"INVALID_BANK_IDENTITY");
  String fingerprint=secrets.hmac("bank-verification-account-rate",bank.transferOrganization()+"\0"+account);accountLock(fingerprint);Instant created=now();
  var recent=em.createQuery("from BankVerification where userId=?1 order by createdAt desc",BankVerificationModels.Challenge.class).setParameter(1,actor.userId()).setMaxResults(1).getResultList();require(recent.isEmpty()||!created.isBefore(recent.getFirst().createdAt.plusSeconds(120)),429,"BANK_VERIFICATION_RATE_LIMIT");
  Instant start=created.atZone(DAY_ZONE).toLocalDate().atStartOfDay(DAY_ZONE).toInstant(),end=start.atZone(DAY_ZONE).plusDays(1).toInstant();long count=em.createQuery("select count(v) from BankVerification v where accountFingerprint=?1 and createdAt>=?2 and createdAt<?3",Long.class).setParameter(1,fingerprint).setParameter(2,start).setParameter(3,end).getSingleResult();require(count<5,429,"BANK_VERIFICATION_RATE_LIMIT");
  var row=new BankVerificationModels.Challenge();row.userId=actor.userId();row.purpose=form.purpose();row.contextId=form.contextId();row.bankId=bank.id();row.bankName=bank.name();row.accountCipher=secrets.encrypt(account);row.holderCipher=secrets.encrypt(holder);row.last4=account.substring(account.length()-Math.min(4,account.length()-2));row.accountLength=account.length();row.accountFingerprint=fingerprint;row.bindingHash=binding(row.userId,row.purpose,row.contextId,row.bankName,account,holder);row.createdAt=created;row.phaseAt=created;row.expiresAt=created.plusSeconds(600);db.save(row);return Map.of("id",row.id);
 }
 private record DispatchData(UUID id,CodefGateway.Bank bank,String account,String holder){}
 public void dispatch(Actor actor,UUID id,String identity){
  require(!TransactionSynchronizationManager.isActualTransactionActive(),500,"BANK_DISPATCH_TRANSACTION_BOUNDARY");
  DispatchData data=transaction.execute(status->{var row=db.lock(BankVerificationModels.Challenge.class,id);require(row.userId.equals(actor.userId()),403,"BANK_VERIFICATION_OWNER_REQUIRED");if(!effective(row,now()).equals("PENDING"))return null;row.status="HOLDER_CHECK";row.phaseAt=now();row.version++;return new DispatchData(row.id,gateway.bank(row.bankId),secrets.decrypt(row.accountCipher),secrets.decrypt(row.holderCipher));});
  if(data==null)return;
  try{String holder=gateway.holder(data.bank,data.account,identity);require(holder!=null&&holder.strip().equals(data.holder),400,"BANK_HOLDER_MISMATCH");}catch(Exception ex){finish(id,"HOLDER_CHECK","FAILED",null,null);return;}
  Boolean claimed=transaction.execute(status->{var row=db.lock(BankVerificationModels.Challenge.class,id);if(!effective(row,now()).equals("HOLDER_CHECK"))return false;row.status="TRANSFER_DISPATCHED";row.phaseAt=now();row.version++;return true;});
  if(!Boolean.TRUE.equals(claimed))return;
  try{
   var transfer=gateway.transfer(data.bank,data.account);require(transfer!=null&&transfer.code()!=null&&transfer.code().matches("[0-9]{4}")&&transfer.reference()!=null&&!transfer.reference().isBlank()&&transfer.reference().length()<=500,503,"BANK_VERIFICATION_FAILED");
   finish(id,"TRANSFER_DISPATCHED","AWAITING_CODE",secrets.hmac("bank-verification-code:"+id,transfer.code()),transfer.reference());
  }catch(Exception ex){finish(id,"TRANSFER_DISPATCHED","UNKNOWN",null,null);}
 }
 private void finish(UUID id,String expected,String next,String codeHash,String providerReference){transaction.executeWithoutResult(status->{var row=db.lock(BankVerificationModels.Challenge.class,id);if(!effective(row,now()).equals(expected))return;row.status=next;row.codeHash=codeHash;row.providerReference=providerReference;row.phaseAt=now();row.version++;});}
 private String effective(BankVerificationModels.Challenge row,Instant time){if(row.status.equals("CONSUMED"))return "CONSUMED";if(!time.isBefore(row.expiresAt))return "EXPIRED";if(IN_FLIGHT.contains(row.status)&&!time.isBefore(row.phaseAt.plusSeconds(90)))return "UNKNOWN";return row.status;}
 private Map<String,Object> view(BankVerificationModels.Challenge row){var result=new LinkedHashMap<String,Object>();result.put("id",row.id);result.put("status",effective(row,now()));result.put("expiresAt",row.expiresAt);result.put("bankName",row.bankName);result.put("accountMasked","*".repeat(row.accountLength-row.last4.length())+row.last4);result.put("attemptsRemaining",Math.max(0,5-row.attempts));return result;}
 @Transactional(readOnly=true)
 public Object get(Actor actor,UUID id){var row=db.find(BankVerificationModels.Challenge.class,id);require(row.userId.equals(actor.userId()),403,"BANK_VERIFICATION_OWNER_REQUIRED");return view(row);}
 @Transactional(readOnly=true)
 public Object mine(Actor actor,String purpose,UUID context){purpose(purpose,context);String query=context==null?"from BankVerification where userId=?1 and purpose=?2 and contextId is null and consumedAt is null and expiresAt>?3 order by createdAt desc,id":"from BankVerification where userId=?1 and purpose=?2 and contextId=?4 and consumedAt is null and expiresAt>?3 order by createdAt desc,id";var select=em.createQuery(query,BankVerificationModels.Challenge.class).setParameter(1,actor.userId()).setParameter(2,purpose).setParameter(3,now());if(context!=null)select.setParameter(4,context);return select.getResultList().stream().map(this::view).toList();}
 private Map<String,Object> confirmation(BankVerificationModels.Challenge row,int status,String code){var body=view(row);if(code!=null)body.put("code",code);return Map.of("httpStatus",status,"body",body);}
 @Transactional(propagation=Propagation.MANDATORY)
 public Object confirm(Actor actor,UUID id,String code){
  var row=db.lock(BankVerificationModels.Challenge.class,id);require(row.userId.equals(actor.userId()),403,"BANK_VERIFICATION_OWNER_REQUIRED");String state=effective(row,now());
  if(state.equals("EXPIRED"))return confirmation(row,409,"BANK_VERIFICATION_EXPIRED");if(state.equals("LOCKED"))return confirmation(row,400,"BANK_VERIFICATION_LOCKED");if(state.equals("VERIFIED"))return confirmation(row,200,null);if(!state.equals("AWAITING_CODE"))return confirmation(row,409,"BANK_VERIFICATION_NOT_AWAITING_CODE");
  String supplied=secrets.hmac("bank-verification-code:"+id,code==null?"":code);boolean matches=MessageDigest.isEqual(HexFormat.of().parseHex(row.codeHash),HexFormat.of().parseHex(supplied));
  row.version++;if(code!=null&&code.matches("[0-9]{4}")&&matches){row.status="VERIFIED";row.verifiedAt=now();return confirmation(row,200,null);}
  row.attempts++;if(row.attempts==5)row.status="LOCKED";return confirmation(row,400,row.attempts==5?"BANK_VERIFICATION_LOCKED":"BANK_AUTH_CODE_INVALID");
 }
 @Transactional(propagation=Propagation.MANDATORY)
 public String consume(UUID user,String bank,String account,String holder,UUID id,String purpose,UUID context){
  require(id!=null,409,"BANK_VERIFICATION_PROOF_REQUIRED");var row=db.lock(BankVerificationModels.Challenge.class,id);require(row.userId.equals(user),403,"BANK_VERIFICATION_OWNER_REQUIRED");String state=effective(row,now());require(!state.equals("EXPIRED"),409,"BANK_VERIFICATION_EXPIRED");require(state.equals("VERIFIED"),409,"BANK_VERIFICATION_NOT_VERIFIED");
  String binding=binding(user,purpose,context,bank,account,holder);require(MessageDigest.isEqual(HexFormat.of().parseHex(row.bindingHash),HexFormat.of().parseHex(binding)),409,"BANK_VERIFICATION_BINDING_MISMATCH");row.status="CONSUMED";row.consumedAt=now();row.version++;return "CODEF:"+row.id;
 }
}
