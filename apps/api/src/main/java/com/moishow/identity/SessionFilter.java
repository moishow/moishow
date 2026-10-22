package com.moishow.identity;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import jakarta.servlet.*;import jakarta.servlet.http.*;
import java.io.IOException;import java.util.List;
public final class SessionFilter extends OncePerRequestFilter {
 private final AuthService auth;public SessionFilter(AuthService auth){this.auth=auth;}
 @Override protected void doFilterInternal(HttpServletRequest request,HttpServletResponse response,FilterChain chain)throws ServletException,IOException{
  String h=request.getHeader("Authorization");
  if(h!=null&&h.startsWith("Bearer ")){var actor=auth.resolve(h.substring(7));if(actor!=null)SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(actor,null,List.of(new SimpleGrantedAuthority(actor.scope()))));}
  chain.doFilter(request,response);
 }
}
