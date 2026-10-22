package com.moishow.identity;
import org.springframework.context.annotation.Profile;import org.springframework.web.bind.annotation.*;import org.springframework.web.multipart.MultipartFile;import org.springframework.security.core.annotation.AuthenticationPrincipal;import org.springframework.http.*;
import java.util.*;import java.io.IOException;
@RestController @Profile("db") @RequestMapping("/api/v1/files")
class FileController {
 final Commands commands;final FileService files;FileController(Commands commands,FileService files){this.commands=commands;this.files=files;}
 @PostMapping(consumes=MediaType.MULTIPART_FORM_DATA_VALUE) Object upload(@AuthenticationPrincipal Actor a,@RequestHeader(value="Idempotency-Key",required=false)String key,@RequestParam String scope,@RequestParam(required=false)UUID clubId,@RequestParam(required=false)UUID eventId,@RequestPart MultipartFile file)throws IOException{
  ApiProblem.require(file.getSize()<=10*1024*1024,413,"INVALID_FILE_SIZE");byte[] bytes=file.getBytes();var input=new LinkedHashMap<String,Object>();input.put("scope",scope);input.put("clubId",clubId);input.put("eventId",eventId);input.put("checksum",FileService.digest(bytes));return commands.run(a,"files:upload",key,input,()->files.upload(a,scope,clubId,eventId,file.getContentType(),bytes));
 }
 @GetMapping("/{id}") ResponseEntity<byte[]> read(@AuthenticationPrincipal Actor a,@PathVariable UUID id){var f=files.read(a,id);return ResponseEntity.ok().contentType(MediaType.parseMediaType(f.contentType())).header("Cache-Control","no-store").header("X-Content-Type-Options","nosniff").header("Content-Disposition",ContentDisposition.attachment().filename(id.toString()).build().toString()).body(f.bytes());}
}
