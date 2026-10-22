package com.moishow.settlement;

import org.springframework.http.*;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.annotation.*;

@RestControllerAdvice
public class ApiErrorHandler {
    public record ErrorBody(String code,String message) {}
    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<ErrorBody> invalid(IllegalArgumentException error) {
        return ResponseEntity.badRequest().body(new ErrorBody("INVALID_REQUEST",error.getMessage()));
    }
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ErrorBody> malformed(HttpMessageNotReadableException error) {
        return ResponseEntity.badRequest().body(new ErrorBody("INVALID_JSON","요청 JSON 형식과 정수 원화 값을 확인해주세요."));
    }
}
