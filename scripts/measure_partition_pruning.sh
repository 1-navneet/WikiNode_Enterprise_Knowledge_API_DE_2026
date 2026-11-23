#!/usr/bin/env bash
# Demonstrate partition pruning on actual large-data transactions without modifying them.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
DB="${1:-gpay_large_cp4}"
mkdir -p benchmarks/results/large
psql -X -v ON_ERROR_STOP=1 -d "$DB" -f sql/08_partitioning.sql \
  > benchmarks/results/large/partition_design.txt
psql -X -v ON_ERROR_STOP=1 -d "$DB" <<'SQL' \
  > benchmarks/results/large/partition_pruning_plan.txt
BEGIN;
-- The prototype is intentionally separate from gpay.transactions.
-- Insert only 10k actual June payments for this one transaction.
INSERT INTO gpay_scale.transactions_partitioned
SELECT * FROM gpay.transactions
WHERE initiated_at >= TIMESTAMPTZ '2026-06-01 00:00:00+00'
  AND initiated_at < TIMESTAMPTZ '2026-07-01 00:00:00+00'
LIMIT 10000;
ANALYZE gpay_scale.transactions_partitioned;
\echo '=== FILTERED: June 2026 should prune other monthly partitions ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM gpay_scale.transactions_partitioned
WHERE initiated_at >= TIMESTAMPTZ '2026-06-01 00:00:00+00'
  AND initiated_at < TIMESTAMPTZ '2026-07-01 00:00:00+00';
\echo '=== UNFILTERED: no time predicate ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM gpay_scale.transactions_partitioned;
ROLLBACK;
SQL
printf 'Saved partition plans; sample inserts were ROLLED BACK.\n'
