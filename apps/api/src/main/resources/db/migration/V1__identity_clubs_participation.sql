CREATE TABLE app_user (
 id uuid PRIMARY KEY, version bigint NOT NULL DEFAULT 0,
 provider varchar(20) NOT NULL CHECK(provider IN ('GOOGLE','APPLE','KAKAO')),
 subject varchar(255) NOT NULL, phone varchar(20) UNIQUE, nickname varchar(50),
 status varchar(20) NOT NULL CHECK(status IN ('PENDING','ACTIVE','DELETED')),
 UNIQUE(provider,subject), CHECK(status<>'ACTIVE' OR (phone IS NOT NULL AND nickname IS NOT NULL))
);
CREATE TABLE service_session (
 token_hash varchar(64) PRIMARY KEY,user_id uuid NOT NULL REFERENCES app_user(id),
 scope varchar(20) NOT NULL CHECK(scope IN ('ONBOARDING','ACTIVE')),expires_at timestamptz NOT NULL,revoked boolean NOT NULL DEFAULT false
);
CREATE INDEX session_user_idx ON service_session(user_id);
CREATE TABLE login_nonce(id uuid PRIMARY KEY,version bigint NOT NULL,nonce varchar(64) NOT NULL,expires_at timestamptz NOT NULL,consumed boolean NOT NULL);
CREATE TABLE sms_challenge(
 id uuid PRIMARY KEY,version bigint NOT NULL,user_id uuid NOT NULL REFERENCES app_user(id),phone varchar(20) NOT NULL,
 code_hash varchar(255) NOT NULL,created_at timestamptz NOT NULL,expires_at timestamptz NOT NULL,verified_at timestamptz,
 attempts integer NOT NULL CHECK(attempts BETWEEN 0 AND 5),consumed boolean NOT NULL
);
CREATE INDEX sms_phone_time_idx ON sms_challenge(phone,created_at);
CREATE TABLE club(id uuid PRIMARY KEY,version bigint NOT NULL,name varchar(100) NOT NULL,join_mode varchar(20) NOT NULL CHECK(join_mode IN ('IMMEDIATE','APPROVAL')),status varchar(20) NOT NULL CHECK(status IN ('ACTIVE','DISSOLVING','DISSOLVED')),owner_id uuid NOT NULL REFERENCES app_user(id));
CREATE TABLE membership(
 id uuid PRIMARY KEY,version bigint NOT NULL,club_id uuid NOT NULL REFERENCES club(id),user_id uuid NOT NULL REFERENCES app_user(id),nickname varchar(50),
 role varchar(20) NOT NULL CHECK(role IN ('OWNER','ADMIN','MEMBER')),status varchar(20) NOT NULL CHECK(status IN ('NONE','PENDING','ACTIVE','LEFT','EXPELLED')),
 expelled_history boolean NOT NULL,blacklisted boolean NOT NULL,UNIQUE(club_id,user_id)
);
CREATE INDEX membership_user_idx ON membership(user_id,status);
CREATE TABLE club_invitation(id uuid PRIMARY KEY,version bigint NOT NULL,club_id uuid NOT NULL REFERENCES club(id),token_hash varchar(64) NOT NULL UNIQUE,expires_at timestamptz NOT NULL);
CREATE TABLE club_event(
 id uuid PRIMARY KEY,version bigint NOT NULL,club_id uuid NOT NULL REFERENCES club(id),host_id uuid NOT NULL REFERENCES app_user(id),responsible_id uuid NOT NULL REFERENCES app_user(id),
 title varchar(100) NOT NULL,kind varchar(20) NOT NULL CHECK(kind IN ('REGULAR','LIGHTNING')),public_event boolean NOT NULL,starts_at timestamptz NOT NULL,ends_at timestamptz NOT NULL,
 CHECK(ends_at>starts_at),CHECK(NOT public_event OR kind='LIGHTNING')
);
CREATE INDEX event_club_idx ON club_event(club_id);
CREATE TABLE event_round(
 id uuid PRIMARY KEY,version bigint NOT NULL,event_id uuid NOT NULL REFERENCES club_event(id),capacity integer NOT NULL CHECK(capacity BETWEEN 1 AND 10000),closes_at timestamptz NOT NULL,
 cancellation_fee bigint NOT NULL CHECK(cancellation_fee BETWEEN 0 AND 9007199254740991)
);
CREATE TABLE participation(
 id uuid PRIMARY KEY,version bigint NOT NULL,round_id uuid NOT NULL REFERENCES event_round(id),user_id uuid NOT NULL REFERENCES app_user(id),
 status varchar(20) NOT NULL CHECK(status IN ('CONFIRMED','WAITLISTED','LATE_REQUESTED','CANCELLED','NO_SHOW')),ever_confirmed boolean NOT NULL,
 agreed_fee bigint NOT NULL CHECK(agreed_fee BETWEEN 0 AND 9007199254740991),UNIQUE(round_id,user_id)
);
CREATE INDEX participation_user_idx ON participation(user_id);
CREATE TABLE command_receipt(
 id uuid PRIMARY KEY,version bigint NOT NULL,user_id uuid NOT NULL REFERENCES app_user(id),request_key varchar(36) NOT NULL,operation varchar(255) NOT NULL,body_hash varchar(64) NOT NULL,response_json text NOT NULL,
 UNIQUE(user_id,operation,request_key)
);
