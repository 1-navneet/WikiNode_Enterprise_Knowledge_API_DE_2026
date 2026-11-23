#!/usr/bin/env bash
# CP4: isolated database, original faculty large dataset, 30 optimized queries x 3.
# No data or timings are invented. Existing databases are never overwritten.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
DB="${1:-gpay_large_cp4}"
[[ "$DB" =~ ^[A-Za-z_][A-Za-z_0-9]*$ ]] || { echo 'Unsafe database name' >&2; exit 2; }
for tool in python3 psql createdb; do
  command -v "$tool" >/dev/null || { echo "Missing $tool; install PostgreSQL 15+ and Python3" >&2; exit 2; }
done
# Auto-download / extract the exact 262190235-byte official faculty release.
python3 scripts/prepare_large_data.py
if psql -X -A -t -d postgres -v ON_ERROR_STOP=1 -c "SELECT 1 FROM pg_database WHERE datname='$DB'" | grep -qx 1; then
  echo "Database $DB already exists; choose a fresh name. Existing data is untouched." >&2
  exit 2
fi
createdb "$DB"
echo "Created dedicated database: $DB (retained for inspection)."
psql -X -v ON_ERROR_STOP=1 -d "$DB" -f sql/01_schema.sql
for table in cities users bank_accounts vpas merchants transactions rewards bill_payments disputes; do
  echo "Loading $table"
  psql -X -v ON_ERROR_STOP=1 -d "$DB" -c "\\copy gpay.$table FROM 'large_data/$table.csv' WITH (FORMAT csv, HEADER true)"
done
mkdir -p benchmarks/results/large
psql -X -v ON_ERROR_STOP=1 -d "$DB" -f scripts/verify_large_integrity.sql \
  > benchmarks/results/large/integrity_check.txt
psql -X -v ON_ERROR_STOP=1 -d "$DB" -f sql/05_indexes.sql
psql -X -v ON_ERROR_STOP=1 -d "$DB" -c 'ANALYZE;'
psql -X -A -t -v ON_ERROR_STOP=1 -d "$DB" -f scripts/measure_storage.sql \
  > benchmarks/results/large/storage.csv
psql -X -A -t -v ON_ERROR_STOP=1 -d "$DB" -c "COPY (
  SELECT 'cities' AS table_name, count(*) AS rows FROM gpay.cities
  UNION ALL SELECT 'users',count(*) FROM gpay.users
  UNION ALL SELECT 'bank_accounts',count(*) FROM gpay.bank_accounts
  UNION ALL SELECT 'vpas',count(*) FROM gpay.vpas
  UNION ALL SELECT 'merchants',count(*) FROM gpay.merchants
  UNION ALL SELECT 'transactions',count(*) FROM gpay.transactions
  UNION ALL SELECT 'rewards',count(*) FROM gpay.rewards
  UNION ALL SELECT 'bill_payments',count(*) FROM gpay.bill_payments
  UNION ALL SELECT 'disputes',count(*) FROM gpay.disputes
) TO STDOUT WITH CSV HEADER" > benchmarks/results/large/row_counts.csv
python3 scripts/benchmark_optimized.py --db "$DB" --runs 3 --resume
printf '\nLarge-data measured artifacts saved under benchmarks/results/large/\n'
printf 'Next: measure seed storage, build report, investigate missed targets, validate.\n'
