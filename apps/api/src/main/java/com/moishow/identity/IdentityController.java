package com.moishow.identity;
import org.springframework.context.annotation.Profile;
import org.springframework.security.core.annotation.AuthenticationPrincipal;import org.springframework.web.bind.annotation.*;
import java.time.Instant;import java.util.UUID;
@RestController @Profile("db") @RequestMapping("/api/v1")
class IdentityController {
 private final Commands commands;private final ClubService clubs;private final EventService events;
 IdentityController(Commands commands,ClubService clubs,EventService events){this.commands=commands;this.clubs=clubs;this.events=events;}
 record ClubForm(String name,String joinMode){}
 record JoinForm(String nickname,Long version,String inviteToken){}
 record ChangeForm(Long version,Boolean enabled,String role){}
 record VersionForm(Long version,String reason){}
 record EventPolicyForm(Long version,Long cancellationFee,Boolean accepted,String reason,Instant startsAt,Instant endsAt){}
 record EventForm(String title,String kind,boolean publicEvent,Instant startsAt,Instant endsAt,Long version,String settlementMode){}
 record RoundForm(Integer capacity,Instant closesAt,Long cancellationFee,Long version){}
 @PostMapping("/clubs") Object create(@AuthenticationPrincipal Actor a,@RequestHeader(value="Idempotency-Key",required=false)String k,@RequestBody ClubForm b){return commands.run(a,"clubs:create",k,b,()->clubs.create(a,b));}
 @GetMapping("/clubs") Object mine(@AuthenticationPrincipal Actor a){return clubs.mine(a);}
 @GetMapping("/clubs/{id}") Object club(@AuthenticationPrincipal Actor a,@PathVariable UUID id){return clubs.get(a,id);}
 @GetMapping("/clubs/{id}/members") Object members(@AuthenticationPrincipal Actor a,@PathVariable UUID id){return clubs.members(a,id);}
 @GetMapping("/clubs/{id}/join-requests") Object requests(@AuthenticationPrincipal Actor a,@PathVariable UUID id){return clubs.requests(a,id);}
 @PostMapping("/clubs/{id}/join") Object join(@AuthenticationPrincipal Actor a,@PathVariable UUID id,@RequestHeader(value="Idempotency-Key",required=false)String k,@RequestBody JoinForm b){return commands.run(a,"clubs:"+id+":join",k,b,()->clubs.join(a,id,b));}
 @PostMapping("/clubs/{id}/members/{userId}/{action}") Object manage(@AuthenticationPrincipal Actor a,@PathVariable UUID id,@PathVariable UUID userId,@PathVariable String action,@RequestHeader(value="Idempotency-Key",required=false)String k,@RequestBody ChangeForm b){return commands.run(a,"clubs:"+id+":"+userId+":"+action,k,b,()->clubs.manage(a,id,userId,action,b));}
 @PostMapping("/clubs/{id}/invites") Object invite(@AuthenticationPrincipal Actor a,@PathVariable UUID id,@RequestHeader(value="Idempotency-Key",required=false)String k,@RequestBody VersionForm b){return commands.run(a,"clubs:"+id+":invite",k,b,()->clubs.invite(a,id,b.version()));}
 @PostMapping("/clubs/{id}/leave") Object leave(@AuthenticationPrincipal Actor a,@PathVariable UUID id,@RequestHeader(value="Idempotency-Key",required=false)String k,@RequestBody VersionForm b){return commands.run(a,"clubs:"+id+":leave",k,b,()->clubs.leave(a,id,b.version()));}
 @PostMapping("/clubs/{id}/events") Object event(@AuthenticationPrincipal Actor a,@PathVariable UUID id,@RequestHeader(value="Idempotency-Key",required=false)String k,@RequestBody EventForm b){return commands.run(a,"clubs:"+id+":event",k,b,()->events.create(a,id,b));}
 @GetMapping("/events/{id}") Object event(@AuthenticationPrincipal Actor a,@PathVariable UUID id){return events.get(a,id);}
 @GetMapping("/events/{id}/access") Object access(@AuthenticationPrincipal Actor a,@PathVariable UUID id){return events.access(a,id);}
 @GetMapping("/events/{id}/participations") Object participants(@AuthenticationPrincipal Actor a,@PathVariable UUID id){return events.participants(a,id);}
 @GetMapping("/rounds/{id}/participation") Object ownParticipation(@AuthenticationPrincipal Actor a,@PathVariable UUID id){return events.ownParticipation(a,id);}
 @PostMapping("/events/{id}/rounds") Object round(@AuthenticationPrincipal Actor a,@PathVariable UUID id,@RequestHeader(value="Idempotency-Key",required=false)String k,@RequestBody RoundForm b){return commands.run(a,"events:"+id+":round",k,b,()->events.round(a,id,b));}
 @PostMapping("/rounds/{id}/participations") Object participate(@AuthenticationPrincipal Actor a,@PathVariable UUID id,@RequestHeader(value="Idempotency-Key",required=false)String k,@RequestBody VersionForm b){return commands.run(a,"rounds:"+id+":join",k,b,()->events.participate(a,id,b.version()));}
 @PostMapping("/rounds/{id}/participations/{participantId}/{action}") Object participation(@AuthenticationPrincipal Actor a,@PathVariable UUID id,@PathVariable UUID participantId,@PathVariable String action,@RequestHeader(value="Idempotency-Key",required=false)String k,@RequestBody VersionForm b){return commands.run(a,"rounds:"+id+":"+participantId+":"+action,k,b,()->events.changeParticipation(a,id,participantId,action,b.version(),b.reason()));}
 @PostMapping("/rounds/{id}/fee") Object fee(@AuthenticationPrincipal Actor a,@PathVariable UUID id,@RequestHeader(value="Idempotency-Key",required=false)String k,@RequestBody EventPolicyForm b){return commands.run(a,"rounds:"+id+":fee",k,b,()->events.changeFee(a,id,b));}
 @PostMapping("/rounds/{id}/consents/{kind}") Object consent(@AuthenticationPrincipal Actor a,@PathVariable UUID id,@PathVariable String kind,@RequestHeader(value="Idempotency-Key",required=false)String k,@RequestBody EventPolicyForm b){return commands.run(a,"rounds:"+id+":consent:"+kind,k,b,()->events.consent(a,id,kind,b));}
 @PostMapping("/rounds/{id}/cancel") Object cancelRound(@AuthenticationPrincipal Actor a,@PathVariable UUID id,@RequestHeader(value="Idempotency-Key",required=false)String k,@RequestBody EventPolicyForm b){return commands.run(a,"rounds:"+id+":cancel",k,b,()->events.cancelRound(a,id,b));}
 @PostMapping("/events/{id}/schedule") Object schedule(@AuthenticationPrincipal Actor a,@PathVariable UUID id,@RequestHeader(value="Idempotency-Key",required=false)String k,@RequestBody EventPolicyForm b){return commands.run(a,"events:"+id+":schedule",k,b,()->events.schedule(a,id,b));}
}
