# CP1 schema design — Google Pay UPI

**RDBMS:** PostgreSQL 15+ · **Schema:** `gpay` · **Tables:** 9

## Design choices

The database reproduces the nine CSV files with their exact table and column names. IDs use INTEGER/BIGINT, money uses NUMERIC (not floating point), phone/IFSC/MCC/account suffix and 12-digit UPI references use text-based types to preserve formatting, and event timestamps use TIMESTAMPTZ. Foreign keys use ON DELETE RESTRICT to protect payment history.

At CP1, only PK, FK, UNIQUE, NOT NULL, and CHECK constraints exist. PK/UNIQUE constraints create automatic B-tree indexes; **no hand-tuned index** is created. `vpas(account_id,user_id)` has a composite FK into `bank_accounts(account_id,user_id)` so VPA ownership is consistent. `is_primary` requires an integrity query rather than a partial unique index (forbidden at this phase). External UPI counterparties prevent universal FKs on `transactions.payer_vpa` and `.payee_vpa`.

## Data dictionary (every column)

| Table | Column | Type | Constraints | Why |
|---|---|---|---|---|
| `cities` | `city_id` | `INTEGER` | PRIMARY KEY | City reference key |
| `cities` | `city_name` | `VARCHAR(100)` | NOT NULL | Named city |
| `cities` | `state` | `VARCHAR(100)` | NOT NULL | State for reports |
| `users` | `user_id` | `INTEGER` | PRIMARY KEY | Owner identifier |
| `users` | `full_name` | `VARCHAR(150)` | NOT NULL | User display name |
| `users` | `phone` | `VARCHAR(20)` | NOT NULL, UNIQUE | Phone identifier, not numeric quantity |
| `users` | `email` | `VARCHAR(255)` | UNIQUE; nullable | Optional contact address |
| `users` | `city_id` | `INTEGER` | NOT NULL, REFERENCES | City reference key |
| `users` | `kyc_status` | `VARCHAR(30)` | NOT NULL | Compliance state |
| `users` | `is_blocked` | `BOOLEAN` | NOT NULL | Access control flag |
| `users` | `created_at` | `TIMESTAMPTZ` | NOT NULL | Timezone-aware creation time |
| `bank_accounts` | `account_id` | `INTEGER` | PRIMARY KEY | Linked bank account ID |
| `bank_accounts` | `user_id` | `INTEGER` | NOT NULL, REFERENCES | Owner identifier |
| `bank_accounts` | `bank_name` | `VARCHAR(120)` | NOT NULL | Bank reporting dimension |
| `bank_accounts` | `ifsc` | `VARCHAR(11)` | NOT NULL | Bank branch routing code |
| `bank_accounts` | `account_last4` | `VARCHAR(4)` | NOT NULL | Masked suffix; preserve zeroes |
| `bank_accounts` | `account_type` | `VARCHAR(30)` | NOT NULL | Savings/current classification |
| `bank_accounts` | `is_primary` | `BOOLEAN` | NOT NULL | Default account marker |
| `bank_accounts` | `linked_at` | `TIMESTAMPTZ` | NOT NULL | Account link time |
| `vpas` | `vpa` | `VARCHAR(255)` | PRIMARY KEY | Natural UPI address key |
| `vpas` | `user_id` | `INTEGER` | NOT NULL, REFERENCES | Owner identifier |
| `vpas` | `account_id` | `INTEGER` | NOT NULL; composite FOREIGN KEY | Linked bank account ID |
| `vpas` | `is_active` | `BOOLEAN` | NOT NULL | UPI activation state |
| `vpas` | `created_at` | `TIMESTAMPTZ` | NOT NULL | Timezone-aware creation time |
| `merchants` | `merchant_id` | `INTEGER` | PRIMARY KEY | Merchant link; NULL on P2P |
| `merchants` | `merchant_name` | `VARCHAR(200)` | NOT NULL | Shop display name |
| `merchants` | `mcc` | `VARCHAR(4)` | NOT NULL | Merchant category code |
| `merchants` | `merchant_vpa` | `VARCHAR(255)` | NOT NULL, UNIQUE | Unique shop payment address |
| `merchants` | `city_id` | `INTEGER` | NOT NULL, REFERENCES | City reference key |
| `merchants` | `is_verified` | `BOOLEAN` | NOT NULL | Merchant verification |
| `merchants` | `onboarded_on` | `DATE` | NOT NULL | Onboarding date |
| `transactions` | `txn_id` | `BIGINT` | PRIMARY KEY | Transaction reference |
| `transactions` | `upi_ref` | `VARCHAR(12)` | NOT NULL, UNIQUE | Unique 12-digit UPI reference |
| `transactions` | `txn_type` | `VARCHAR(10)` | NOT NULL | P2M/P2P classification |
| `transactions` | `payer_vpa` | `VARCHAR(255)` | NOT NULL | Sender handle, possibly external |
| `transactions` | `payee_vpa` | `VARCHAR(255)` | NOT NULL | Recipient handle, possibly external |
| `transactions` | `merchant_id` | `INTEGER` | REFERENCES | Merchant link; NULL on P2P |
| `transactions` | `amount` | `NUMERIC(14,2)` | NOT NULL | Exact decimal amount |
| `transactions` | `note` | `TEXT` | nullable | Optional payment description |
| `transactions` | `initiated_at` | `TIMESTAMPTZ` | NOT NULL | Payment initiation time |
| `transactions` | `completed_at` | `TIMESTAMPTZ` | nullable | Nullable completion time |
| `transactions` | `status` | `VARCHAR(30)` | NOT NULL | Current transaction/reward/bill/dispute state |
| `transactions` | `failure_code` | `VARCHAR(30)` | nullable | Optional NPCI error code |
| `rewards` | `reward_id` | `INTEGER` | PRIMARY KEY | Reward identifier |
| `rewards` | `user_id` | `INTEGER` | NOT NULL, REFERENCES | Owner identifier |
| `rewards` | `txn_id` | `BIGINT` | NOT NULL, REFERENCES | Transaction reference |
| `rewards` | `reward_type` | `VARCHAR(30)` | NOT NULL | Reward type code (uppercase; full values verified from faculty CSV) |
| `rewards` | `amount` | `NUMERIC(12,2)` | NOT NULL | Exact decimal amount |
| `rewards` | `status` | `VARCHAR(30)` | NOT NULL | Current transaction/reward/bill/dispute state |
| `rewards` | `issued_at` | `TIMESTAMPTZ` | NOT NULL | Reward issue time |
| `rewards` | `expires_at` | `TIMESTAMPTZ` | NOT NULL | Expiry time |
| `rewards` | `credited_at` | `TIMESTAMPTZ` | nullable | Nullable credit time |
| `bill_payments` | `bill_id` | `INTEGER` | PRIMARY KEY | Bill identifier |
| `bill_payments` | `user_id` | `INTEGER` | NOT NULL, REFERENCES | Owner identifier |
| `bill_payments` | `biller_category` | `VARCHAR(40)` | NOT NULL | Utility category |
| `bill_payments` | `biller_name` | `VARCHAR(150)` | NOT NULL | Service-provider label |
| `bill_payments` | `consumer_number` | `VARCHAR(60)` | NOT NULL | Account reference; preserve zeroes |
| `bill_payments` | `amount` | `NUMERIC(14,2)` | NOT NULL | Exact decimal amount |
| `bill_payments` | `due_date` | `DATE` | NOT NULL | Payment deadline |
| `bill_payments` | `status` | `VARCHAR(30)` | NOT NULL | Current transaction/reward/bill/dispute state |
| `bill_payments` | `paid_at` | `TIMESTAMPTZ` | nullable | Nullable settlement time |
| `disputes` | `dispute_id` | `INTEGER` | PRIMARY KEY | Ticket identifier |
| `disputes` | `txn_id` | `BIGINT` | NOT NULL, REFERENCES | Transaction reference |
| `disputes` | `raised_by` | `INTEGER` | NOT NULL, REFERENCES | Ticket opener FK |
| `disputes` | `reason` | `VARCHAR(80)` | NOT NULL | Complaint reason |
| `disputes` | `raised_at` | `TIMESTAMPTZ` | NOT NULL | Submission time |
| `disputes` | `status` | `VARCHAR(30)` | NOT NULL | Current transaction/reward/bill/dispute state |
| `disputes` | `resolved_at` | `TIMESTAMPTZ` | nullable | Nullable resolution time |

