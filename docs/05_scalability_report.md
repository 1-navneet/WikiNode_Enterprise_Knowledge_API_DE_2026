# DE CP4 — Scalability Report (Google Pay UPI Database, T0109)

Generated: 2026-11-23

## 1. Dataset and methodology

- Faculty source: [GitHub release `large-data`](https://github.com/edusatyaki/DBMS-Google-Pay-Digital-Payments/releases/tag/large-data) (`large_data.zip`, 262,190,235 bytes, approximately 9.5 million rows).
- Original seed: 250,468 transactions; large dataset expected approximately 20×. Exact loaded counts are recorded below if available.
- Load into an isolated PostgreSQL database; install the **same CP3 indexes**; run `ANALYZE`.
- Measure **optimized workload only**, three times per query using `EXPLAIN (ANALYZE, BUFFERS)`. Write operations must be inside transactions rolled back after execution.
- Large timing values require a summary and three matching execution plans; otherwise they are left blank/unverified. Hardware and cache effects limit cross-run comparisons.

## 2. Row counts (actual imported faculty dataset)

| Table | Rows |
|---|---:|
| cities | 10 |
| merchants | 60000 |
| disputes | 73365 |
| bill_payments | 600000 |
| rewards | 798991 |
| users | 800000 |
| bank_accounts | 1066666 |
| vpas | 1066666 |
| transactions | 5009340 |
| **TOTAL** | **9,475,038** |

## 3. Actual results for all 30 optimized queries

| Query | Seed optimized (ms) | Large optimized (ms) | Growth (×) | Faculty target (ms) | Met? | If not, explanation/action |
|---|---:|---:|---:|---:|:---:|---|
| R01 | 33.821 | 831.318 | 24.580 | 5 | NO | Inspect plan, measure revision and document before/after |
| R02 | 0.041 | 0.271 | 6.610 | 5 | YES | — |
| R03 | 0.043 | 0.108 | 2.512 | 5 | YES | — |
| R04 | 0.062 | 0.758 | 12.226 | 5 | YES | — |
| R05 | 0.080 | 0.126 | 1.575 | 250 | YES | — |
| R06 | 0.730 | 14.523 | 19.895 | 5000 | YES | — |
| R07 | 2.613 | 55.791 | 21.351 | 5000 | YES | — |
| R08 | 359.888 | 4474.441 | 12.433 | 5000 | YES | — |
| R09 | 104.248 | 8237.610 | 79.019 | 5000 | NO | Inspect plan, measure revision and document before/after |
| R10 | 0.037 | 0.038 | 1.027 | 5 | YES | — |
| R11 | 0.030 | 0.284 | 9.467 | 250 | YES | — |
| R12 | 0.019 | 0.059 | 3.105 | 5 | YES | — |
| R13 | 4.292 | 70.001 | 16.310 | 250 | YES | — |
| R14 | 0.140 | 0.226 | 1.614 | 250 | YES | — |
| R15 | 2.967 | 84.623 | 28.521 | 5000 | YES | — |
| R16 | 0.144 | 6.836 | 47.472 | 250 | YES | — |
| R17 | 13.985 | 239.996 | 17.161 | 5000 | YES | — |
| R18 | 43.832 | 810.269 | 18.486 | 5000 | YES | — |
| R19 | 1.545 | 26.838 | 17.371 | 5000 | YES | — |
| R20 | 2.487 | 58.958 | 23.706 | 5000 | YES | — |
| R21 | 0.814 | 13.172 | 16.182 | 250 | YES | — |
| R22 | 0.053 | 0.181 | 3.415 | 5 | YES | — |
| R23 | 13.547 | 13.602 | 1.004 | 250 | YES | — |
| R24 | 0.032 | 0.166 | 5.188 | 5 | YES | — |
| R25 | 18.513 | 177.932 | 9.611 | 5000 | YES | — |
| W01 | 0.615 | 1.063 | 1.728 | 5 | YES | — |
| W02 | 0.447 | 0.712 | 1.593 | 5 | YES | — |
| W03 | 0.385 | 0.059 | 0.153 | 5 | YES | — |
| W04 | 0.719 | 3.835 | 5.334 | 1000 | YES | — |
| W05 | 2.748 | 126.642 | 46.085 | 1000 | YES | — |

## 4. Growth classification

- **Stayed approximately the same (≤2×):** R05, R10, R14, R23, W01, W02, W03
- **Increased between 2× and 20×:** R02, R03, R04, R06, R08, R11, R12, R13, R17, R18, R19, R21, R22, R24, R25, W04
- **Increased more than 20×:** R01, R07, R09, R15, R16, R20, W05

Why: highly selective indexed lookups may stay close to constant, but wide scans, sorting, aggregation and high-offset pagination can grow sharply. Verify reasons using `benchmarks/results/large/*.txt`, not timing ratios alone.

## 5. Queries that missed the faculty targets

| Query | Measured ms | Target ms | Observed scan nodes | Status |
|---|---:|---:|---|---|
| R01 | 831.318 | <5 | Index Scan using idx_gpay_txn_history_page on transactions | Index Only Scan using idx_gpay_vpas_user_vpa on vpas | Needs investigation/retest |
| R09 | 8237.610 | <5000 | Index Scan using idx_gpay_txn_success_pair_time on transactions | Needs investigation/retest |

The table identifies actual misses; it **does not** claim they have been fixed. Save before-and-after plans and new 3-run means for each optimization. If a query cannot meet the target, document the technical reason and remaining limitations.

## 6. Storage footprint

| Dataset | Heap (MiB) | Indexes (MiB) | Total relations (MiB) |
|---|---:|---:|---:|
| Seed with CP3 indexes | 56.88 | 107.67 | 164.76 |
| Faculty 20× large | 1115.26 | 2184.02 | 3299.77 |

Storage values use `pg_relation_size`, `pg_indexes_size`, and `pg_total_relation_size`; total can include TOAST storage. Measure seed and large on comparable PostgreSQL installations.

## 7. Partitioning, sharding, replicas, and caching at 100×

**Partitioning:** see `sql/08_partitioning.sql` and `docs/partitioning_design.md`; monthly `RANGE(initiated_at)` supports time-pruning for R03/R05/R06/R15/R20. Run `bash scripts/measure_partition_pruning.sh gpay_large_cp4` and attach the resulting plan. This is a prototype: PostgreSQL partitioned unique keys must contain the partition key, so the existing `txn_id`-only PK and rewards/disputes references require an explicit migration design.

**Sharding:** payer-keyed sharding localizes payer history but makes payee history and cross-payer merchant settlements distributed; time sharding aids archive analytics but not individual user history. Resolve cross-shard consistency with globally unique IDs, idempotency and reconciliation. No sharding has been implemented.

**Replicas:** eventual-consistency analytics (R06/R08/R15/R17/R19/R20/R25) may run on replicas; immediate checks (R02/R03/R04/R10/R12/R22/R24) and W01–W05 need primary-consistent behavior.

**Caching:** cache immutable merchant metadata/aggregate reports with expiration and invalidation, not live payment decisions. Review data sensitivity and privacy.

**Maintenance:** tune autovacuum based on observed dead tuples and write volume; `ANALYZE` after bulk loads; archive old partitions within retention rules; keep backups, WAL archiving and disaster recovery tests.

## 8. Conclusion and open risks

Executed and plan-verified all 30 optimized queries on the faculty dataset. 2 queries failed their target on this hardware. This benchmark alone does not certify 100× production readiness; remaining risks include index-maintenance cost, deep OFFSET, cross-shard transactions and replica lag.

## 9. Evidence inventory

- `benchmarks/results/large/summary.csv` and `R01.txt`…`W05.txt`: optimized 3-run large dataset timings and plans
- `benchmarks/results/large/row_counts.csv` and `storage.csv`: actual loaded rows and storage
- `benchmarks/results/optimized/storage.csv`: seed storage with same index set
- `benchmarks/results/large/partition_pruning_plan.txt`: partition prototype EXPLAIN evidence
- `benchmarks/results/large/integrity_check.txt`: schema and data checks
