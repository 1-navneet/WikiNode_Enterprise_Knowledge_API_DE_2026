-- CP4: Only invariant integrity checks; no seed-specific expected row counts.
-- These four checks match the semantic part of sql/03_integrity_checks.sql.
\set ON_ERROR_STOP on
SET search_path TO gpay;
DO $$
DECLARE bad BIGINT;
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
-- Large dataset is roughly 20x, not the exact seed sizes.
DO $$
DECLARE txns BIGINT; total BIGINT;
BEGIN
 SELECT count(*) INTO txns FROM transactions;
 SELECT (SELECT count(*) FROM cities) + (SELECT count(*) FROM users) +
        (SELECT count(*) FROM bank_accounts) + (SELECT count(*) FROM vpas) +
        (SELECT count(*) FROM merchants) + (SELECT count(*) FROM transactions) +
        (SELECT count(*) FROM rewards) + (SELECT count(*) FROM bill_payments) +
        (SELECT count(*) FROM disputes) INTO total;
 IF txns < 1000000 OR total < 6000000 THEN
   RAISE EXCEPTION 'Data appears too small for the faculty 20x dataset: % transactions, % total rows',txns,total;
 END IF;
 RAISE NOTICE 'Large dataset loaded: % transactions, % total rows',txns,total;
END $$;

SELECT 'PASS: large dataset semantic integrity and plausible row counts' AS result;
