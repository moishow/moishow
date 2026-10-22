package com.moishow.identity;
import org.springframework.context.annotation.Profile;
import org.springframework.web.bind.annotation.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import java.util.UUID;
import java.time.Instant;
@RestController @Profile("db") @RequestMapping("/api/v1/events/{eventId}/advances")
class AdvanceController {
 final Commands commands; final AdvanceService service;
 AdvanceController(Commands commands,AdvanceService service){this.commands=commands;this.service=service;}
 record Form(Long version,UUID creditorId,Long amount,String reason,String reference,Instant actualAt){}
 @GetMapping Object get(@AuthenticationPrincipal Actor a,@PathVariable UUID eventId){return service.get(a,eventId);}
 @PostMapping("/{action}") Object create(@AuthenticationPrincipal Actor a,@PathVariable UUID eventId,@PathVariable String action,@RequestHeader(value="Idempotency-Key",required=false)String key,@RequestBody Form f){return commands.run(a,"advance:"+eventId+":"+action,key,f,()->switch(action){case "self-recoveries"->service.recover(a,eventId,f);case "repayments"->service.request(a,eventId,f);default->throw new ApiProblem(404,"UNKNOWN_OPERATION");});}
 @PostMapping("/repayments/{id}/{action}") Object change(@AuthenticationPrincipal Actor a,@PathVariable UUID eventId,@PathVariable UUID id,@PathVariable String action,@RequestHeader(value="Idempotency-Key",required=false)String key,@RequestBody Form f){return commands.run(a,"advance:"+eventId+":"+id+":"+action,key,f,()->service.change(a,eventId,id,action,f));}
}
