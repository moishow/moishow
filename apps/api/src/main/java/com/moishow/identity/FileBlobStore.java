package com.moishow.identity;
import org.springframework.context.annotation.Profile;import org.springframework.stereotype.Component;import org.springframework.core.env.Environment;
import software.amazon.awssdk.services.s3.S3Client;import software.amazon.awssdk.services.s3.model.*;import software.amazon.awssdk.regions.Region;import software.amazon.awssdk.core.sync.RequestBody;
import java.nio.file.*;import java.io.*;import static com.moishow.identity.ApiProblem.require;
@Component @Profile("db")
class FileBlobStore {
 final Environment env;private S3Client s3;FileBlobStore(Environment env){this.env=env;}
 boolean local(){return env.getProperty("FILE_STORAGE_MODE","S3").equals("LOCAL");}
 Path path(String key){require(env.matchesProfiles("dev","file-test"),503,"LOCAL_FILE_STORAGE_DEV_ONLY");String root=env.getProperty("FILE_STORAGE_ROOT","");require(!root.isBlank(),503,"FILE_STORAGE_NOT_CONFIGURED");Path base=Path.of(root).toAbsolutePath().normalize(),p=base.resolve(key).normalize();require(p.startsWith(base),400,"INVALID_OBJECT_KEY");return p;}
 String bucket(){String b=env.getProperty("FILES_BUCKET","");require(!b.isBlank(),503,"FILE_STORAGE_NOT_CONFIGURED");return b;}
 synchronized S3Client client(){if(s3==null){String region=env.getProperty("AWS_REGION","");bucket();require(!region.isBlank(),503,"FILE_REGION_NOT_CONFIGURED");s3=S3Client.builder().region(Region.of(region)).build();}return s3;}
 void put(String key,String type,byte[] bytes){try{if(local()){Path p=path(key);Files.createDirectories(p.getParent());Files.write(p,bytes,StandardOpenOption.CREATE_NEW);}else client().putObject(PutObjectRequest.builder().bucket(bucket()).key(key).contentType(type).serverSideEncryption(ServerSideEncryption.AES256).build(),RequestBody.fromBytes(bytes));}catch(IOException|software.amazon.awssdk.core.exception.SdkException e){throw new ApiProblem(503,"FILE_STORAGE_UNAVAILABLE");}}
 byte[] get(String key){try{return local()?Files.readAllBytes(path(key)):client().getObjectAsBytes(GetObjectRequest.builder().bucket(bucket()).key(key).build()).asByteArray();}catch(NoSuchFileException|NoSuchKeyException e){throw new ApiProblem(404,"FILE_NOT_FOUND");}catch(IOException|software.amazon.awssdk.core.exception.SdkException e){throw new ApiProblem(503,"FILE_STORAGE_UNAVAILABLE");}}
 @jakarta.annotation.PreDestroy void close(){if(s3!=null)s3.close();}
}
