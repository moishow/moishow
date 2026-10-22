ALTER TABLE club ADD COLUMN description varchar(1000) NOT NULL DEFAULT '';
ALTER TABLE club ADD COLUMN region varchar(100) NOT NULL DEFAULT '';
ALTER TABLE club ADD COLUMN category varchar(100) NOT NULL DEFAULT '';
ALTER TABLE club ADD COLUMN image_file_id uuid REFERENCES private_file(id);
ALTER TABLE membership ADD COLUMN request_memo varchar(1000) NOT NULL DEFAULT '';
ALTER TABLE participation ADD COLUMN request_memo varchar(1000) NOT NULL DEFAULT '';
ALTER TABLE membership DROP CONSTRAINT membership_status_check;
ALTER TABLE membership ADD CONSTRAINT membership_status_check CHECK(status IN ('NONE','PENDING','ACTIVE','LEFT','EXPELLED','REJECTED'));
ALTER TABLE participation DROP CONSTRAINT participation_status_check;
ALTER TABLE participation ADD CONSTRAINT participation_status_check CHECK(status IN ('CONFIRMED','WAITLISTED','LATE_REQUESTED','CANCELLED','NO_SHOW','REJECTED'));
ALTER TABLE participation ADD CONSTRAINT rejected_not_confirmed CHECK(status<>'REJECTED' OR NOT ever_confirmed);
CREATE TABLE identity_request_decision(
 id uuid PRIMARY KEY, version bigint NOT NULL, club_id uuid NOT NULL REFERENCES club(id),round_id uuid REFERENCES event_round(id),user_id uuid NOT NULL REFERENCES app_user(id),
 kind varchar(20) NOT NULL CHECK(kind IN ('MEMBERSHIP','LATE_JOIN')),status varchar(20) NOT NULL CHECK(status IN ('SUBMITTED','APPROVED','REJECTED')),
 memo varchar(1000) NOT NULL,reason varchar(1000) NOT NULL,created_at timestamptz NOT NULL,created_by uuid NOT NULL REFERENCES app_user(id),
 CHECK((kind='MEMBERSHIP' AND round_id IS NULL) OR (kind='LATE_JOIN' AND round_id IS NOT NULL))
);
CREATE INDEX identity_request_club_idx ON identity_request_decision(club_id,created_at,id);
CREATE INDEX identity_request_round_idx ON identity_request_decision(round_id,created_at,id);
