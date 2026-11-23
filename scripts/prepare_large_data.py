#!/usr/bin/env python3
"""Safely extract the nine faculty CSVs; download the official release if needed."""
from pathlib import Path
import argparse
import hashlib
import shutil
import sys
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
URL = 'https://github.com/edusatyaki/DBMS-Google-Pay-Digital-Payments/releases/download/large-data/large_data.zip'
EXPECTED_SIZE = 262190235  # Verified from official release metadata on 2026-11-23.
EXPECTED_SHA256 = "dac0bf4f312de3796d2fe904846c84cac51fa974b2e7dc5871365c91c4659423"
TABLES = ('cities', 'users', 'bank_accounts', 'vpas', 'merchants',
          'transactions', 'rewards', 'bill_payments', 'disputes')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, default=ROOT / 'large_data.zip')
    parser.add_argument('--data-dir', type=Path, default=ROOT / 'large_data')
    parser.add_argument('--no-download', action='store_true')
    args = parser.parse_args()
    archive, target = args.archive.resolve(), args.data_dir.resolve()
    if not archive.exists():
        if args.no_download:
            parser.error(f'Archive missing: {archive}')
        print('Downloading the official faculty release (262 MB). This may take some time.', flush=True)
        temp = archive.with_name(archive.name + '.part')
        req = urllib.request.Request(URL, headers={'User-Agent': 'WikiNode-T0109-CP4/1.0'})
        with urllib.request.urlopen(req, timeout=60) as response, temp.open('wb') as out:
            shutil.copyfileobj(response, out, length=1024 * 1024)
        temp.replace(archive)
    size = archive.stat().st_size
    if size != EXPECTED_SIZE:
        raise SystemExit(f'Unexpected ZIP size {size}; official release is {EXPECTED_SIZE} bytes. Refusing to extract.')
    digest = hashlib.sha256()
    with archive.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    if digest.hexdigest() != EXPECTED_SHA256:
        raise SystemExit('ZIP SHA-256 does not match official GitHub release digest; refusing to extract.')
    print('Verified faculty ZIP size and SHA-256 checksum.', flush=True)
    with zipfile.ZipFile(archive) as zf:
        items = {}
        for member in zf.infolist():
            if member.is_dir() or member.filename.startswith('__MACOSX/'):
                continue
            filename = Path(member.filename).name
            if filename in {f'{table}.csv' for table in TABLES}:
                if filename in items:
                    raise SystemExit(f'Archive contains duplicate {filename}')
                items[filename] = member
        missing = sorted({f'{table}.csv' for table in TABLES} - items.keys())
        if missing:
            raise SystemExit(f'Archive is missing: {missing}')
        target.mkdir(parents=True, exist_ok=True)
        for name in (f'{table}.csv' for table in TABLES):
            item = items[name]
            path = target / name  # Names come from a fixed allow-list, not ZIP paths.
            if path.exists() and path.stat().st_size == item.file_size:
                print(f'Already present: {name}')
                continue
            temp = target / f'{name}.part'
            print(f'Extracting {name} ({item.file_size:,} bytes)', flush=True)
            with zf.open(item) as src, temp.open('wb') as out:
                shutil.copyfileobj(src, out, length=1024 * 1024)
            temp.replace(path)
    print(f'Ready: {target} (nine CSVs; never commit these files)')


if __name__ == '__main__':
    try:
        main()
    except (OSError, zipfile.BadZipFile) as exc:
        print(f'FAILED: {exc}', file=sys.stderr)
        raise SystemExit(1)
