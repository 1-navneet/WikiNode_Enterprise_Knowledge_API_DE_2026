# DE CP3 — Measured Optimization Report

## Methodology

Baseline and optimized workloads were executed three times per query using `EXPLAIN (ANALYZE, BUFFERS)`. Write operations were rolled back. The optimized workload includes candidate rewrites for R19/R20 and targeted indexes. Hardware, cache, and query plans may affect results.

| Query | Baseline avg (ms) | Optimized avg (ms) | Improvement (%) |
|---|---:|---:|---:|
| R01 | 25.844 | 33.821 | -30.87 |
| R02 | 0.054 | 0.041 | +24.07 |
| R03 | 16.077 | 0.043 | +99.73 |
| R04 | 8.092 | 0.062 | +99.23 |
| R05 | 7.545 | 0.080 | +98.94 |
| R06 | 7.675 | 0.730 | +90.49 |
| R07 | 8.029 | 2.613 | +67.46 |
| R08 | 339.982 | 359.888 | -5.86 |
| R09 | 870.160 | 104.248 | +88.02 |
| R10 | 1.917 | 0.037 | +98.07 |
| R11 | 2.651 | 0.030 | +98.87 |
| R12 | 1.671 | 0.019 | +98.86 |
| R13 | 30.668 | 4.292 | +86.00 |
| R14 | 21.190 | 0.140 | +99.34 |
| R15 | 9.252 | 2.967 | +67.93 |
| R16 | 0.355 | 0.144 | +59.44 |
| R17 | 13.920 | 13.985 | -0.47 |
| R18 | 25.280 | 43.832 | -73.39 |
| R19 | 4152.663 | 1.545 | +99.96 |
| R20 | 9.919 | 2.487 | +74.93 |
| R21 | 0.866 | 0.814 | +6.00 |
| R22 | 5.121 | 0.053 | +98.97 |
| R23 | 61.979 | 13.547 | +78.14 |
| R24 | 0.041 | 0.032 | +21.95 |
| R25 | 21.061 | 18.513 | +12.10 |
| W01 | 0.424 | 0.615 | -45.05 |
| W02 | 19.662 | 0.447 | +97.73 |
| W03 | 1.734 | 0.385 | +77.80 |
| W04 | 2.267 | 0.719 | +68.28 |
| W05 | 2.557 | 2.748 | -7.47 |

## Interpretation

Negative percentages mean regression, not improvement. Inspect `benchmarks/results/optimized/*.txt` for scan choice and actual plan changes. An index does not guarantee a faster query. R19 replaces repeated correlated subqueries with a single grouped join; R20 changes the date predicate to a timestamp range.
