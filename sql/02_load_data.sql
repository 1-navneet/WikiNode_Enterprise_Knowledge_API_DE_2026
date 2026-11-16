-- Run from repository root: psql -v ON_ERROR_STOP=1 -d YOUR_DB -f sql/02_load_data.sql
-- Unzip seed_data.zip locally into seed_data/ before running.
\set ON_ERROR_STOP on
SET search_path TO gpay;
\copy cities FROM 'seed_data/cities.csv' WITH (FORMAT csv, HEADER true)
\copy users FROM 'seed_data/users.csv' WITH (FORMAT csv, HEADER true)
\copy bank_accounts FROM 'seed_data/bank_accounts.csv' WITH (FORMAT csv, HEADER true)
\copy vpas FROM 'seed_data/vpas.csv' WITH (FORMAT csv, HEADER true)
\copy merchants FROM 'seed_data/merchants.csv' WITH (FORMAT csv, HEADER true)
\copy transactions FROM 'seed_data/transactions.csv' WITH (FORMAT csv, HEADER true)
\copy rewards FROM 'seed_data/rewards.csv' WITH (FORMAT csv, HEADER true)
\copy bill_payments FROM 'seed_data/bill_payments.csv' WITH (FORMAT csv, HEADER true)
\copy disputes FROM 'seed_data/disputes.csv' WITH (FORMAT csv, HEADER true)
ANALYZE;
SELECT 'cities' AS table_name, count(*) AS actual_rows, 10 AS expected_rows FROM cities
UNION ALL SELECT 'users',count(*),40000 FROM users
UNION ALL SELECT 'bank_accounts',count(*),53333 FROM bank_accounts
UNION ALL SELECT 'vpas',count(*),53333 FROM vpas
UNION ALL SELECT 'merchants',count(*),3000 FROM merchants
UNION ALL SELECT 'transactions',count(*),250468 FROM transactions
UNION ALL SELECT 'rewards',count(*),39799 FROM rewards
UNION ALL SELECT 'bill_payments',count(*),30000 FROM bill_payments
UNION ALL SELECT 'disputes',count(*),3569 FROM disputes;
