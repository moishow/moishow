package com.moishow.identity;
public class ApiProblem extends RuntimeException {
 public final int status; public final String code;
 public ApiProblem(int status,String code){super(code);this.status=status;this.code=code;}
 public static void require(boolean condition,int status,String code){if(!condition)throw new ApiProblem(status,code);}
}
