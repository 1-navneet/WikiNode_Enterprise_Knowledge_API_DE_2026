-- Google Pay Digital Payments Database
-- DE CP3
-- Contributor: Paras Dhankhar
-- Optimized query contributions
--
-- Integrate these five marked queries into sql/06_optimized_queries.sql,
-- replacing their matching IDs while preserving all other workload queries.

SET search_path TO gpay;

-- @R03
-- Daily UPI limit calculation for 30 June 2026.
-- The timezone-less timestamp literals use the session TimeZone, matching
-- DATE(timestamptz)'s calendar-day interpretation in the original query.
SELECT coalesce(sum(t.amount), 0) AS sent_today
FROM transactions AS t
JOIN vpas AS v
    ON v.vpa = t.payer_vpa
WHERE v.user_id = 15177
  AND t.status IN ('SUCCESS', 'PENDING')
  AND t.initiated_at >= TIMESTAMPTZ '2026-06-30 00:00:00'
  AND t.initiated_at < TIMESTAMPTZ '2026-07-01 00:00:00';

-- @R13
-- Merchants without recorded payments.
-- Unlike the original NOT IN, this correctly returns merchants even when
-- transactions contains NULL merchant_id values from P2P payments.
SELECT
    m.merchant_id,
    m.merchant_name,
    m.onboarded_on
FROM merchants AS m
WHERE NOT EXISTS (
    SELECT 1
    FROM transactions AS t
    WHERE t.merchant_id = m.merchant_id
);

-- @R14
-- User 15177 spending by merchant category from 2025 onward.
-- This lower bound preserves EXTRACT(YEAR FROM initiated_at) >= 2025;
-- intentionally do not cap the range at the end of 2025 or 2026.
SELECT
    m.mcc,
    count(*) AS payments,
    sum(t.amount) AS spent
FROM transactions AS t
JOIN merchants AS m
    ON m.merchant_id = t.merchant_id
JOIN vpas AS v
    ON v.vpa = t.payer_vpa
WHERE v.user_id = 15177
  AND t.status = 'SUCCESS'
  AND t.initiated_at >= TIMESTAMPTZ '2025-01-01 00:00:00'
GROUP BY m.mcc
ORDER BY spent DESC;

-- @R19
-- Last payment time and successful payment count for verified Bengaluru merchants.
-- Compute both aggregates in one indexed per-merchant pass; retain merchants
-- with no matching payments through the LEFT JOIN.
SELECT
    m.merchant_id,
    m.merchant_name,
    txn_stats.last_payment_at,
    coalesce(txn_stats.successful_payments, 0) AS successful_payments
FROM merchants AS m
LEFT JOIN LATERAL (
    SELECT
        t.merchant_id,
        max(t.initiated_at) AS last_payment_at,
        count(*) FILTER (WHERE t.status = 'SUCCESS') AS successful_payments
    FROM transactions AS t
    WHERE t.merchant_id = m.merchant_id
    GROUP BY t.merchant_id
) AS txn_stats ON TRUE
WHERE m.is_verified
  AND m.city_id = 1
ORDER BY successful_payments DESC;

-- @R20
-- Daily success rate in June 2026.
-- The half-open range uses the same session-local midnight boundaries as
-- initiated_at::date, while retaining the original grouping and calculation.
SELECT
    initiated_at::date AS day,
    count(*) AS payments,
    round(100.0 * count(*) FILTER (WHERE status = 'SUCCESS') / count(*), 2) AS success_pct
FROM transactions
WHERE initiated_at >= TIMESTAMPTZ '2026-06-01 00:00:00'
  AND initiated_at < TIMESTAMPTZ '2026-07-01 00:00:00'
GROUP BY 1
ORDER BY 1;
