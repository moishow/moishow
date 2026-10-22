package com.moishow.identity;
import org.springframework.context.annotation.Profile;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.ResponseEntity;
import org.springframework.dao.*;
import java.util.Map;
@RestControllerAdvice @Profile("db")
class IdentityErrors {
 @ExceptionHandler(ApiProblem.class) ResponseEntity<?> problem(ApiProblem e){return ResponseEntity.status(e.status).body(Map.of("code",e.code));}
 @ExceptionHandler(DataIntegrityViolationException.class) ResponseEntity<?> duplicate(DataIntegrityViolationException e){return ResponseEntity.status(409).body(Map.of("code","CONSTRAINT_CONFLICT"));}
 @ExceptionHandler({CannotAcquireLockException.class,org.springframework.orm.ObjectOptimisticLockingFailureException.class}) ResponseEntity<?> race(Exception e){return ResponseEntity.status(409).body(Map.of("code","CONCURRENT_CHANGE"));}
}
