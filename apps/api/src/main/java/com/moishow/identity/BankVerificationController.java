package com.moishow.identity;

import java.util.*;
import org.springframework.context.annotation.Profile;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController @Profile("db") @RequestMapping("/api/v1/bank-verifications")
class BankVerificationController {
 private final BankVerificationService service;private final Commands commands;private final tools.jackson.databind.ObjectMapper json;
 BankVerificationController(BankVerificationService service,Commands commands,tools.jackson.databind.ObjectMapper json){this.service=service;this.commands=commands;this.json=json;}
 record Begin(String purpose,UUID contextId,String bankId,String accountNumber,String holderName,String identity){@Override public String toString(){return "BankVerificationBegin[redacted]";}}
 record Confirm(String code){@Override public String toString(){return "BankVerificationConfirm[redacted]";}}
 @GetMapping("/banks") ResponseEntity<Object> banks(){return noStore(service.banks());}
 @GetMapping ResponseEntity<Object> mine(@AuthenticationPrincipal Actor actor,@RequestParam String purpose,@RequestParam(required=false)UUID contextId){return noStore(service.mine(actor,purpose,contextId));}
 @GetMapping("/{id}") ResponseEntity<Object> get(@AuthenticationPrincipal Actor actor,@PathVariable UUID id){return noStore(service.get(actor,id));}
 @PostMapping ResponseEntity<Object> begin(@AuthenticationPrincipal Actor actor,@RequestHeader(value="Idempotency-Key",required=false)String key,@RequestBody Begin form){
  boolean[] created={false};var result=commands.run(actor,"bank-verification:begin",key,service.fingerprint("begin",form),()->{var receipt=service.create(actor,form);created[0]=true;return receipt;});
  UUID id=UUID.fromString(json.readTree(json.writeValueAsString(result)).path("id").asText());
  if(created[0])service.dispatch(actor,id,form.identity());
  return noStore(service.get(actor,id));
 }
 @PostMapping("/{id}/confirm") ResponseEntity<Object> confirm(@AuthenticationPrincipal Actor actor,@PathVariable UUID id,@RequestHeader(value="Idempotency-Key",required=false)String key,@RequestBody Confirm form){
  var result=commands.run(actor,"bank-verification:confirm:"+id,key,service.fingerprint("confirm:"+id,form),()->service.confirm(actor,id,form.code()));
  var envelope=json.readTree(json.writeValueAsString(result));return ResponseEntity.status(envelope.path("httpStatus").asInt()).cacheControl(CacheControl.noStore()).body(envelope.path("body"));
 }
 private ResponseEntity<Object> noStore(Object body){return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(body);}
}
