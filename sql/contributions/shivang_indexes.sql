-- DE CP3: PostgreSQL workload index contribution
-- Contributor: Shivang Agarwal
-- Project: Google Pay Digital Payments Database
--
-- Based on sql/01_schema.sql and the committed CP2 plans in
-- benchmarks/results/baseline. Existing PK/UNIQUE indexes are not duplicated.
-- Apply only to a database on which this contribution is authorized.

SET search_path TO gpay;

-- R01, R03, R14, R18, R22: locate a user's VPAs and follow them to accounts.
-- user_id is the equality key; vpa supports the transaction join. account_id
-- and is_active cover the payment-screen lookup where possible.
CREATE INDEX IF NOT EXISTS idx_gpay_vpas_user_vpa
    ON vpas (user_id, vpa)
    INCLUDE (account_id, is_active);

-- R22: find the user's linked accounts; user_id is not the leading key of any
-- existing bank_accounts index (the existing composite unique key leads with
-- account_id).
CREATE INDEX IF NOT EXISTS idx_gpay_bank_accounts_user
    ON bank_accounts (user_id);

CREATE INDEX IF NOT EXISTS idx_gpay_vpas_account
    ON vpas (account_id)
    INCLUDE (vpa, is_active);

-- R01: history lookup on either side of a payment, newest first. The separate
-- indexes are needed because payer_vpa and payee_vpa are alternate predicates.
CREATE INDEX IF NOT EXISTS idx_gpay_txn_payer_time
    ON transactions (payer_vpa, initiated_at DESC);

CREATE INDEX IF NOT EXISTS idx_gpay_txn_payee_time
    ON transactions (payee_vpa, initiated_at DESC);

-- R04 and W02: find old pending rows in time order and locate the oldest
-- pending txn_id for the callback. The partial predicate keeps settled rows out.
CREATE INDEX IF NOT EXISTS idx_gpay_txn_pending_time
    ON transactions (initiated_at, txn_id)
    WHERE status = 'PENDING';

CREATE INDEX IF NOT EXISTS idx_gpay_txn_pending_id
    ON transactions (txn_id)
    WHERE status = 'PENDING';

-- R05 and R19: merchant-specific time lookups, last payment of any status, and
-- successful-payment counts. Keep all statuses because R19's last_payment_at
-- subquery has no status filter; INCLUDE lets that query check status from the
-- index while using the same merchant/time ordering.
CREATE INDEX IF NOT EXISTS idx_gpay_txn_merchant_time
    ON transactions (merchant_id, initiated_at DESC)
    INCLUDE (status);

-- R06 and R15: successful transactions in a time window across merchants/cities.
-- Time is first because these queries constrain a date range across merchants.
CREATE INDEX IF NOT EXISTS idx_gpay_txn_success_time_merchant
    ON transactions (initiated_at, merchant_id)
    INCLUDE (amount)
    WHERE status = 'SUCCESS';

-- R09: feed successful rows to the window function grouped and ordered by
-- payer, payee, and initiation time. The baseline plan shows this as a major
-- full-table/window-sort cost.
CREATE INDEX IF NOT EXISTS idx_gpay_txn_success_pair_time
    ON transactions (payer_vpa, payee_vpa, initiated_at)
    WHERE status = 'SUCCESS';

-- R10 and W03: user-specific unscratched rewards, oldest reward first.
CREATE INDEX IF NOT EXISTS idx_gpay_rewards_user_unscratched
    ON rewards (user_id, reward_id)
    WHERE status = 'UNSCRATCHED';

-- R11 and W04: expiry queue in expiry order; only active scratch cards included.
CREATE INDEX IF NOT EXISTS idx_gpay_rewards_unscratched_expiry
    ON rewards (expires_at)
    WHERE status = 'UNSCRATCHED';

-- R12 and W05: due bills for a user and the global overdue processing queue.
CREATE INDEX IF NOT EXISTS idx_gpay_bills_due_user_date
    ON bill_payments (user_id, due_date)
    WHERE status = 'DUE';

CREATE INDEX IF NOT EXISTS idx_gpay_bills_due_date
    ON bill_payments (due_date)
    WHERE status = 'DUE';

-- R16: open disputes in age order for the SLA queue.
CREATE INDEX IF NOT EXISTS idx_gpay_disputes_open_raised
    ON disputes (raised_at)
    WHERE status = 'OPEN';

-- R23: provide the requested newest-first order and selected values from the
-- index for the deep-offset operations page. Large INCLUDE payload increases
-- index size, so confirm its write/storage cost during CP3 benchmarking.
CREATE INDEX IF NOT EXISTS idx_gpay_txn_history_page
    ON transactions (initiated_at DESC)
    INCLUDE (txn_id, upi_ref, txn_type, amount, status);

-- Queries needing query rewrites rather than a sound index-only fix:
-- R03/R14/R20 apply DATE()/EXTRACT() to initiated_at; make predicates
-- half-open timestamp ranges before expecting a time index to narrow the scan.
-- R08 groups by a timestamp-to-date expression and scans a broad population.
-- R13 uses NOT IN over nullable transactions.merchant_id; P2P rows make the
-- subquery contain NULL, so the original predicate can return no merchants.
-- Replace with NOT EXISTS in the optimized workload after result validation.
-- R19's paired scalar subqueries are candidates for a single grouped join.
-- R21's leading-wildcard ILIKE needs pg_trgm, which is intentionally not
-- enabled here; evaluate extension availability before adding a GIN index.
-- R25 has a broad June-onward predicate and an aggregate; inspect actual data
-- distribution before selecting a partial or BRIN strategy.
