CREATE TABLE personal_bank_account (
 id uuid PRIMARY KEY,
 version bigint NOT NULL CHECK(version>0),
 user_id uuid NOT NULL REFERENCES app_user(id),
 bank_name varchar(100) NOT NULL,
 account_cipher text NOT NULL,
 holder_cipher text NOT NULL,
 verification_reference varchar(500) NOT NULL,
 verified_at timestamptz NOT NULL,
 current boolean NOT NULL DEFAULT true,
 UNIQUE(user_id,version)
);
CREATE UNIQUE INDEX personal_bank_account_current ON personal_bank_account(user_id) WHERE current;
