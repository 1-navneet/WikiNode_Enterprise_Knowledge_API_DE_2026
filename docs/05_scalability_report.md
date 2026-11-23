# DE CP4 — Scalability Report (pending faculty large-data measurements)

**Faculty update (21 Nov 2026):** Official `large_data.zip` is now available at https://github.com/edusatyaki/DBMS-Google-Pay-Digital-Payments/releases/download/large-data/large_data.zip (262,190,235 bytes, ~9.5 million rows). The provided script downloads, verifies, extracts and benchmarks it on your PostgreSQL machine.

**Status:** incomplete until real `large_data/` measurements are collected; do not submit this document as proof of large-dataset performance.

## Optimized seed timings vs large data

| Query | Optimized seed avg (ms) | Large avg (ms) | Growth | Faculty target (ms) | Meets target? |
|---|---:|---:|---:|---:|:---:|
| R01 | 33.821 | NOT MEASURED | NOT MEASURED | <5 | NOT MEASURED |
| R02 | 0.041 | NOT MEASURED | NOT MEASURED | <5 | NOT MEASURED |
| R03 | 0.043 | NOT MEASURED | NOT MEASURED | <5 | NOT MEASURED |
| R04 | 0.062 | NOT MEASURED | NOT MEASURED | <5 | NOT MEASURED |
| R05 | 0.080 | NOT MEASURED | NOT MEASURED | <250 | NOT MEASURED |
| R06 | 0.730 | NOT MEASURED | NOT MEASURED | <5000 | NOT MEASURED |
| R07 | 2.613 | NOT MEASURED | NOT MEASURED | <5000 | NOT MEASURED |
| R08 | 359.888 | NOT MEASURED | NOT MEASURED | <5000 | NOT MEASURED |
| R09 | 104.248 | NOT MEASURED | NOT MEASURED | <5000 | NOT MEASURED |
| R10 | 0.037 | NOT MEASURED | NOT MEASURED | <5 | NOT MEASURED |
| R11 | 0.030 | NOT MEASURED | NOT MEASURED | <250 | NOT MEASURED |
| R12 | 0.019 | NOT MEASURED | NOT MEASURED | <5 | NOT MEASURED |
| R13 | 4.292 | NOT MEASURED | NOT MEASURED | <250 | NOT MEASURED |
| R14 | 0.140 | NOT MEASURED | NOT MEASURED | <250 | NOT MEASURED |
| R15 | 2.967 | NOT MEASURED | NOT MEASURED | <5000 | NOT MEASURED |
| R16 | 0.144 | NOT MEASURED | NOT MEASURED | <250 | NOT MEASURED |
| R17 | 13.985 | NOT MEASURED | NOT MEASURED | <5000 | NOT MEASURED |
| R18 | 43.832 | NOT MEASURED | NOT MEASURED | <5000 | NOT MEASURED |
| R19 | 1.545 | NOT MEASURED | NOT MEASURED | <5000 | NOT MEASURED |
| R20 | 2.487 | NOT MEASURED | NOT MEASURED | <5000 | NOT MEASURED |
| R21 | 0.814 | NOT MEASURED | NOT MEASURED | <250 | NOT MEASURED |
| R22 | 0.053 | NOT MEASURED | NOT MEASURED | <5 | NOT MEASURED |
| R23 | 13.547 | NOT MEASURED | NOT MEASURED | <250 | NOT MEASURED |
| R24 | 0.032 | NOT MEASURED | NOT MEASURED | <5 | NOT MEASURED |
| R25 | 18.513 | NOT MEASURED | NOT MEASURED | <5000 | NOT MEASURED |
| W01 | 0.615 | NOT MEASURED | NOT MEASURED | <5 | NOT MEASURED |
| W02 | 0.447 | NOT MEASURED | NOT MEASURED | <5 | NOT MEASURED |
| W03 | 0.385 | NOT MEASURED | NOT MEASURED | <5 | NOT MEASURED |
| W04 | 0.719 | NOT MEASURED | NOT MEASURED | <1000 | NOT MEASURED |
| W05 | 2.748 | NOT MEASURED | NOT MEASURED | <1000 | NOT MEASURED |

## Growth and regressions

**Not measured yet.** Only classify performance growth and target compliance after the 3-run, large-dataset benchmark. R01 was 33.821 ms already on the optimized seed data; the faculty target for R01 on large data is under 5 ms. This flags a potential optimization problem, but says nothing about the unknown large result. R08 (359.888 ms), R09 (104.248 ms), and R18 (43.832 ms) deserve particular review.

## Measured storage

| Dataset | Heap MiB | Index MiB | Total MiB |
|---|---:|---:|---:|
| Seed | NOT MEASURED | NOT MEASURED | NOT MEASURED |
| Large | NOT MEASURED | NOT MEASURED | NOT MEASURED |

Use `scripts/measure_storage.sql` on both databases.

## Architecture at 100×

See `docs/partitioning_design.md` and `sql/08_partitioning.sql` for monthly range partitioning, primary key/foreign-key constraints, sharding, replicas, caching, and maintenance.

## Conclusion

The existing CP3 optimized results establish seed-data performance only. **Readiness at ~20× or 100× scale remains unverified until faculty large-data benchmarks, plans, and storage measurements exist.**
