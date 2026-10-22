package com.moishow.identity;
import jakarta.persistence.*;import java.util.UUID;import java.time.Instant;
final class FileModels {
 @Entity(name="PrivateFile") @Table(name="private_file") static class Blob extends Models.Row {
  UUID ownerId;UUID clubId;UUID eventId;String scope;String objectKey;String contentType;long size;String checksum;String status="STAGED";Instant createdAt;
 }
}
