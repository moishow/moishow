package com.moishow.identity;
import org.springframework.context.annotation.Profile;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import java.util.*;
@RestController @Profile("db") @RequestMapping("/api/v1")
class AuthController {
 private final AuthService auth;AuthController(AuthService auth){this.auth=auth;}
 record Social(String provider,String token,UUID challengeId){}
 record Phone(String phone){} record Code(String code){} record Registration(String nickname,UUID verificationId){}
 @PostMapping("/auth/challenges") Object challenge(){return auth.challenge();}
 @PostMapping("/auth/social") Object login(@RequestBody Social body){return auth.login(body.provider(),body.token(),body.challengeId());}
 @PostMapping("/auth/sms") Object sms(@AuthenticationPrincipal Actor actor,@RequestBody Phone body){return auth.sendSms(actor,body.phone());}
 @PostMapping("/auth/sms/{id}/verify") Object verify(@AuthenticationPrincipal Actor actor,@PathVariable UUID id,@RequestBody Code body){boolean result=auth.verifySms(actor,id,body.code());ApiProblem.require(result,400,"INVALID_CODE");return Map.of("verified",true);}
 @PostMapping("/auth/register") Object register(@AuthenticationPrincipal Actor actor,@RequestBody Registration body){ApiProblem.require(body.verificationId()!=null,400,"VERIFICATION_REQUIRED");return auth.register(actor,body.verificationId(),body.nickname());}
 @PostMapping("/auth/logout") Object logout(@AuthenticationPrincipal Actor actor){return auth.logout(actor);}
 @GetMapping("/me") Object me(@AuthenticationPrincipal Actor actor){return auth.me(actor);}
}
