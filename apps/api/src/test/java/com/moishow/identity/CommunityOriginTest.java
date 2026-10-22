package com.moishow.identity;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class CommunityOriginTest {
 @Test void onlyExactHttpOriginsAreAccepted(){
  assertEquals(0,CommunitySocket.origins("").length);
  assertArrayEquals(new String[]{"http://127.0.0.1:8766","https://chat.example"},CommunitySocket.origins("http://127.0.0.1:8766, https://chat.example"));
  for(String invalid:new String[]{"*","https://*.example","https://chat.example/","https://chat.example/path","https://chat.example?token=secret","https://chat.example#fragment","https://user:secret@chat.example","ws://chat.example","https://chat.example:0","https://chat.example:65536","https://chat.example,"})assertThrows(IllegalArgumentException.class,()->CommunitySocket.origins(invalid),invalid);
 }
}
