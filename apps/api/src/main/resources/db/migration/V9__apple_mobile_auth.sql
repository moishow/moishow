CREATE TABLE apple_mobile_auth_attempt (
 id uuid PRIMARY KEY, version bigint NOT NULL DEFAULT 0,
 state_hash varchar(64) NOT NULL UNIQUE, nonce varchar(128) NOT NULL,
 pkce_challenge varchar(43) NOT NULL, expires_at timestamptz NOT NULL,
 callback_consumed boolean NOT NULL DEFAULT false,
 ticket_hash varchar(64) UNIQUE, identity_subject varchar(255),
 ticket_expires_at timestamptz, exchanged boolean NOT NULL DEFAULT false
);
CREATE INDEX apple_mobile_auth_expiry ON apple_mobile_auth_attempt(expires_at);
