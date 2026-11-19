#!/usr/bin/env python3
"""Generate honest before/after CP3 report from actual measured CSVs."""
import csv,pathlib
root=pathlib.Path(__file__).resolve().parents[1]
def read(path):
 with path.open(newline='') as f:return {r['query_id']:r for r in csv.DictReader(f)}
a=read(root/'benchmarks/results/baseline/summary.csv')
b=read(root/'benchmarks/results/optimized/summary.csv')
if set(a)!=set(b) or len(a)!=30:raise SystemExit('Baseline/optimized results must contain the same 30 query IDs')
rows=[]
for k in sorted(a):
 before=float(a[k]['avg_ms']);after=float(b[k]['avg_ms']);change=(before-after)/before*100 if before else 0
 rows.append((k,before,after,change))
p=root/'docs/04_optimization_report.md';p.parent.mkdir(parents=True,exist_ok=True)
with p.open('w') as f:
 f.write('# DE CP3 — Measured Optimization Report\n\n')
 f.write('## Methodology\n\nBaseline and optimized workloads were executed three times per query using `EXPLAIN (ANALYZE, BUFFERS)`. Write operations were rolled back. The optimized workload includes candidate rewrites for R19/R20 and targeted indexes. Hardware, cache, and query plans may affect results.\n\n')
 f.write('| Query | Baseline avg (ms) | Optimized avg (ms) | Improvement (%) |\n|---|---:|---:|---:|\n')
 for k,x,y,pct in rows:f.write(f'| {k} | {x:.3f} | {y:.3f} | {pct:+.2f} |\n')
 f.write('\n## Interpretation\n\nNegative percentages mean regression, not improvement. Inspect `benchmarks/results/optimized/*.txt` for scan choice and actual plan changes. An index does not guarantee a faster query. R19 replaces repeated correlated subqueries with a single grouped join; R20 changes the date predicate to a timestamp range.\n')
print('Wrote',p)
