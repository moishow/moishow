package com.moishow.identity;
import org.springframework.context.annotation.*;import org.springframework.core.env.Environment;import org.springframework.stereotype.Component;
import javax.crypto.*;import javax.crypto.spec.*;import java.nio.charset.StandardCharsets;import java.util.*;
@Configuration @Profile("db") class BankProviderConfiguration {
 @Bean BankOwnershipVerifier bankOwnershipVerifier(BankVerificationService verification){return new BankOwnershipVerifier(){
  @Override public String verify(UUID user,String bank,String number,String holder){throw new ApiProblem(409,"BANK_VERIFICATION_PROOF_REQUIRED");}
  @Override public String verify(UUID user,String bank,String number,String holder,UUID proof,String purpose,UUID context){return verification.consume(user,bank,number,holder,proof,purpose,context);}
 };}
}
@Component @Profile("db") class BankData {
 private final Environment env;BankData(Environment env){this.env=env;}
 byte[] key(){try{byte[] k=Base64.getDecoder().decode(env.getProperty("BANK_DATA_KEY_BASE64",""));ApiProblem.require(k.length==32,503,"BANK_DATA_KEY_NOT_CONFIGURED");return k;}catch(IllegalArgumentException e){throw new ApiProblem(503,"BANK_DATA_KEY_NOT_CONFIGURED");}}
 String hmac(String domain,String value){try{var mac=Mac.getInstance("HmacSHA256");mac.init(new SecretKeySpec(key(),"HmacSHA256"));return HexFormat.of().formatHex(mac.doFinal((domain+"\0"+value).getBytes(StandardCharsets.UTF_8)));}catch(java.security.GeneralSecurityException e){throw new IllegalStateException("Bank data authentication unavailable",e);}}
 String encrypt(String text){try{byte[] iv=new byte[12];Crypto.RANDOM.nextBytes(iv);var cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.ENCRYPT_MODE,new SecretKeySpec(key(),"AES"),new GCMParameterSpec(128,iv));byte[] encrypted=cipher.doFinal(text.getBytes(StandardCharsets.UTF_8));byte[] result=new byte[iv.length+encrypted.length];System.arraycopy(iv,0,result,0,iv.length);System.arraycopy(encrypted,0,result,iv.length,encrypted.length);return Base64.getEncoder().encodeToString(result);}catch(java.security.GeneralSecurityException e){throw new IllegalStateException("Bank data encryption unavailable",e);}}
 String decrypt(String stored){try{byte[] b=Base64.getDecoder().decode(stored);var cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.DECRYPT_MODE,new SecretKeySpec(key(),"AES"),new GCMParameterSpec(128,Arrays.copyOfRange(b,0,12)));return new String(cipher.doFinal(Arrays.copyOfRange(b,12,b.length)),StandardCharsets.UTF_8);}catch(java.security.GeneralSecurityException|IllegalArgumentException e){throw new ApiProblem(503,"BANK_DATA_UNAVAILABLE");}}
}
