package com.moishow.identity;
import java.util.UUID;
public record Actor(UUID userId,String scope,String sessionHash) implements java.security.Principal {
 public String getName(){return userId.toString();}
}
