CREATE TABLE private_file(id uuid PRIMARY KEY,version bigint NOT NULL,owner_id uuid NOT NULL REFERENCES app_user(id),club_id uuid REFERENCES club(id),event_id uuid REFERENCES club_event(id),scope varchar(20) NOT NULL CHECK(scope IN ('POST','PAYMENT','EXPENSE','DISPUTE')),object_key varchar(255) NOT NULL UNIQUE,content_type varchar(100) NOT NULL,size bigint NOT NULL CHECK(size BETWEEN 1 AND 10485760),checksum varchar(64) NOT NULL,status varchar(20) NOT NULL CHECK(status IN ('STAGED','ATTACHED','DELETED')),created_at timestamptz NOT NULL);
CREATE INDEX private_file_owner ON private_file(owner_id);
ALTER TABLE community_post_photo ADD CONSTRAINT post_photo_file_fk FOREIGN KEY(file_id) REFERENCES private_file(id);

ALTER TABLE platform_case_photo ADD CONSTRAINT case_photo_file_fk FOREIGN KEY(file_id) REFERENCES private_file(id);
