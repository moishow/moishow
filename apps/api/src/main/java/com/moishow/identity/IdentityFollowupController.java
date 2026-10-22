package com.moishow.identity;
import org.springframework.context.annotation.Profile;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import java.util.UUID;
@RestController @Profile("db") @RequestMapping("/api/v1")
class IdentityFollowupController {
 final ClubService clubs; final EventService events; final Commands commands;
 IdentityFollowupController(ClubService clubs,EventService events,Commands commands){this.clubs=clubs;this.events=events;this.commands=commands;}
 record MetadataForm(Long version,String description,String region,String category,UUID imageFileId,Boolean clearImage){}
 @PostMapping("/clubs/{id}/metadata") Object metadata(@AuthenticationPrincipal Actor actor,@PathVariable UUID id,@RequestHeader(value="Idempotency-Key",required=false)String key,@RequestBody MetadataForm form){return commands.run(actor,"clubs:"+id+":metadata",key,form,()->clubs.metadata(actor,id,form));}
 @GetMapping("/clubs/{id}/join-history") Object joinHistory(@AuthenticationPrincipal Actor actor,@PathVariable UUID id){return clubs.requestHistory(actor,id);}
 @GetMapping("/rounds/{id}/request-history") Object lateHistory(@AuthenticationPrincipal Actor actor,@PathVariable UUID id){return events.requestHistory(actor,id);}
}
