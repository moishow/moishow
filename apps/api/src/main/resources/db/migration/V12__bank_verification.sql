ALTER TABLE reserve_account ADD COLUMN holder_cipher text;

CREATE TABLE bank_verification (
 id uuid PRIMARY KEY,
 version bigint NOT NULL DEFAULT 0,
 user_id uuid NOT NULL REFERENCES app_user(id),
 purpose varchar(24) NOT NULL CHECK (purpose IN ('PERSONAL','RESERVE','RESERVE_HANDOVER')),
 context_id uuid,
 bank_id varchar(100) NOT NULL,
 bank_name varchar(100) NOT NULL,
 account_cipher text NOT NULL,
 holder_cipher text NOT NULL,
 last4 varchar(4) NOT NULL CHECK(last4 ~ '^[0-9]{1,4}$'),
 account_length integer NOT NULL CHECK(account_length BETWEEN 4 AND 34),
 account_fingerprint varchar(64) NOT NULL CHECK(account_fingerprint ~ '^[0-9a-f]{64}$'),
 binding_hash varchar(64) NOT NULL CHECK(binding_hash ~ '^[0-9a-f]{64}$'),
 status varchar(30) NOT NULL CHECK(status IN ('PENDING','HOLDER_CHECK','TRANSFER_DISPATCHED','AWAITING_CODE','VERIFIED','CONSUMED','FAILED','UNKNOWN','LOCKED','EXPIRED')),
 code_hash varchar(64) CHECK(code_hash IS NULL OR code_hash ~ '^[0-9a-f]{64}$'),
 provider_reference varchar(500),
 attempts integer NOT NULL DEFAULT 0 CHECK(attempts BETWEEN 0 AND 5),
 created_at timestamptz NOT NULL,
 phase_at timestamptz NOT NULL,
 expires_at timestamptz NOT NULL,
 verified_at timestamptz,
 consumed_at timestamptz,
 CHECK((purpose='PERSONAL' AND context_id IS NULL) OR (purpose<>'PERSONAL' AND context_id IS NOT NULL)),
 CHECK(expires_at>created_at),
 CHECK(char_length(last4)<=account_length-2),
 CHECK(status NOT IN ('AWAITING_CODE','VERIFIED','CONSUMED') OR code_hash IS NOT NULL),
 CHECK(status NOT IN ('VERIFIED','CONSUMED') OR verified_at IS NOT NULL),
 CHECK((status='CONSUMED')=(consumed_at IS NOT NULL))
);
CREATE INDEX bank_verification_owner_recent ON bank_verification(user_id,created_at DESC);
CREATE INDEX bank_verification_account_day ON bank_verification(account_fingerprint,created_at);
CREATE INDEX bank_verification_reentry ON bank_verification(user_id,purpose,context_id,expires_at) WHERE consumed_at IS NULL;
