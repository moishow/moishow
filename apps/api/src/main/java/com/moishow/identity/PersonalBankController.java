package com.moishow.identity;

import org.springframework.context.annotation.Profile;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController @Profile("db") @RequestMapping("/api/v1/me/bank-account")
class PersonalBankController {
 private final PersonalBankService service;private final Commands commands;
 PersonalBankController(PersonalBankService service,Commands commands){this.service=service;this.commands=commands;}
 record Form(Long version,String bankName,String accountNumber,String holderName){}
 @GetMapping Object get(@AuthenticationPrincipal Actor actor){return service.get(actor);}
 @PostMapping Object register(@AuthenticationPrincipal Actor actor,@RequestHeader(value="Idempotency-Key",required=false)String key,@RequestBody Form form){return commands.run(actor,"bank-account:register",key,form,()->service.register(actor,form));}
}
