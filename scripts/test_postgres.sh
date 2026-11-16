#!/usr/bin/env bash
# End-to-end validation against the faculty CSVs and a temporary PostgreSQL database.
# Run from any directory: bash scripts/test_postgres.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
for tool in psql createdb dropdb python3 unzip; do
  command -v "$tool" >/dev/null || { echo "Missing $tool. Install PostgreSQL 15+, Python 3 and unzip." >&2; exit 2; }
done
if [[ ! -d seed_data ]]; then
  [[ -f seed_data.zip ]] || { echo 'Copy faculty seed_data.zip to repo root first.' >&2; exit 2; }
  unzip -nq seed_data.zip
fi
[[ -f seed_data/transactions.csv ]] || { echo 'Expected seed_data/transactions.csv after extraction.' >&2; exit 2; }
python3 scripts/validate_csvs.py
DB="gpay_cp1_test_$(date +%s)_${RANDOM}"
LOG="${ROOT}/validation"
mkdir -p "$LOG"
createdb "$DB"
trap 'dropdb --if-exists "$DB" >/dev/null 2>&1 || true' EXIT
psql -v ON_ERROR_STOP=1 -d "$DB" -f sql/01_schema.sql > "$LOG/schema.log"
psql -v ON_ERROR_STOP=1 -d "$DB" -f sql/02_load_data.sql > "$LOG/load.log"
psql -v ON_ERROR_STOP=1 -d "$DB" -f sql/03_integrity_checks.sql > "$LOG/integrity.log"
if [[ ! -f queries/workload_30.sql ]]; then
  echo 'Required faculty queries/workload_30.sql not found; copy these files into team DE repo.' >&2
  exit 2
fi
psql -v ON_ERROR_STOP=1 -d "$DB" -f queries/workload_30.sql > "$LOG/workload.log"
echo 'PASS: CSV validation, schema creation, nine CSV imports, integrity checks, and all 30 faculty queries.'
echo "Logs in ${LOG}/ ; temporary database removed after test."
