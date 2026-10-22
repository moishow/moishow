package com.moishow.identity;
import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;
import static org.junit.jupiter.api.Assertions.*;
class ProviderConfigurationTest {
 @Test void providersWithoutCredentialsFailClosed(){
  var providers=new ProviderConfiguration();var env=new MockEnvironment();
  for(String p:new String[]{"GOOGLE","APPLE","KAKAO"})assertEquals(503,assertThrows(ApiProblem.class,()->providers.providerVerifier(env).verify(p,"not-real","nonce")).status);
  assertEquals(503,assertThrows(ApiProblem.class,()->providers.smsGateway(env).send("+821012345678","000000")).status);
 }
}
