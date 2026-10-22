package com.moishow.identity;
import org.springframework.context.annotation.Profile;import org.springframework.web.bind.annotation.*;import org.springframework.http.*;import java.net.URI;
@RestController @Profile("db") @RequestMapping("/api/v1/auth/apple/mobile")
class AppleMobileAuthController {
 final AppleMobileAuthService service;AppleMobileAuthController(AppleMobileAuthService service){this.service=service;}
 record Start(String codeChallenge){}record Exchange(String ticket,String codeVerifier){}
 @PostMapping("/start") Object start(@RequestBody Start b){return service.start(b.codeChallenge());}
 @PostMapping(value="/callback",consumes=MediaType.APPLICATION_FORM_URLENCODED_VALUE) ResponseEntity<Void> callback(@RequestParam String state,@RequestParam("id_token")String token){return ResponseEntity.status(HttpStatus.FOUND).location(URI.create(service.callback(state,token))).cacheControl(CacheControl.noStore()).build();}
 @PostMapping("/exchange") Object exchange(@RequestBody Exchange b){return service.exchange(b.ticket(),b.codeVerifier());}
}
