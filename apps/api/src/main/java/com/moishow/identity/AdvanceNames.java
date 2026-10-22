package com.moishow.identity;
import java.util.*;
/** Public financial display names; callers must first restrict the set to authorized ledger parties. */
final class AdvanceNames {
 private AdvanceNames(){}
 static Map<String,Object> view(Store db,UUID club,UUID user){
  var member=db.member(club,user);boolean named=member!=null&&member.nickname!=null&&Set.of("ACTIVE","LEFT","EXPELLED").contains(member.status);
  return Map.of("nickname",named?member.nickname:db.find(Models.Account.class,user).nickname,"departed",member!=null&&Set.of("LEFT","EXPELLED").contains(member.status));
 }
 static Map<UUID,Object> map(Store db,UUID club,Collection<UUID> users){
  var result=new LinkedHashMap<UUID,Object>();for(var user:users)if(user!=null)result.put(user,view(db,club,user));return result;
 }
}
