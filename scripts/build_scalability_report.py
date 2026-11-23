#!/usr/bin/env python3
"""Generate CP4 report from recorded 3-run plans and real CSV summaries only."""
import csv
from datetime import date
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT/'benchmarks/results'
OUT = ROOT/'docs/05_scalability_report.md'
IDS = [f'R{i:02}' for i in range(1, 26)] + [f'W{i:02}' for i in range(1, 6)]
FAST = set('R01 R02 R03 R04 R10 R12 R22 R24 W01 W02 W03'.split())
INTERACTIVE = set('R05 R11 R13 R14 R16 R21 R23'.split())
REPORTS = set('R06 R07 R08 R09 R15 R17 R18 R19 R20 R25'.split())
TIME = re.compile(r'Execution Time:\s*([\d.]+)\s*ms')


def read_csv(path):
    if not path.exists(): return []
    with path.open(newline='') as f: return list(csv.DictReader(f))


def rows_by_id(path):
    rows=read_csv(path)
    result={}
    for row in rows:
        key=row.get('query_id','')
        if key in result: raise ValueError(f'Duplicate query ID {key} in {path}')
        result[key]=row
    return result


def measured(value):
    try:
        n=float(value)
        return n if n >= 0 else None
    except (TypeError,ValueError): return None


def limit(q):
    return 5 if q in FAST else 250 if q in INTERACTIVE else 5000 if q in REPORTS else 1000


def verified_large(q, row):
    if row is None: return None
    val=measured(row.get('avg_ms'))
    if val is None: return None
    plan=BASE/'large'/f'{q}.txt'
    if not plan.exists(): return None
    times=[float(t) for t in TIME.findall(plan.read_text())]
    if len(times)!=3 or abs(sum(times)/3-val)>0.025: return None
    return val


def fmt(n): return 'NOT MEASURED' if n is None else f'{n:.3f}'


def storage(folder):
    rows=read_csv(BASE/folder/'storage.csv')
    if len(rows)!=9:return None
    try:return tuple(sum(int(row[col]) for row in rows) for col in ('heap_bytes','index_bytes','total_bytes'))
    except (KeyError,ValueError):return None


seed=rows_by_id(BASE/'optimized/summary.csv')
large=rows_by_id(BASE/'large/summary.csv')
lines=[
'# DE CP4 — Scalability Report (Google Pay UPI Database, T0109)', '',
'Generated: '+date.today().isoformat(), '',
'## 1. Dataset and methodology', '',
'- Faculty source: [GitHub release `large-data`](https://github.com/edusatyaki/DBMS-Google-Pay-Digital-Payments/releases/tag/large-data) (`large_data.zip`, 262,190,235 bytes, approximately 9.5 million rows).',
'- Original seed: 250,468 transactions; large dataset expected approximately 20×. Exact loaded counts are recorded below if available.',
'- Load into an isolated PostgreSQL database; install the **same CP3 indexes**; run `ANALYZE`.',
'- Measure **optimized workload only**, three times per query using `EXPLAIN (ANALYZE, BUFFERS)`. Write operations must be inside transactions rolled back after execution.',
'- Large timing values require a summary and three matching execution plans; otherwise they are left blank/unverified. Hardware and cache effects limit cross-run comparisons.',
'', '## 2. Row counts (actual imported faculty dataset)', '',
'| Table | Rows |', '|---|---:|'
]
counts=read_csv(BASE/'large/row_counts.csv')
if counts:
    for row in counts: lines.append(f"| {row.get('table_name','?')} | {row.get('rows','?')} |")
    try: lines.append(f"| **TOTAL** | **{sum(int(row['rows']) for row in counts):,}** |")
    except (KeyError,ValueError): pass
else: lines.append('| NOT MEASURED | NOT MEASURED |')
lines.extend(['', '## 3. Actual results for all 30 optimized queries', '',
 '| Query | Seed optimized (ms) | Large optimized (ms) | Growth (×) | Faculty target (ms) | Met? | If not, explanation/action |',
 '|---|---:|---:|---:|---:|:---:|---|'])
known={}
for q in IDS:
    s=measured(seed.get(q,{}).get('avg_ms'))
    b=verified_large(q,large.get(q))
    known[q]=(s,b)
    ratio=b/s if s and b is not None else None
    met='NOT MEASURED' if b is None else ('YES' if b<limit(q) else 'NO')
    action='Pending real measurement' if b is None else ('—' if b<limit(q) else 'Inspect plan, measure revision and document before/after')
    lines.append(f"| {q} | {fmt(s)} | {fmt(b)} | {fmt(ratio)} | {limit(q)} | {met} | {action} |")

