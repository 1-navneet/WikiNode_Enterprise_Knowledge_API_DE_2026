# T0109 — DE CP4 final submission guide (actual faculty large dataset)

**Canonical GitHub repository:** https://github.com/1-navneet/WikiNode_Enterprise_Knowledge_API_DE_2026 (the older Shivang-owner URL redirects here).
**Faculty source:** https://github.com/edusatyaki/DBMS-Google-Pay-Digital-Payments/releases/download/large-data/large_data.zip
**Archive:** 262,190,235 bytes (official SHA-256 `dac0bf4f312de3796d2fe904846c84cac51fa974b2e7dc5871365c91c4659423`), released 21 Nov 2026, about 9.5 million records across 9 CSVs.
**Deadline from faculty CHECKPOINTS.md:** Monday 23 Nov 2026, 11:59 PM local.

## Division of work (commit after reviewing your own files)

| Member | Code and deliverables |
|---|---|
| Shivang | `sql/08_partitioning.sql`, `docs/partitioning_design.md`, `scripts/measure_partition_pruning.sh` |
| Jatasay | large release download/unzip and database load, optimized three-run benchmark, large-only integrity SQL, storage SQL, `.gitignore`, instructions |
| Paras | evidence-based `docs/05_scalability_report.md`, report generator, analysis notes |
| Navneet | this guide, `scripts/check_cp4.py`, `scripts/finish_cp4.sh` |

## Steps after merging four contribution packages

1. Install/start PostgreSQL 15+ and ensure `createdb` / `psql` / Python3 work. Ensure **several GiB** free disk.
2. Obtain the faculty archive automatically when running the pipeline, or manually put `large_data.zip` in the repository root. The script extracts only expected CSV files into ignored `large_data/`.
3. Identify your existing **optimized seed database** name (with CP3 indexes installed), then run:

   ```bash
   bash scripts/finish_cp4.sh gpay_large_cp4 YOUR_OPTIMIZED_SEED_DB
   ```

   This creates a **new database** and refuses to overwrite an existing one. If interrupted after data load, resume optimized queries with `python3 scripts/benchmark_optimized.py --db gpay_large_cp4 --resume`, then run partition demonstration, storage measurement and report scripts separately.
4. Verify `benchmarks/results/large/summary.csv` has 30 queries and the plan files show three real `Execution Time` values each. Do not edit measurements manually.
5. Compare performance to faculty's 5/250/5000/1000 ms targets. For each miss, inspect plans, tune responsibly, rerun **three times** and document before/after evidence. The helper code does not pretend tuning is finished.
6. Inspect `docs/05_scalability_report.md`; complete the qualitative 100× scale discussion using actual measurements and note any remaining risks.
7. Run `python3 scripts/check_cp4.py` again. Commit **measured evidence** (`benchmarks/results/large/`), edited report, and seed storage CSV. Never commit `large_data/` or `large_data.zip`.
8. Check `git status`, actual authors and that GitHub's default branch contains required artifacts. Individual analysis (CP5) follows separately in class.

## Expected evidence

`docs/05_scalability_report.md`, `sql/08_partitioning.sql`, `benchmarks/results/large/summary.csv`, `R01.txt`…`R25.txt`, `W01.txt`…`W05.txt`, `row_counts.csv`, `storage.csv`, `integrity_check.txt`, `partition_pruning_plan.txt`, and `benchmarks/results/optimized/storage.csv`.

## Honest status

The source ZIP is publicly available; benchmarks are only complete **after** PostgreSQL executes them against the faculty dataset. Do not mark targets passed based on small seed timings or estimates. Git author/committer identities should correspond to whoever actually reviews and commits the contribution.
