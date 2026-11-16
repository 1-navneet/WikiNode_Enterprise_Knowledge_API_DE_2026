-- Google Pay DBMS: baseline schema (PostgreSQL 15+)
-- Deliberately no performance indexes beyond PK/UNIQUE constraints.
CREATE SCHEMA IF NOT EXISTS gpay;
SET search_path TO gpay;

CREATE TABLE cities (
 city_id INTEGER PRIMARY KEY,
 city_name VARCHAR(100) NOT NULL,
 state VARCHAR(100) NOT NULL,
 CONSTRAINT cities_name_nonempty CHECK (length(trim(city_name)) > 0),
 CONSTRAINT cities_state_nonempty CHECK (length(trim(state)) > 0)
);

CREATE TABLE users (
 user_id INTEGER PRIMARY KEY,
 full_name VARCHAR(150) NOT NULL,
 phone VARCHAR(20) NOT NULL UNIQUE,
 email VARCHAR(255) UNIQUE,
 city_id INTEGER NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
 kyc_status VARCHAR(30) NOT NULL,
 is_blocked BOOLEAN NOT NULL,
 created_at TIMESTAMPTZ NOT NULL,
 CONSTRAINT users_phone_format CHECK (phone ~ '^[0-9]{10}$'),
 CONSTRAINT users_kyc_status CHECK (kyc_status IN ('VERIFIED','PENDING','REJECTED','NOT_STARTED','UNVERIFIED')),
 CONSTRAINT users_email_format CHECK (email IS NULL OR position('@' in email) > 1)
);

CREATE TABLE bank_accounts (
 account_id INTEGER PRIMARY KEY,
 user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
 bank_name VARCHAR(120) NOT NULL,
 ifsc VARCHAR(11) NOT NULL,
 account_last4 VARCHAR(4) NOT NULL,
 account_type VARCHAR(30) NOT NULL,
 is_primary BOOLEAN NOT NULL,
 linked_at TIMESTAMPTZ NOT NULL,
 CONSTRAINT bank_ifsc_format CHECK (ifsc ~ '^[A-Z]{4}0[A-Z0-9]{6}$'),
 CONSTRAINT bank_last4_format CHECK (account_last4 ~ '^[0-9]{4}$'),
 CONSTRAINT bank_account_type CHECK (account_type IN ('SAVINGS','CURRENT','SALARY','NRE','NRO')),
 CONSTRAINT bank_account_owner_candidate_key UNIQUE (account_id, user_id)
);

CREATE TABLE vpas (
 vpa VARCHAR(255) PRIMARY KEY,
 user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
 account_id INTEGER NOT NULL,
 is_active BOOLEAN NOT NULL,
 created_at TIMESTAMPTZ NOT NULL,
 CONSTRAINT vpa_format CHECK (vpa ~ '^[^ @]+@[^ @]+$'),
 CONSTRAINT vpa_account_same_owner FOREIGN KEY (account_id, user_id)
   REFERENCES bank_accounts(account_id, user_id) ON DELETE RESTRICT
);

CREATE TABLE merchants (
 merchant_id INTEGER PRIMARY KEY,
 merchant_name VARCHAR(200) NOT NULL,
 mcc VARCHAR(4) NOT NULL,
 merchant_vpa VARCHAR(255) NOT NULL UNIQUE,
 city_id INTEGER NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
 is_verified BOOLEAN NOT NULL,
 onboarded_on DATE NOT NULL,
 CONSTRAINT merchant_mcc_format CHECK (mcc ~ '^[0-9]{4}$'),
 CONSTRAINT merchant_vpa_format CHECK (merchant_vpa ~ '^[^ @]+@[^ @]+$')
);

