-- CP4 design prototype: monthly RANGE partitioning of Google Pay transactions.
-- This is a NON-DESTRUCTIVE, separate schema; it does not alter the existing gpay tables.
-- Use: psql -v ON_ERROR_STOP=1 -d <database> -f sql/08_partitioning.sql
-- PostgreSQL partitioned PRIMARY KEY/UNIQUE must include ALL partition key columns.
-- Existing gpay.transactions has PRIMARY KEY(txn_id) and UNIQUE(upi_ref), which
-- cannot be preserved globally on RANGE(initiated_at) without redesign.
-- Existing gpay.rewards/disputes reference txn_id alone, so a real migration
-- must redesign those foreign keys or choose a different partition strategy.
BEGIN;
CREATE SCHEMA IF NOT EXISTS gpay_scale;
CREATE TABLE IF NOT EXISTS gpay_scale.transactions_partitioned (
  txn_id BIGINT NOT NULL,
  upi_ref VARCHAR(12) NOT NULL,
  txn_type VARCHAR(10) NOT NULL,
  payer_vpa VARCHAR(255) NOT NULL,
  payee_vpa VARCHAR(255) NOT NULL,
  merchant_id INTEGER,
  amount NUMERIC(14,2) NOT NULL,
  note TEXT,
  initiated_at TIMESTAMPTZ NOT NULL,
  completed_at TIMESTAMPTZ,
  status VARCHAR(30) NOT NULL,
  failure_code VARCHAR(30),
  CONSTRAINT txn_partition_pk PRIMARY KEY (txn_id, initiated_at),
  CONSTRAINT txn_partition_ref_uq UNIQUE (upi_ref, initiated_at),
  CONSTRAINT txn_partition_ref_format CHECK (upi_ref ~ '^[0-9]{12}$'),
  CONSTRAINT txn_partition_type CHECK (txn_type IN ('P2P','P2M')),
  CONSTRAINT txn_partition_amount CHECK (amount > 0 AND amount <= 100000),
  CONSTRAINT txn_partition_status CHECK (status IN ('SUCCESS','FAILED','PENDING','REVERSED','REFUNDED')),
  CONSTRAINT txn_partition_merchant CHECK ((txn_type='P2M' AND merchant_id IS NOT NULL) OR (txn_type='P2P' AND merchant_id IS NULL)),
  CONSTRAINT txn_partition_parties CHECK (payer_vpa <> payee_vpa),
  CONSTRAINT txn_partition_completion CHECK (completed_at IS NULL OR completed_at >= initiated_at),
  CONSTRAINT txn_partition_pending CHECK (status <> 'PENDING' OR completed_at IS NULL),
  CONSTRAINT txn_partition_refund CHECK (status <> 'REFUNDED' OR txn_type='P2M')
) PARTITION BY RANGE (initiated_at);
-- UTC boundary dates; queries should use matching timestamptz ranges.
CREATE TABLE IF NOT EXISTS gpay_scale.transactions_2026_05 PARTITION OF gpay_scale.transactions_partitioned
  FOR VALUES FROM ('2026-05-01 00:00:00+00') TO ('2026-06-01 00:00:00+00');
CREATE TABLE IF NOT EXISTS gpay_scale.transactions_2026_06 PARTITION OF gpay_scale.transactions_partitioned
  FOR VALUES FROM ('2026-06-01 00:00:00+00') TO ('2026-07-01 00:00:00+00');
CREATE TABLE IF NOT EXISTS gpay_scale.transactions_2026_07 PARTITION OF gpay_scale.transactions_partitioned
  FOR VALUES FROM ('2026-07-01 00:00:00+00') TO ('2026-08-01 00:00:00+00');
-- Catch out-of-range rows; investigate volume here and add partitions in advance.
CREATE TABLE IF NOT EXISTS gpay_scale.transactions_default PARTITION OF gpay_scale.transactions_partitioned DEFAULT;
CREATE INDEX IF NOT EXISTS txn_partition_payer_time ON gpay_scale.transactions_partitioned (payer_vpa, initiated_at DESC);
CREATE INDEX IF NOT EXISTS txn_partition_payee_time ON gpay_scale.transactions_partitioned (payee_vpa, initiated_at DESC);
CREATE INDEX IF NOT EXISTS txn_partition_merchant_time ON gpay_scale.transactions_partitioned (merchant_id, initiated_at DESC);
COMMIT;
-- EXPLAIN demo (no seed data loaded into the prototype): shows plans and pruning
-- with bounds, but timing comparisons require real data and EXPLAIN ANALYZE.
EXPLAIN (COSTS OFF)
SELECT txn_id, amount FROM gpay_scale.transactions_partitioned
WHERE initiated_at >= TIMESTAMPTZ '2026-06-01 00:00:00+00'
  AND initiated_at < TIMESTAMPTZ '2026-07-01 00:00:00+00';
-- To test with actual seed data after confirming all timestamps have partitions:
-- INSERT INTO gpay_scale.transactions_partitioned
-- SELECT * FROM gpay.transactions;
-- ANALYZE gpay_scale.transactions_partitioned;
-- EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) FROM ... WHERE ...;
