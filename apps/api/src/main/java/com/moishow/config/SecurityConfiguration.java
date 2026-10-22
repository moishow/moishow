package com.moishow.config;

import org.springframework.context.annotation.*;
import org.springframework.beans.factory.ObjectProvider;
import com.moishow.identity.AuthService;
import com.moishow.identity.SessionFilter;
import org.springframework.security.web.authentication.AnonymousAuthenticationFilter;
import org.springframework.core.env.Environment;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class SecurityConfiguration {
    @Bean SecurityFilterChain boundary(HttpSecurity http,Environment environment,ObjectProvider<AuthService> authService) throws Exception {
        boolean dev=environment.matchesProfiles("dev");
        boolean db=environment.matchesProfiles("db");
        if(db){http.addFilterBefore(new SessionFilter(authService.getObject()),AnonymousAuthenticationFilter.class);http.csrf(csrf->csrf.ignoringRequestMatchers("/api/v1/**"));}
        http.sessionManagement(s->s.sessionCreationPolicy(SessionCreationPolicy.STATELESS));
        http.requestCache(cache->cache.disable());
        http.httpBasic(basic->basic.disable());http.formLogin(form->form.disable());
        if(dev)http.csrf(csrf->csrf.ignoringRequestMatchers("/api/v1/settlements/preview"));
        http.authorizeHttpRequests(auth->{
            auth.requestMatchers("/actuator/health").permitAll();
            if(dev)auth.requestMatchers(HttpMethod.POST,"/api/v1/settlements/preview").permitAll();
            if(db){
                auth.requestMatchers(HttpMethod.GET,"/api/v1/chat/socket").permitAll();
                auth.requestMatchers(HttpMethod.POST,"/api/v1/auth/challenges","/api/v1/auth/social").permitAll();
                auth.requestMatchers(HttpMethod.POST,"/api/v1/auth/apple/mobile/start","/api/v1/auth/apple/mobile/callback","/api/v1/auth/apple/mobile/exchange").permitAll();
                auth.requestMatchers("/api/v1/auth/sms","/api/v1/auth/sms/*/verify","/api/v1/auth/register").hasAuthority("ONBOARDING");
                auth.requestMatchers("/api/v1/auth/logout").authenticated();
                auth.requestMatchers("/api/v1/**").hasAuthority("ACTIVE");
            }
            auth.anyRequest().denyAll();
        });
        http.exceptionHandling(errors->errors
            .authenticationEntryPoint((request,response,error)->response.setStatus(db?401:403))
            .accessDeniedHandler((request,response,error)->response.setStatus(403)));
        return http.build();
    }
}
