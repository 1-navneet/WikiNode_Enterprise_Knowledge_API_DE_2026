# CP2 — Baseline Query Execution Timings

**Date:** 2026-11-17
**Project:** Google Pay Digital Payments Database
**Database:** PostgreSQL 18.7
**Benchmark:** 30 queries, 3 executions per query

## Objective

Measure the performance of the original SQL workload before query and index optimization.

## Methodology

- Loaded all nine CSV datasets into the `gpay` schema.
- Verified that the loaded row counts match the expected counts.
- Executed 25 read queries and 5 write queries.
- Used `EXPLAIN (ANALYZE, BUFFERS)` for each execution.
- Repeated each query three times and calculated the average.
- Executed write queries within transactions that were rolled back.
- Recorded execution plans and scan types.

## Dataset

| Table | Rows |
|---|---:|
| cities | 10 |
| users | 40,000 |
| bank_accounts | 53,333 |
| vpas | 53,333 |
| merchants | 3,000 |
| transactions | 250,468 |
| rewards | 39,799 |
| bill_payments | 30,000 |
| disputes | 3,569 |

## Baseline Results

All timings are actual PostgreSQL EXPLAIN ANALYZE execution times in milliseconds. Runs appear in their original execution order.

| Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) | Median (ms) | Scan nodes |
|---|---|---:|---:|---:|---:|---:|---|
| R01 | READ | 32.218 | 23.921 | 21.393 | 25.844 | 23.921 | Seq Scan on transactions \| Seq Scan on vpas |
| R02 | READ | 0.063 | 0.063 | 0.035 | 0.054 | 0.063 | Index Scan using vpas_pkey on vpas \| Index Scan using users_pkey on users |
| R03 | READ | 18.074 | 15.873 | 14.284 | 16.077 | 15.873 | Seq Scan on transactions \| Seq Scan on vpas |
| R04 | READ | 8.295 | 8.196 | 7.785 | 8.092 | 8.196 | Seq Scan on transactions |
| R05 | READ | 7.354 | 7.897 | 7.384 | 7.545 | 7.384 | Seq Scan on transactions |
| R06 | READ | 8.002 | 7.802 | 7.220 | 7.675 | 7.802 | Seq Scan on transactions \| Index Scan using merchants_pkey on merchants |
| R07 | READ | 8.180 | 8.107 | 7.801 | 8.029 | 8.107 | Seq Scan on transactions \| Index Scan using vpas_pkey on vpas \| Index Scan using bank_account_owner_candidate_key on bank_accounts |
| R08 | READ | 356.004 | 336.037 | 327.904 | 339.982 | 336.037 | Seq Scan on transactions |
| R09 | READ | 840.060 | 905.007 | 865.412 | 870.160 | 865.412 | Seq Scan on transactions |
| R10 | READ | 1.773 | 1.941 | 2.038 | 1.917 | 1.941 | Seq Scan on rewards |
| R11 | READ | 2.395 | 2.760 | 2.798 | 2.651 | 2.760 | Seq Scan on rewards |
| R12 | READ | 1.888 | 1.110 | 2.016 | 1.671 | 1.888 | Seq Scan on bill_payments |
| R13 | READ | 38.881 | 29.172 | 23.951 | 30.668 | 29.172 | Seq Scan on merchants \| Seq Scan on transactions |
| R14 | READ | 18.963 | 22.604 | 22.004 | 21.190 | 22.004 | Seq Scan on transactions \| Seq Scan on vpas \| Index Scan using merchants_pkey on merchants |
| R15 | READ | 9.410 | 8.987 | 9.358 | 9.252 | 9.358 | Seq Scan on transactions \| Seq Scan on merchants |
| R16 | READ | 0.363 | 0.324 | 0.377 | 0.355 | 0.363 | Seq Scan on disputes \| Index Scan using transactions_pkey on transactions |
| R17 | READ | 15.011 | 13.974 | 12.775 | 13.920 | 13.974 | Seq Scan on transactions |
| R18 | READ | 27.313 | 25.342 | 23.186 | 25.280 | 25.342 | Seq Scan on transactions \| Seq Scan on vpas \| Seq Scan on users |
| R19 | READ | 4169.152 | 4128.686 | 4160.152 | 4152.663 | 4160.152 | Seq Scan on merchants \| Seq Scan on transactions |
| R20 | READ | 10.245 | 9.922 | 9.591 | 9.919 | 9.922 | Seq Scan on transactions |
| R21 | READ | 0.915 | 0.886 | 0.796 | 0.866 | 0.886 | Seq Scan on merchants |
| R22 | READ | 4.842 | 5.333 | 5.189 | 5.121 | 5.189 | Seq Scan on vpas \| Index Scan using bank_account_owner_candidate_key on bank_accounts |
| R23 | READ | 68.384 | 59.050 | 58.504 | 61.979 | 59.050 | Seq Scan on transactions |
| R24 | READ | 0.053 | 0.036 | 0.033 | 0.041 | 0.036 | Index Scan using transactions_upi_ref_key on transactions |
| R25 | READ | 22.978 | 20.639 | 19.566 | 21.061 | 20.639 | Seq Scan on transactions \| Seq Scan on vpas \| Seq Scan on bank_accounts |
| W01 | WRITE | 0.476 | 0.419 | 0.377 | 0.424 | 0.419 | (no scan) |
| W02 | WRITE | 22.064 | 18.687 | 18.235 | 19.662 | 18.687 | Index Scan using transactions_pkey on transactions |
| W03 | WRITE | 1.854 | 1.555 | 1.793 | 1.734 | 1.793 | Seq Scan on rewards \| Index Scan using rewards_pkey on rewards |
| W04 | WRITE | 1.870 | 2.476 | 2.456 | 2.267 | 2.456 | Seq Scan on rewards |
| W05 | WRITE | 3.236 | 2.477 | 1.958 | 2.557 | 2.477 | Seq Scan on bill_payments |

## Five Slowest Queries

1. **R19** — 4152.663 ms. Scan nodes: Seq Scan on merchants | Seq Scan on transactions.
2. **R09** — 870.160 ms. Scan nodes: Seq Scan on transactions.
3. **R08** — 339.982 ms. Scan nodes: Seq Scan on transactions.
4. **R23** — 61.979 ms. Scan nodes: Seq Scan on transactions.
5. **R13** — 30.668 ms. Scan nodes: Seq Scan on merchants | Seq Scan on transactions.

## Observations

The slowest queries are priority candidates for investigation during CP3. Sequential scans appear in several execution plans, but they are not automatically inefficient; the underlying filters, joins, row estimates, and buffer usage must be examined.

R19, R09, and R08 show substantially higher execution times than the other baseline queries.

## Next Steps — CP3

Inspect the raw execution plans, identify expensive operations, consider appropriate indexes and SQL rewrites, and benchmark the optimized workload against these baseline measurements.

## Evidence

- `benchmarks/results/baseline/summary.csv`
- `benchmarks/results/baseline/R01.txt` through `W05.txt`

