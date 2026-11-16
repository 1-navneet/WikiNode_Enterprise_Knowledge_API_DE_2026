-- Actual-result integrity checks. Run after 02_load_data.sql.
SET search_path TO gpay;
DO $$
DECLARE bad bigint;
BEGIN
  SELECT count(*) INTO bad FROM transactions t
    JOIN merchants m ON m.merchant_id=t.merchant_id
    WHERE t.txn_type='P2M' AND t.payee_vpa<>m.merchant_vpa;
  IF bad<>0 THEN RAISE EXCEPTION 'P2M merchant VPA mismatches: %',bad; END IF;

  SELECT count(*) INTO bad FROM vpas v
    JOIN bank_accounts b ON b.account_id=v.account_id
    WHERE v.user_id<>b.user_id;
  IF bad<>0 THEN RAISE EXCEPTION 'VPA/bank-owner mismatches: %',bad; END IF;

  SELECT count(*) INTO bad FROM (
    SELECT u.user_id FROM users u LEFT JOIN bank_accounts b ON b.user_id=u.user_id
    GROUP BY u.user_id HAVING count(*) FILTER(WHERE b.is_primary) <> 1
  ) q;
  IF bad<>0 THEN RAISE EXCEPTION 'Users without exactly one primary account: %',bad; END IF;

  SELECT count(*) INTO bad FROM rewards r JOIN transactions t ON t.txn_id=r.txn_id
    JOIN vpas v ON v.vpa=t.payer_vpa WHERE r.user_id<>v.user_id;
  IF bad<>0 THEN RAISE EXCEPTION 'Reward owner mismatches: %',bad; END IF;
END $$;

-- Complete nine-table row-count checks from faculty README.
DO $$
DECLARE bad bigint;
BEGIN
  SELECT count(*) INTO bad FROM (
   SELECT 'cities' AS name,(SELECT count(*) FROM cities) AS actual,10 AS expected
   UNION ALL SELECT 'users',(SELECT count(*) FROM users),40000
   UNION ALL SELECT 'bank_accounts',(SELECT count(*) FROM bank_accounts),53333
   UNION ALL SELECT 'vpas',(SELECT count(*) FROM vpas),53333
   UNION ALL SELECT 'merchants',(SELECT count(*) FROM merchants),3000
   UNION ALL SELECT 'transactions',(SELECT count(*) FROM transactions),250468
   UNION ALL SELECT 'rewards',(SELECT count(*) FROM rewards),39799
   UNION ALL SELECT 'bill_payments',(SELECT count(*) FROM bill_payments),30000
   UNION ALL SELECT 'disputes',(SELECT count(*) FROM disputes),3569
  ) counts WHERE actual<>expected;
  IF bad<>0 THEN RAISE EXCEPTION 'Incorrect row counts in % tables',bad; END IF;
END $$;
SELECT 'PASS: row counts and four data-integrity checks' AS result;
