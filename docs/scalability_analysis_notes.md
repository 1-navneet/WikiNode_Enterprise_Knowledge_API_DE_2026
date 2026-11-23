# CP4 analysis checklist

- Compare each optimized seed 3-run average with actual faculty large 3-run average.
- The `<` target rule is strict: 5.000 ms **fails** an under-5-ms target.
- Preserve raw EXPLAIN plans for every result. A CSV without plans cannot substantiate the measurement.
- Review R01 (seed already 33.821 ms, exceeding the real-time large target of <5 ms), R08 (359.888 ms and broad grouping), R09 (104.248 ms), R18 (43.832 ms), and R23 (13.547 ms for deep OFFSET) for scaling risk. These are **seed timings**, not large timings.
- For R13, the optimized NOT EXISTS fixes NULL semantics in the original NOT IN; verify correctness against known merchants.
- For R19, LATERAL aggregation dramatically improves seed timing; test if it remains performant at increased merchant count.
- Treat the original queries as frozen faculty workload; do not edit `queries/workload_30.sql`. Store alternative revisions separately and explain whether their results are semantically equivalent.

## New official faculty 20× data (released 21 November 2026)

The `large-data` GitHub release has been verified: `large_data.zip`, 262,190,235 bytes. Use Jatasay's large benchmark pipeline to produce actual plans, then regenerate the report from 3-run measured evidence. The report builder refuses to label an unsupported CSV-only number as measured: each large summary average must agree with the three `Execution Time:` values in `Rxx.txt` or `Wxx.txt`. Check outliers/target misses manually. Do not report extrapolated figures as measurements.
