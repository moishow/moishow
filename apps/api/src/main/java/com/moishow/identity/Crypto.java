package com.moishow.identity;
import java.security.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
final class Crypto {
 static final SecureRandom RANDOM=new SecureRandom();
 static String token(){byte[] b=new byte[32];RANDOM.nextBytes(b);return Base64.getUrlEncoder().withoutPadding().encodeToString(b);}
 static String hash(String value){try{return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)));}catch(NoSuchAlgorithmException e){throw new IllegalStateException(e);}}
}
