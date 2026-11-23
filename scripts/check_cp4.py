#!/usr/bin/env python3
"""Fail CP4 validation unless source, all 90 plans and storage are verified."""
import csv
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'benchmarks/results'
IDS = [f'R{i:02}' for i in range(1,26)] + [f'W{i:02}' for i in range(1,6)]
TABLES = {'cities','users','bank_accounts','vpas','merchants','transactions','rewards','bill_payments','disputes'}
TIME = re.compile(r'Execution Time:\s*([\d.]+)\s*ms')
fail=[]


def read_csv(path):
    if not path.exists():
        fail.append('MISSING '+str(path.relative_to(ROOT)))
        return []
    with path.open(newline='') as stream: return list(csv.DictReader(stream))


for file in ('sql/08_partitioning.sql','docs/partitioning_design.md',
             'docs/05_scalability_report.md',
             'scripts/benchmark_optimized.py','scripts/verify_large_integrity.sql'):
    if not (ROOT/file).is_file():fail.append('MISSING '+file)

summary=read_csv(OUT/'large/summary.csv')
by_id={r.get('query_id',''):r for r in summary}
if len(summary)!=30 or set(by_id)!=set(IDS):
    fail.append(f'Large summary must contain 30 distinct queries, got {len(summary)} rows and {len(by_id)} unique IDs')
for q in IDS:
    plan=OUT/'large'/f'{q}.txt'
    if not plan.exists():
        fail.append('MISSING '+str(plan.relative_to(ROOT))); continue
    times=[float(t) for t in TIME.findall(plan.read_text())]
    if len(times)!=3:
        fail.append(f'{q}: expected 3 actual Execution Time values, got {len(times)}');continue
    try:
        observed=float(by_id[q]['avg_ms'])
        if not math.isfinite(observed) or observed < 0 or abs(observed-sum(times)/3)>0.025:
            fail.append(f'{q}: avg_ms not consistent with 3-run plan')
    except (KeyError,ValueError,TypeError):fail.append(f'{q}: missing/invalid avg_ms')

counts=read_csv(OUT/'large/row_counts.csv')
if len(counts)!=9 or {r.get('table_name') for r in counts}!=TABLES:
    fail.append('Large row counts must contain the 9 expected tables')
else:
    try:
        grand=sum(int(r['rows']) for r in counts)
        if grand<6000000:fail.append('Large dataset row count unexpectedly low: '+str(grand))
    except (KeyError,ValueError):fail.append('Invalid row counts')

for variant in ('optimized','large'):
    rows=read_csv(OUT/variant/'storage.csv')
    if len(rows)!=9 or {r.get('table_name') for r in rows}!=TABLES:
        fail.append(f'{variant} storage must contain nine distinct table rows')
    else:
        for r in rows:
            try:
                if not (int(r['total_bytes'])>0 and int(r['index_bytes'])>=0 and int(r['heap_bytes'])>=0):
                    fail.append(f'{variant}: invalid storage sizes for {r["table_name"]}')
            except (KeyError,ValueError):fail.append(f'{variant}: invalid storage CSV')

prune=OUT/'large/partition_pruning_plan.txt'
if not prune.exists() or 'FILTERED:' not in prune.read_text() or len(TIME.findall(prune.read_text()))<2:
    fail.append('Missing measured filtered/unfiltered partition-pruning evidence')

integrity=OUT/'large/integrity_check.txt'
if not integrity.exists():fail.append('Missing large-data integrity check output')

report=ROOT/'docs/05_scalability_report.md'
if report.exists():
    body=report.read_text()
    if 'NOT MEASURED' in body:
        fail.append('Report contains NOT MEASURED: finish benchmarks/seed storage and regenerate')
    for q in IDS:
        if not re.search(r'^\|\s*'+q+r'\s*\|',body,re.M):
            fail.append(f'Missing {q} in scalability report')

ignored=(ROOT/'.gitignore').read_text() if (ROOT/'.gitignore').exists() else ''
if 'large_data/' not in ignored or 'large_data.zip' not in ignored:
    fail.append('.gitignore must exclude both large_data/ and large_data.zip')

print('CP4: '+'READY FOR MANUAL REVIEW' if not fail else 'CP4: INCOMPLETE')
for issue in fail: print(' - '+issue)
if fail:raise SystemExit(1)
print('Validated artifacts are structurally complete; human review is still required for target misses, code correctness and attribution.')