lines += ['', '## 4. Growth classification', '']
if all(known[q][1] is not None for q in IDS):
    bins={'Stayed approximately the same (≤2×)': [], 'Increased between 2× and 20×': [], 'Increased more than 20×': []}
    for q, (s,b) in known.items():
        if not s: continue
        ratio=b/s
        k='Stayed approximately the same (≤2×)' if ratio<=2 else ('Increased between 2× and 20×' if ratio<=20 else 'Increased more than 20×')
        bins[k].append(q)
    for label, group in bins.items(): lines.append('- **'+label+':** '+(', '.join(group) or 'none'))
    lines += ['', 'Why: highly selective indexed lookups may stay close to constant, but wide scans, sorting, aggregation and high-offset pagination can grow sharply. Verify reasons using `benchmarks/results/large/*.txt`, not timing ratios alone.']
else:
    lines.append('**NOT MEASURED** — cannot classify growth without all 90 real plans and the large summary. Do not extrapolate runtimes from row count.')

fails=[(q,b,limit(q),large.get(q,{}).get('scan_nodes','')) for q,(s,b) in known.items() if b is not None and b>=limit(q)]
lines+=['', '## 5. Queries that missed the faculty targets', '']
if fails:
    lines+=['| Query | Measured ms | Target ms | Observed scan nodes | Status |','|---|---:|---:|---|---|']
    for q,b,target,nodes in fails:
        lines.append(f'| {q} | {b:.3f} | <{target} | {nodes or "See plan"} | Needs investigation/retest |')
    lines += ['', 'The table identifies actual misses; it **does not** claim they have been fixed. Save before-and-after plans and new 3-run means for each optimization. If a query cannot meet the target, document the technical reason and remaining limitations.']
elif all(known[q][1] is not None for q in IDS):
    lines.append('All 30 measured averages are below their respective faculty targets on this environment. Verify plan evidence and repeatability before submission.')
else: lines.append('**NOT MEASURED** — identify missed targets after the full benchmark.')
lines+=['', '## 6. Storage footprint', '',
 '| Dataset | Heap (MiB) | Indexes (MiB) | Total relations (MiB) |', '|---|---:|---:|---:|']
for label,key in [('Seed with CP3 indexes','optimized'),('Faculty 20× large','large')]:
    vals=storage(key)
    cols=[f'{v/1048576:.2f}' for v in vals] if vals else ['NOT MEASURED']*3
    lines.append('| '+' | '.join([label,*cols])+' |')
lines += ['', 'Storage values use `pg_relation_size`, `pg_indexes_size`, and `pg_total_relation_size`; total can include TOAST storage. Measure seed and large on comparable PostgreSQL installations.',
'', '## 7. Partitioning, sharding, replicas, and caching at 100×', '',
'**Partitioning:** see `sql/08_partitioning.sql` and `docs/partitioning_design.md`; monthly `RANGE(initiated_at)` supports time-pruning for R03/R05/R06/R15/R20. Run `bash scripts/measure_partition_pruning.sh gpay_large_cp4` and attach the resulting plan. This is a prototype: PostgreSQL partitioned unique keys must contain the partition key, so the existing `txn_id`-only PK and rewards/disputes references require an explicit migration design.',
'', '**Sharding:** payer-keyed sharding localizes payer history but makes payee history and cross-payer merchant settlements distributed; time sharding aids archive analytics but not individual user history. Resolve cross-shard consistency with globally unique IDs, idempotency and reconciliation. No sharding has been implemented.',
'', '**Replicas:** eventual-consistency analytics (R06/R08/R15/R17/R19/R20/R25) may run on replicas; immediate checks (R02/R03/R04/R10/R12/R22/R24) and W01–W05 need primary-consistent behavior.',
'', '**Caching:** cache immutable merchant metadata/aggregate reports with expiration and invalidation, not live payment decisions. Review data sensitivity and privacy.',
'', '**Maintenance:** tune autovacuum based on observed dead tuples and write volume; `ANALYZE` after bulk loads; archive old partitions within retention rules; keep backups, WAL archiving and disaster recovery tests.',
'', '## 8. Conclusion and open risks', '']
if all(known[q][1] is not None for q in IDS):
    lines.append(f'Executed and plan-verified all 30 optimized queries on the faculty dataset. {len(fails)} queries failed their target on this hardware. This benchmark alone does not certify 100× production readiness; remaining risks include index-maintenance cost, deep OFFSET, cross-shard transactions and replica lag.')
else:
    lines.append('Large-dataset benchmarking remains **NOT MEASURED** in this report. CP3 seed results alone cannot establish scalability readiness. Run actual tests on PostgreSQL and regenerate this report before submission.')
lines += ['', '## 9. Evidence inventory', '',
'- `benchmarks/results/large/summary.csv` and `R01.txt`…`W05.txt`: optimized 3-run large dataset timings and plans',
'- `benchmarks/results/large/row_counts.csv` and `storage.csv`: actual loaded rows and storage',
'- `benchmarks/results/optimized/storage.csv`: seed storage with same index set',
'- `benchmarks/results/large/partition_pruning_plan.txt`: partition prototype EXPLAIN evidence',
'- `benchmarks/results/large/integrity_check.txt`: schema and data checks', '']
OUT.parent.mkdir(parents=True,exist_ok=True)
OUT.write_text('\n'.join(lines))
print(f'Wrote {OUT}: verified {sum(known[q][1] is not None for q in IDS)}/30 large query summaries')
