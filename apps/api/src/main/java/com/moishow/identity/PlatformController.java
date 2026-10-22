package com.moishow.identity;
import org.springframework.context.annotation.Profile;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import java.util.UUID;
@RestController @Profile("db") @RequestMapping("/api/v1")
class PlatformController {
 final PlatformService service;final Commands commands;
 PlatformController(PlatformService service,Commands commands){this.service=service;this.commands=commands;}
 @GetMapping("/push/devices") Object devices(@AuthenticationPrincipal Actor a){return service.devices(a);}
 @PostMapping("/push/devices") Object device(@AuthenticationPrincipal Actor a,@RequestHeader(value="Idempotency-Key",required=false)String key,@RequestBody PlatformModels.Device b){return commands.run(a,"push:device",key,b,()->service.device(a,b));}
 @DeleteMapping("/push/devices/{id}") Object deleteDevice(@AuthenticationPrincipal Actor a,@PathVariable UUID id,@RequestHeader(value="Idempotency-Key",required=false)String key){return commands.run(a,"push:device:"+id+":remove",key,id,()->service.deleteDevice(a,id));}
 @GetMapping("/events/{id}/support/results") Object results(@AuthenticationPrincipal Actor a,@PathVariable UUID id){return service.publicResults(a,id);}
 @PostMapping("/support/cases/{id}/claim") Object claim(@AuthenticationPrincipal Actor a,@PathVariable UUID id,@RequestHeader(value="Idempotency-Key",required=false)String key,@RequestBody PlatformModels.Version b){return commands.run(a,"support:"+id+":claim",key,b,()->service.claim(a,id,b));}
 @GetMapping("/notifications") Object inbox(@AuthenticationPrincipal Actor a){return service.inbox(a);}
 @PostMapping("/notifications/{id}/read") Object read(@AuthenticationPrincipal Actor a,@PathVariable UUID id,@RequestHeader(value="Idempotency-Key",required=false)String key){return commands.run(a,"notification:"+id+":read",key,id,()->service.read(a,id));}
 @GetMapping("/notification-preferences") Object preferences(@AuthenticationPrincipal Actor a){return service.preferences(a);}
 @PostMapping("/notification-preferences") Object preferences(@AuthenticationPrincipal Actor a,@RequestHeader(value="Idempotency-Key",required=false)String key,@RequestBody PlatformModels.Preferences b){return commands.run(a,"notification:preferences",key,b,()->service.preferences(a,b));}
 @GetMapping("/clubs/{clubId}/levels/{userId}") Object level(@AuthenticationPrincipal Actor a,@PathVariable UUID clubId,@PathVariable UUID userId){return service.level(a,clubId,userId);}
 @PostMapping("/support/requests") Object request(@AuthenticationPrincipal Actor a,@RequestHeader(value="Idempotency-Key",required=false)String key,@RequestBody PlatformModels.Request b){return commands.run(a,"support:create",key,b,()->service.request(a,b));}
 @PostMapping("/reports") Object report(@AuthenticationPrincipal Actor a,@RequestHeader(value="Idempotency-Key",required=false)String key,@RequestBody PlatformModels.Report b){return commands.run(a,"report:create",key,b,()->service.report(a,b));}
 @GetMapping("/support/cases") Object cases(@AuthenticationPrincipal Actor a){return service.cases(a,false);}
 @GetMapping("/operator/cases") Object operators(@AuthenticationPrincipal Actor a){return service.cases(a,true);}
 @GetMapping("/support/cases/{id}") Object detail(@AuthenticationPrincipal Actor a,@PathVariable UUID id){return service.caseView(a,id);}
 @PostMapping("/support/cases/{id}/escalate") Object escalate(@AuthenticationPrincipal Actor a,@PathVariable UUID id,@RequestHeader(value="Idempotency-Key",required=false)String key,@RequestBody PlatformModels.Version b){return commands.run(a,"support:"+id+":escalate",key,b,()->service.escalate(a,id,b));}
 @PostMapping("/support/cases/{id}/decisions") Object decide(@AuthenticationPrincipal Actor a,@PathVariable UUID id,@RequestHeader(value="Idempotency-Key",required=false)String key,@RequestBody PlatformModels.Decision b){return commands.run(a,"support:"+id+":decide",key,b,()->service.decide(a,id,b));}
}
