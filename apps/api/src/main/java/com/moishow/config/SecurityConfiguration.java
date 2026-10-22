package com.moishow.config;

import org.springframework.context.annotation.*;
import org.springframework.core.env.Environment;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class SecurityConfiguration {
    @Bean SecurityFilterChain boundary(HttpSecurity http,Environment environment) throws Exception {
        boolean dev=environment.matchesProfiles("dev");
        http.sessionManagement(s->s.sessionCreationPolicy(SessionCreationPolicy.STATELESS));
        http.requestCache(cache->cache.disable());
        http.httpBasic(basic->basic.disable());http.formLogin(form->form.disable());
        if(dev)http.csrf(csrf->csrf.ignoringRequestMatchers("/api/v1/settlements/preview"));
        http.authorizeHttpRequests(auth->{
            auth.requestMatchers("/actuator/health").permitAll();
            if(dev)auth.requestMatchers(HttpMethod.POST,"/api/v1/settlements/preview").permitAll();
            auth.anyRequest().denyAll();
        });
        http.exceptionHandling(errors->errors
            .authenticationEntryPoint((request,response,error)->response.setStatus(403))
            .accessDeniedHandler((request,response,error)->response.setStatus(403)));
        return http.build();
    }
}