CREATE TABLE transactions (
 txn_id BIGINT PRIMARY KEY,
 upi_ref VARCHAR(12) NOT NULL UNIQUE,
 txn_type VARCHAR(10) NOT NULL,
 payer_vpa VARCHAR(255) NOT NULL,
 payee_vpa VARCHAR(255) NOT NULL,
 merchant_id INTEGER REFERENCES merchants(merchant_id) ON DELETE RESTRICT,
 amount NUMERIC(14,2) NOT NULL,
 note TEXT,
 initiated_at TIMESTAMPTZ NOT NULL,
 completed_at TIMESTAMPTZ,
 status VARCHAR(30) NOT NULL,
 failure_code VARCHAR(30),
 CONSTRAINT txn_upi_ref_format CHECK (upi_ref ~ '^[0-9]{12}$'),
 CONSTRAINT txn_type_valid CHECK (txn_type IN ('P2P','P2M')),
 CONSTRAINT txn_amount_positive CHECK (amount > 0 AND amount <= 100000),
 CONSTRAINT txn_status_valid CHECK (status IN ('SUCCESS','FAILED','PENDING','REVERSED','REFUNDED')),
 CONSTRAINT txn_merchant_consistency CHECK ((txn_type='P2M' AND merchant_id IS NOT NULL) OR (txn_type='P2P' AND merchant_id IS NULL)),
 CONSTRAINT txn_distinct_parties CHECK (payer_vpa <> payee_vpa),
 CONSTRAINT txn_completion_order CHECK (completed_at IS NULL OR completed_at >= initiated_at),
 CONSTRAINT txn_pending_incomplete CHECK (status <> 'PENDING' OR completed_at IS NULL),
 CONSTRAINT txn_failure_code_nonempty CHECK (failure_code IS NULL OR length(trim(failure_code)) > 0),
 CONSTRAINT txn_refunds_are_merchant_only CHECK (status <> 'REFUNDED' OR txn_type = 'P2M')
);

CREATE TABLE rewards (
 reward_id INTEGER PRIMARY KEY,
 user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
 txn_id BIGINT NOT NULL REFERENCES transactions(txn_id) ON DELETE RESTRICT,
 reward_type VARCHAR(30) NOT NULL,
 amount NUMERIC(12,2) NOT NULL,
 status VARCHAR(30) NOT NULL,
 issued_at TIMESTAMPTZ NOT NULL,
 expires_at TIMESTAMPTZ NOT NULL,
 credited_at TIMESTAMPTZ,
 CONSTRAINT reward_amount_nonnegative CHECK (amount >= 0),
 -- Faculty CSV contains additional reward types beyond CASHBACK and SCRATCH_CARD.
 -- Require a nonempty uppercase code without prematurely guessing the full enumeration.
 CONSTRAINT reward_type_valid CHECK (reward_type ~ '^[A-Z][A-Z0-9_]*$'),
 CONSTRAINT reward_status_valid CHECK (status IN ('UNSCRATCHED','CREDITED','EXPIRED','SCRATCHED')),
 CONSTRAINT reward_expiry_after_issue CHECK (expires_at >= issued_at)
);

CREATE TABLE bill_payments (
 bill_id INTEGER PRIMARY KEY,
 user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
 biller_category VARCHAR(40) NOT NULL,
 biller_name VARCHAR(150) NOT NULL,
 consumer_number VARCHAR(60) NOT NULL,
 amount NUMERIC(14,2) NOT NULL,
 due_date DATE NOT NULL,
 status VARCHAR(30) NOT NULL,
 paid_at TIMESTAMPTZ,
 CONSTRAINT bill_amount_positive CHECK (amount > 0),
 CONSTRAINT bill_status_valid CHECK (status IN ('PAID','DUE','OVERDUE','FAILED','CANCELLED')),
 CONSTRAINT bill_consumer_nonempty CHECK (length(trim(consumer_number)) > 0),
 CONSTRAINT bill_biller_nonempty CHECK (length(trim(biller_name)) > 0)
);

CREATE TABLE disputes (
 dispute_id INTEGER PRIMARY KEY,
 txn_id BIGINT NOT NULL REFERENCES transactions(txn_id) ON DELETE RESTRICT,
 raised_by INTEGER NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
 reason VARCHAR(80) NOT NULL,
 raised_at TIMESTAMPTZ NOT NULL,
 status VARCHAR(30) NOT NULL,
 resolved_at TIMESTAMPTZ,
 CONSTRAINT dispute_status_valid CHECK (status IN ('OPEN','IN_PROGRESS','RESOLVED','REJECTED','CLOSED')),
 CONSTRAINT dispute_resolution_order CHECK (resolved_at IS NULL OR resolved_at >= raised_at),
 CONSTRAINT dispute_reason_nonempty CHECK (length(trim(reason)) > 0)
);
-- Note: intentionally omit a UNIQUE constraint on one primary account per user here:
-- it requires a partial unique index, which Phase 2 prohibits. Verify by integrity query.
-- Avoid FK on payer/payee VPAs: cross-app UPI handles can be external.
-- A composite VPA/account FK does ensure the VPA and its linked account have the same owner.
