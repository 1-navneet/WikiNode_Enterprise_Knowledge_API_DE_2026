#!/usr/bin/env python3
"""Validate all nine faculty seed CSVs before PostgreSQL loading.

Usage (from repository root): python3 scripts/validate_csvs.py
Reads seed_data/*.csv if present, otherwise seed_data.zip (without extracting).
No third-party dependencies. Does not modify the data.
"""
import csv
import io
import json
import re
import sys
import zipfile
from collections import Counter
from pathlib import Path

EXPECTED = {
    'cities': 10, 'users': 40000, 'bank_accounts': 53333, 'vpas': 53333,
    'merchants': 3000, 'transactions': 250468, 'rewards': 39799,
    'bill_payments': 30000, 'disputes': 3569,
}
HEADERS = {
    'cities': 'city_id city_name state',
    'users': 'user_id full_name phone email city_id kyc_status is_blocked created_at',
    'bank_accounts': 'account_id user_id bank_name ifsc account_last4 account_type is_primary linked_at',
    'vpas': 'vpa user_id account_id is_active created_at',
    'merchants': 'merchant_id merchant_name mcc merchant_vpa city_id is_verified onboarded_on',
    'transactions': 'txn_id upi_ref txn_type payer_vpa payee_vpa merchant_id amount note initiated_at completed_at status failure_code',
    'rewards': 'reward_id user_id txn_id reward_type amount status issued_at expires_at credited_at',
    'bill_payments': 'bill_id user_id biller_category biller_name consumer_number amount due_date status paid_at',
    'disputes': 'dispute_id txn_id raised_by reason raised_at status resolved_at',
}
PRIMARY = {
    'cities':'city_id','users':'user_id','bank_accounts':'account_id','vpas':'vpa',
    'merchants':'merchant_id','transactions':'txn_id','rewards':'reward_id',
    'bill_payments':'bill_id','disputes':'dispute_id',
}


def load_csvs(folder: Path, zip_path: Path):
    data = {}
    if folder.is_dir():
        for table in EXPECTED:
            path = folder / (table + '.csv')
            with path.open(newline='', encoding='utf-8-sig') as handle:
                reader = csv.DictReader(handle)
                assert reader.fieldnames == HEADERS[table].split(), f'{path}: unexpected columns {reader.fieldnames}'
                data[table] = list(reader)
    elif zip_path.is_file():
        with zipfile.ZipFile(zip_path) as archive:
            for table in EXPECTED:
                matches = [name for name in archive.namelist() if name.endswith('/'+table+'.csv') or name == table+'.csv']
                assert len(matches) == 1, f'{zip_path}: expected one {table}.csv, found {matches}'
                with archive.open(matches[0]) as raw:
                    reader = csv.DictReader(io.TextIOWrapper(raw, encoding='utf-8-sig', newline=''))
                    assert reader.fieldnames == HEADERS[table].split(), f'{table}: unexpected columns {reader.fieldnames}'
                    data[table] = list(reader)
    else:
        raise FileNotFoundError('Missing seed_data/ and seed_data.zip. Get the original faculty seed_data.zip and retry.')
    return data


