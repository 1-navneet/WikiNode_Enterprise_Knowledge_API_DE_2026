# CP4: Official faculty 20× dataset — reproducible measurements

**Official archive:** https://github.com/edusatyaki/DBMS-Google-Pay-Digital-Payments/releases/download/large-data/large_data.zip

**Source:** Satyaki Das's release `large-data`, published 2026-11-21, size **262,190,235 bytes**, SHA-256 `dac0bf4f312de3796d2fe904846c84cac51fa974b2e7dc5871365c91c4659423`. The archive contains the same nine tables/columns as the seed dataset and approximately 9.5 million rows in total. **The archive and extracted CSVs must not be committed.**

## Requirements

PostgreSQL 15+ installed and started; `psql`, `createdb`, `python3` on your PATH. Ensure several GiB of disk space for extracted CSVs, PostgreSQL tables and indexes. On macOS, add Homebrew's PostgreSQL `bin` directory to your PATH if needed. PostgreSQL's user must have permission to create a database.

## One command, from repository root

```bash
bash scripts/run_large_benchmark.sh gpay_large_cp4
```

The script downloads the release if `large_data.zip` is not already present, verifies size and official SHA-256, safely extracts only the nine expected CSVs to `large_data/`, creates a **new** database, loads the exact CSVs, runs large-specific integrity checks, installs the project's CP3 indexes, runs `ANALYZE`, measures storage/row counts, and performs **three measured `EXPLAIN (ANALYZE, BUFFERS)` executions for each of 30 optimized queries**. Write queries are rolled back. It does **not** run the unoptimized faculty workload on large data. It will refuse to overwrite an existing database.

Outputs: `benchmarks/results/large/{summary.csv,storage.csv,row_counts.csv,integrity_check.txt,R01.txt...W05.txt}`. Missing measurements are never manufactured. Benchmarks can be resumed after interruption on an already-populated database using:

```bash
python3 scripts/benchmark_optimized.py --db gpay_large_cp4 --resume
```

To compare seed storage, use the same PostgreSQL installation and your previously measured **optimized seed database** (replace `SEED_DB_NAME`):

```bash
mkdir -p benchmarks/results/optimized
psql -X -A -t -v ON_ERROR_STOP=1 -d SEED_DB_NAME -f scripts/measure_storage.sql > benchmarks/results/optimized/storage.csv
python3 scripts/build_scalability_report.py
python3 scripts/check_cp4.py
```

**Important correction:** `sql/03_integrity_checks.sql` includes *seed-only* exact row counts and must not be run on the large dataset. This package uses `scripts/verify_large_integrity.sql` for the reusable semantic checks.

`benchmark_optimized.py` is portable to macOS (does not need `sort -V`) and records actual plans. If a faculty target fails, inspect the exact `Rxx.txt` plan before editing an index or query, then measure again and preserve before/after plans for the report. The code package itself is not benchmark evidence.