## ER diagram and cardinalities

- `cities` 1:N `users`; `cities` 1:N `merchants`; `users` 1:N `bank_accounts`; `users` 1:N `vpas`; `bank_accounts` 1:N `vpas`.
- `merchants` 1:N `transactions` for P2M only (merchant FK nullable for P2P). `transactions` 1:N `rewards` and 1:N `disputes`.
- `users` 1:N `rewards`, 1:N `bill_payments`, and 1:N `disputes` (raised_by).
- See `diagrams/er_diagram.svg` and `diagrams/er_diagram.mmd`; merchant-to-transaction relationship is optional on the transaction side.

## Functional dependencies and normalization

All tables have atomic columns (1NF). Each uses a one-column primary key (therefore no partial dependence on a composite key, satisfying 2NF). The main FDs and 3NF/BCNF caveats are:

| Table | Functional dependencies | 3NF/BCNF judgment |
|---|---|---|
| cities | `city_id → city_name,state` | BCNF by key |
| users | `user_id → other columns`; `phone → user_id`; non-NULL `email → user_id` | BCNF under declared unique identifiers |
| bank_accounts | `account_id → other columns` | BCNF by account ID; `(account_id,user_id)` constraint supports composite reference |
| vpas | `vpa → user_id,account_id,is_active,created_at`; `account_id → user_id` (via linked-account rule) | `user_id` is redundant for a linked account; strict BCNF/3NF is not claimed |
| merchants | `merchant_id → other columns`; `merchant_vpa → merchant_id` | BCNF under declared keys |
| transactions | `txn_id → other columns`; `upi_ref → txn_id`; P2M `merchant_id → payee_vpa` | Merchant payee address may be redundant; retained as event snapshot and required CSV column |
| rewards | `reward_id → other columns`; `txn_id → payer user_id` in local-user transactions | `user_id` is redundant where payer is known; retained for workload |
| bill_payments | `bill_id → other columns` | BCNF by key |
| disputes | `dispute_id → other columns` | BCNF by key |

