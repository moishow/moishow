package com.moishow.identity;
import org.springframework.context.annotation.Profile;import org.springframework.security.core.annotation.AuthenticationPrincipal;import org.springframework.web.bind.annotation.*;import java.util.UUID;import java.time.LocalDate;
@RestController @Profile("db") @RequestMapping("/api/v1")
class HubController {
 final HubService hub;final Commands commands;HubController(HubService hub,Commands commands){this.hub=hub;this.commands=commands;}
 record ProfileForm(String nickname,Long version,java.util.List<String> interests,String bio,UUID avatarFileId,Boolean clearAvatar){}
 @GetMapping("/me/profile") Object ownProfile(@AuthenticationPrincipal Actor a){return hub.ownProfile(a);}
 @GetMapping("/home") Object home(@AuthenticationPrincipal Actor a,@RequestParam(required=false)LocalDate date,@RequestParam(defaultValue="0")int offset,@RequestParam(defaultValue="50")int limit){return hub.home(a,date,offset,limit);}
 @GetMapping("/clubs/discover") Object discover(@AuthenticationPrincipal Actor a,@RequestParam(required=false)String q,@RequestParam(defaultValue="0")int offset,@RequestParam(defaultValue="50")int limit){return hub.discover(a,q,offset,limit);}
 @GetMapping("/clubs/{id}/events") Object events(@AuthenticationPrincipal Actor a,@PathVariable UUID id,@RequestParam(defaultValue="0")int offset,@RequestParam(defaultValue="50")int limit){return hub.events(a,id,offset,limit);}
 @GetMapping("/me/history") Object history(@AuthenticationPrincipal Actor a,@RequestParam(defaultValue="0")int offset,@RequestParam(defaultValue="50")int limit){return hub.history(a,offset,limit);}
 @PostMapping("/me/profile") Object profile(@AuthenticationPrincipal Actor a,@RequestHeader(value="Idempotency-Key",required=false)String k,@RequestBody ProfileForm b){return commands.run(a,"me:profile",k,b,()->hub.profile(a,b));}
 @PostMapping("/clubs/{id}/nickname") Object nickname(@AuthenticationPrincipal Actor a,@PathVariable UUID id,@RequestHeader(value="Idempotency-Key",required=false)String k,@RequestBody ProfileForm b){return commands.run(a,"clubs:"+id+":nickname",k,b,()->hub.clubNickname(a,id,b));}
}