def validate(data):
    failures = []
    counts = {name:len(rows) for name,rows in data.items()}
    for table, expected in EXPECTED.items():
        if counts[table] != expected:
            failures.append(f'{table}: expected {expected} rows, got {counts[table]}')
        ids = [row[PRIMARY[table]] for row in data[table]]
        if len(set(ids)) != len(ids):
            failures.append(f'{table}: primary key {PRIMARY[table]} is not unique')

    def foreign(source, column, parent, parent_pk):
        keys = {r[parent_pk] for r in data[parent]}
        invalid = sum(bool(r[column]) and r[column] not in keys for r in data[source])
        if invalid:
            failures.append(f'{source}.{column}: {invalid} missing {parent}.{parent_pk} values')

    for source,col,parent,pk in [
        ('users','city_id','cities','city_id'),
        ('bank_accounts','user_id','users','user_id'),
        ('vpas','user_id','users','user_id'),
        ('vpas','account_id','bank_accounts','account_id'),
        ('merchants','city_id','cities','city_id'),
        ('transactions','merchant_id','merchants','merchant_id'),
        ('rewards','user_id','users','user_id'),
        ('rewards','txn_id','transactions','txn_id'),
        ('bill_payments','user_id','users','user_id'),
        ('disputes','txn_id','transactions','txn_id'),
        ('disputes','raised_by','users','user_id'),
    ]:
        foreign(source,col,parent,pk)

    users = {r['user_id']:r for r in data['users']}
    accounts = {r['account_id']:r for r in data['bank_accounts']}
    merchants = {r['merchant_id']:r for r in data['merchants']}
    vpas = {r['vpa']:r for r in data['vpas']}
    transactions = {r['txn_id']:r for r in data['transactions']}
    primary = Counter(r['user_id'] for r in data['bank_accounts'] if r['is_primary'].lower() in ('t','true','1'))
    primary_bad = sum(primary[user_id] != 1 for user_id in users)
    if primary_bad: failures.append(f'{primary_bad} users do not have exactly one primary bank account')
    mismatch_vpa = sum(accounts.get(r['account_id'],{}).get('user_id') != r['user_id'] for r in data['vpas'])
    if mismatch_vpa: failures.append(f'{mismatch_vpa} VPAs mismatch linked bank account owner')
    mismatch_merchant = sum(r['payee_vpa'] != merchants.get(r['merchant_id'],{}).get('merchant_vpa') for r in data['transactions'] if r['txn_type'] == 'P2M')
    if mismatch_merchant: failures.append(f'{mismatch_merchant} P2M payments mismatch merchant VPA')
    reward_mismatch = 0
    for reward in data['rewards']:
        transaction = transactions.get(reward['txn_id'])
        if transaction:
            payer = vpas.get(transaction['payer_vpa'])
            if payer and payer['user_id'] != reward['user_id']:
                reward_mismatch += 1
    if reward_mismatch: failures.append(f'{reward_mismatch} rewards mismatch transaction payer')

    def count_invalid(table, predicate, description):
        bad=sum(not predicate(row) for row in data[table])
        if bad: failures.append(f'{table}: {bad} rows fail {description}')

    count_invalid('users', lambda r: bool(re.fullmatch(r'[0-9]{10}',r['phone'])), '10-digit phone')
    count_invalid('users', lambda r: not r['email'] or '@' in r['email'][1:], 'email format')
    count_invalid('bank_accounts',lambda r: bool(re.fullmatch(r'[A-Z]{4}0[A-Z0-9]{6}',r['ifsc'])),'IFSC')
    count_invalid('bank_accounts',lambda r: bool(re.fullmatch(r'[0-9]{4}',r['account_last4'])),'last4')
    count_invalid('bank_accounts',lambda r: r['account_type'] in {'SAVINGS','CURRENT','SALARY','NRE','NRO'},'account type')
    count_invalid('users',lambda r: r['kyc_status'] in {'VERIFIED','PENDING','REJECTED','NOT_STARTED','UNVERIFIED'},'KYC status')
    count_invalid('merchants',lambda r: bool(re.fullmatch(r'[0-9]{4}',r['mcc'])),'merchant category code')
    count_invalid('merchants',lambda r: bool(re.fullmatch(r'[^ @]+@[^ @]+',r['merchant_vpa'])),'merchant VPA')
    count_invalid('vpas',lambda r: bool(re.fullmatch(r'[^ @]+@[^ @]+',r['vpa'])),'user VPA')
    count_invalid('transactions',lambda r: bool(re.fullmatch(r'[0-9]{12}',r['upi_ref'])),'UPI reference')
    count_invalid('transactions',lambda r: r['txn_type'] in {'P2P','P2M'},'transaction type')
    count_invalid('transactions',lambda r: r['status'] in {'SUCCESS','FAILED','PENDING','REVERSED','REFUNDED'},'transaction status')
    count_invalid('transactions',lambda r: (r['txn_type']=='P2M') == bool(r['merchant_id']),'P2M merchant association')
    count_invalid('transactions',lambda r: r['payer_vpa']!=r['payee_vpa'],'payer/payee distinct')
    count_invalid('transactions',lambda r: 0 < float(r['amount']) <= 100000,'positive amount <=100000')
    count_invalid('transactions',lambda r: r['status']!='PENDING' or not r['completed_at'],'pending incomplete')
    count_invalid('transactions',lambda r: not r['failure_code'] or bool(r['failure_code'].strip()),'nonblank failure code')
    count_invalid('transactions',lambda r: r['status']!='REFUNDED' or r['txn_type']=='P2M','refund only for P2M')
    count_invalid('rewards',lambda r: float(r['amount']) >= 0,'reward amount')
    count_invalid('rewards',lambda r: r['expires_at']>=r['issued_at'],'expiry after issue')
    count_invalid('rewards',lambda r: bool(re.fullmatch(r'[A-Z][A-Z0-9_]*', r['reward_type'])),'uppercase reward type code')
    count_invalid('rewards',lambda r: r['status'] in {'UNSCRATCHED','CREDITED','EXPIRED','SCRATCHED'},'reward status')
    count_invalid('bill_payments',lambda r: float(r['amount']) > 0,'positive bill amount')
    count_invalid('bill_payments',lambda r: bool(r['consumer_number'].strip()),'consumer number')
    count_invalid('bill_payments',lambda r: r['status'] in {'PAID','DUE','OVERDUE','FAILED','CANCELLED'},'bill status')
    count_invalid('disputes',lambda r: not r['resolved_at'] or r['resolved_at']>=r['raised_at'],'dispute chronology')
    count_invalid('disputes',lambda r: bool(r['reason'].strip()),'dispute reason')
    count_invalid('disputes',lambda r: r['status'] in {'OPEN','IN_PROGRESS','RESOLVED','REJECTED','CLOSED'},'dispute status')
    for table, col in [('users','phone'),('users','email'),('merchants','merchant_vpa'),('transactions','upi_ref')]:
        values = [r[col] for r in data[table] if r[col]]
        if len(values) != len(set(values)):
            failures.append(f'{table}.{col}: duplicates violate UNIQUE constraint')
    return {'row_counts':counts, 'reward_types':dict(sorted(Counter(r['reward_type'] for r in data['rewards']).items())), 'checks': 'FAIL' if failures else 'PASS', 'failures':failures,
            'primary_account_violations':primary_bad, 'vpa_owner_mismatches':mismatch_vpa,
            'merchant_vpa_mismatches':mismatch_merchant, 'reward_owner_mismatches':reward_mismatch}

if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1]
    try:
        data=load_csvs(root/'seed_data',root/'seed_data.zip')
        result=validate(data)
    except Exception as e:
        print('UNABLE TO VALIDATE:',e,file=sys.stderr)
        sys.exit(2)
    print(json.dumps(result,indent=2))
    sys.exit(0 if result['checks']=='PASS' else 1)