**Why retain redundant fields?** The lecturer provides fixed CSV headers and SQL workload. Removing these fields would break the queries. Composite FK and post-load checks help prevent inconsistent records; transaction-time snapshots and external-provider VPAs are additional reasons to preserve payment address strings.

## Integrity checks and source-data caveats

`sql/03_integrity_checks.sql` runs four consistency checks: (1) merchant VPA matches P2M payee, (2) VPA user matches linked bank-account owner, (3) exactly one primary bank account per user, (4) reward owner matches payer when payer VPA is known. It also verifies the nine faculty row counts. More than 12 SQL CHECK constraints cover formats, amounts, statuses, timeline, and P2M/P2P merchant linkage.

| Test | Actual result |
|---|---|
| Complete faculty CSV precheck | **Not run: seed_data.zip not accessible in this environment** |
| PostgreSQL 15+ schema execution and nine-table import | **Not run: PostgreSQL server unavailable here** |
| PostgreSQL FK/UNIQUE/CHECK, integrity and 30-query workload | **Not run; run `bash scripts/test_postgres.sh` locally** |
| Structural, synthetic constraint and mocked benchmarking test suite | PASS locally (see `TEST_REPORT.md`) |

**Evidence required before claiming CP1 complete:** After running `bash scripts/test_postgres.sh` on your Mac with the faculty archive in the repo, copy the real outputs from `validation/load.log`, `validation/integrity.log`, and `validation/workload.log` into a dated result section here. No fabricated pass/fail figures or benchmark timings have been used.

## Unresolved assumptions for complete-data testing

- Constraints deliberately restrict known statuses and transaction amounts. If a faculty data row violates an assumed rule, inspect the row and faculty specification; record the data issue or revise the constraint with an explanation. Do not silently skip rows.
- `email` is unique when supplied; external VPAs do not have FK constraints; each user is assumed to have exactly one primary bank account.
- The schema cannot guarantee all cross-table derived values through simple CHECK constraints; the included integrity SQL checks them after import.


### Reward-type category correction — 16 November 2026

An actual local run of the faculty CSV validator (reported by the team) found that 7,883 of the 39,799 rewards had types outside the previously assumed `CASHBACK`/`SCRATCH_CARD` set. That assumption was incorrect. The schema and validator now require nonempty uppercase reward-type codes (letters, digits and underscore) rather than an incomplete enumeration. **This is a format check, not a complete business-category whitelist.** The updated precheck emits the exact reward-type distribution, which should be reviewed and recorded here after rerunning it. PostgreSQL import and workload execution remain unverified until the team shares the succeeding full-test logs.
