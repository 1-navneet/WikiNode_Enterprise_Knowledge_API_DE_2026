#!/usr/bin/env bash
# One-command CP4 runner after all four team packages are merged.
# Usage: bash scripts/finish_cp4.sh gpay_large_cp4 SEED_DB_NAME
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
LARGE="${1:-gpay_large_cp4}"
SEED="${2:-}"
if [[ -z "$SEED" ]]; then
  echo 'Usage: bash scripts/finish_cp4.sh gpay_large_cp4 YOUR_OPTIMIZED_SEED_DB' >&2
  echo 'Second argument must be the database with your seed data and CP3 indexes.' >&2
  exit 2
fi
bash scripts/run_large_benchmark.sh "$LARGE"
bash scripts/measure_partition_pruning.sh "$LARGE"
mkdir -p benchmarks/results/optimized
psql -X -A -t -v ON_ERROR_STOP=1 -d "$SEED" -f scripts/measure_storage.sql \
  > benchmarks/results/optimized/storage.csv
python3 scripts/build_scalability_report.py
python3 scripts/check_cp4.py
printf '\nReview target misses, explain plan regressions, then commit measured evidence.\n'
