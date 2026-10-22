package com.moishow.identity;
public interface SocialVerifier {
 record Identity(String provider,String subject) {}
 Identity verify(String provider,String token,String expectedNonce);
}
