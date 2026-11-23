# CP4: Transaction partitioning and architecture for 100× scale

## Scope and status

`sql/08_partitioning.sql` builds a **separate, non-destructive prototype**, not a production migration. It has not been benchmarked against the faculty large dataset. The design preserves the main transaction columns and key CHECK rules but does not reproduce every original foreign key. Do not replace `gpay.transactions` with it as-is.

## Why monthly RANGE(initiated_at)?

Typical reporting workloads R03/R05/R06/R15/R20 and expiry-oriented operations restrict time ranges. A monthly partition can allow PostgreSQL to **prune** other months. This reduces scanned partitions only when the query has an eligible time predicate. R01/R09/R17/R18 and global totals may still scan many partitions. A time-partitioned table is not equivalent to a global index.

## PostgreSQL primary key/unique caveat

PostgreSQL requires partitioned UNIQUE and PRIMARY KEY constraints to include `initiated_at`. Therefore `PRIMARY KEY(txn_id)` and `UNIQUE(upi_ref)` on the existing table cannot be carried over unchanged. The prototype uses `(txn_id, initiated_at)` and `(upi_ref, initiated_at)`; these **do not enforce** global uniqueness of `txn_id` or `upi_ref` across different timestamps. Existing `rewards(txn_id)` and `disputes(txn_id)` foreign keys cannot target the composite key without adding the timestamp columns and changing references. Real migration options include retaining a global unpartitioned ID registry (with carefully designed synchronization), redesigning referencing tables with composite FKs, or using partitioning by an immutable business key instead. Each has costs.

## Proving pruning

Run the SQL file, then insert suitable test/seed rows only into the `gpay_scale` prototype and `ANALYZE`. Use `EXPLAIN (ANALYZE, BUFFERS)` with a half-open June 2026 range; identify scanned partitions versus a query without the date predicate. Do not claim speedups without capturing the plans and three-run timings.

## Sharding at 100×

Sharding by payer makes payer history locality easier, but P2P transfers cross shards because payees may reside elsewhere; reconciliation, global UPI reference lookup, settlement, and fraud analytics may need distributed joins or an event/aggregation pipeline. Sharding by payee or merchant favors settlement and merchant analytics, but payer history crosses shards. Time sharding favors archives and time-window reporting but does not locate a user's entire history efficiently. Introduce a stable routing key and globally unique payment IDs before sharding. Cross-shard writes require a saga/idempotency and reconciliation strategy; do not pretend a distributed transaction is free.

## Replicas, cache, and maintenance

Only eventually-consistent dashboards/reports (e.g. R06, R08, R15, R17, R19, R20, R25) are good candidates for read replicas; payment-path checks (R02, R03, R04, R10, R12, R22, R24) should read the primary if immediate consistency is required. Short-lived caches may help merchant lookup R21 or aggregate dashboard data, with invalidation on changes. Writes W01–W05 must hit the primary. Monitor autovacuum lag and dead tuples for transactions, use regular `ANALYZE`, retain WAL/backups and point-in-time recovery, archive old partitions after business retention approval, and refresh materialized summaries on a defined schedule.

## Performance risks

High insert rates increase index maintenance cost; many indexes improve reads at the expense of W01/W02. Query R23 still uses deep `OFFSET` and may scan large index ranges. Convert to keyset pagination in an API with a stable cursor `(initiated_at, txn_id)` and a matching index; it is not a drop-in replacement for the faculty's fixed page 8001 without determining the page boundary.

## CP4 executable proof on official large dataset

After Jatasay's large-data load, run:

```bash
bash scripts/measure_partition_pruning.sh gpay_large_cp4
```

This creates the separate prototype `gpay_scale` if missing, inserts at most 10,000 **real** June transactions inside a transaction, analyzes the sample, captures filtered and unfiltered `EXPLAIN (ANALYZE, BUFFERS)` plans, and rolls back the sample. Plan evidence is written to `benchmarks/results/large/partition_pruning_plan.txt`. It does not mutate `gpay.transactions`. **This is a pruning illustration, not a full 100× partition benchmark.**
