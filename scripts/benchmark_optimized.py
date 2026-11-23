#!/usr/bin/env python3
"""Portable CP4 benchmark for the faculty's 30 optimized queries.

Runs 3 EXPLAIN (ANALYZE, BUFFERS) per query. Wraps writes in ROLLBACK.
Uses no GNU-only `sort -V`, so works on macOS and Linux.
"""
import argparse
import csv
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IDS = [f'R{x:02}' for x in range(1, 26)] + [f'W{x:02}' for x in range(1, 6)]
MARKER = re.compile(r'^--\s*@([RW]\d{2}|END)\s*$', re.M)
TIME = re.compile(r'Execution Time:\s*([0-9.]+)\s*ms')
SCAN = re.compile(r'((?:Parallel\s+)?(?:Index Only Scan|Index Scan|Bitmap Index Scan|Bitmap Heap Scan|Seq Scan)(?:\s+Backward)?(?:\s+using\s+\w+)?\s+on\s+\w+)', re.I)


def split_workload(source):
    chunks = {}
    active = None
    statements = []
    for line in source.splitlines():
        match = MARKER.fullmatch(line.strip())
        if match:
            if active is not None:
                chunks[active] = '\n'.join(statements).strip()
            active = match.group(1)
            statements = []
            if active == 'END':
                break
        elif active:
            statements.append(line)
    if set(chunks) != set(IDS):
        raise ValueError(f'Expected exactly 30 queries; found {len(chunks)}. Missing: {set(IDS)-set(chunks)}')
    for key, sql in chunks.items():
        # Every block is one SQL statement, and the query source is trusted project code.
        if not sql.rstrip().endswith(';'):
            raise ValueError(f'Incomplete SQL statement for {key}')
    return chunks


def run_one(db, key, statement, limit):
    if key.startswith('W'):
        sql = f'BEGIN;\nSET LOCAL search_path TO gpay;\nEXPLAIN (ANALYZE, BUFFERS) {statement}\nROLLBACK;\n'
    else:
        sql = f'SET search_path TO gpay;\nEXPLAIN (ANALYZE, BUFFERS) {statement}\n'
    proc = subprocess.run(['psql', '-X', '-q', '-A', '-t', '-v', 'ON_ERROR_STOP=1', '-d', db],
                          input=sql, text=True, capture_output=True, timeout=limit, check=False)
    if proc.returncode:
        raise RuntimeError(f'{key}: psql exit {proc.returncode}: {proc.stderr[-2500:]}')
    match = TIME.findall(proc.stdout)
    if len(match) != 1:
        raise RuntimeError(f'{key}: expected one Execution Time; got {len(match)}. {proc.stdout[-800:]}')
    return float(match[0]), proc.stdout


def write_summary(out, data, runs):
    with (out/'summary.csv').open('w', newline='') as file:
        w = csv.writer(file)
        w.writerow(['query_id','type','avg_ms','median_ms','min_ms','max_ms','scan_nodes'])
        for key in IDS:
            if key not in data: continue
            vals = sorted(data[key][0]); plan = data[key][1]
            nodes = list(dict.fromkeys(SCAN.findall(plan)))
            w.writerow([key,'WRITE' if key.startswith('W') else 'READ',
                        f'{sum(vals)/len(vals):.3f}',f'{vals[len(vals)//2]:.3f}',
                        f'{min(vals):.3f}',f'{max(vals):.3f}', ' | '.join(nodes) or '(no scan)'])


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--db', required=True, help='Existing dedicated large-data database')
    p.add_argument('--runs', type=int, default=3)
    p.add_argument('--timeout', type=int, default=600, help='Seconds per EXPLAIN run')
    p.add_argument('--out', type=Path, default=ROOT/'benchmarks/results/large')
    p.add_argument('--resume', action='store_true', help='Reuse complete 3-run plan files in this database')
    args = p.parse_args()
    if args.runs != 3:
        p.error('The faculty requires three runs for every query')
    out = args.out
    out.mkdir(parents=True, exist_ok=True)
    manifest = out/'BENCHMARK_DATABASE.txt'
    if manifest.exists() and manifest.read_text().strip() != args.db:
        p.error(f'Result directory belongs to database {manifest.read_text().strip()} (not {args.db})')
    manifest.write_text(args.db+'\n')
    queries = split_workload((ROOT/'sql/06_optimized_queries.sql').read_text())
    results = {}
    for i, key in enumerate(IDS, 1):
        plan_file = out/f'{key}.txt'
        times = []
        sections = []
        if args.resume and plan_file.exists():
            saved = plan_file.read_text()
            times = [float(v) for v in TIME.findall(saved)]
            if len(times)==3:
                results[key] = (times, saved)
                print(f'{i:02}/30 {key} resume avg={sum(times)/3:.3f} ms', flush=True)
                write_summary(out, results, args.runs)
                continue
            times = []
        for run in range(1, 4):
            elapsed, plan = run_one(args.db, key, queries[key], args.timeout)
            times.append(elapsed)
            sections.append(f'=== {key} run {run} ===\n{plan.rstrip()}\n')
            print(f'{i:02}/30 {key} run {run}: {elapsed:.3f} ms', flush=True)
        full_plan = '\n'.join(sections)
        plan_file.write_text(full_plan)
        results[key] = (times, full_plan)
        write_summary(out, results, args.runs)
    print(f'SUCCESS: 30 query IDs, 3 actual plans each, saved in {out}')


if __name__ == '__main__':
    main()
