"""Seed loopback scenario states with real REST commands, never database edits.
The configured bank/identity providers belong to MobileScenarioHost test source.
No real transfer occurs; reports and confirmations simulate human test evidence.
"""
import argparse
from datetime import datetime, timedelta, timezone
import json
import time
from pathlib import Path
import urllib.request
import urllib.error
from uuid import uuid4

parser = argparse.ArgumentParser()
parser.add_argument('--manifest', type=Path, required=True)
args = parser.parse_args()
path = args.manifest.resolve(strict=True)
if '.superpowers' not in path.parts:
    raise SystemExit('Use the gitignored loopback manifest')
data = json.loads(path.read_text(encoding='utf-8'))
if data.get('testOnly') is not True or data['apiBaseUrl'] != 'http://127.0.0.1:18080/api/v1':
    raise SystemExit('Exact test host required')
roles = list(data['roles'].values())
owner, member = roles[0], roles[2]
def call(method, route, actor, body=None):
    headers = {'Authorization': 'Bearer '+actor['token'], 'Content-Type':'application/json'}
    if method == 'POST':
        headers['Idempotency-Key'] = str(uuid4())
    request = urllib.request.Request(data['apiBaseUrl']+route, method=method, headers=headers,
        data=None if body is None else json.dumps(body).encode())
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        result=json.load(error)
        raise RuntimeError(f'{method} {route}: HTTP {error.code} {result.get("code")}') from None
def get(route, actor=owner): return call('GET',route,actor)
def post(route, body, actor=owner): return call('POST',route,actor,body)
def iso(value): return value.isoformat().replace('+00:00','Z')
def version(event): return get(f'/events/{event}/finance')['version']
now = datetime.now(timezone.utc)
for index, actor in enumerate(roles):
    account=get('/me/bank-account', actor)
    if not account['registered']:
        post('/me/bank-account',{'version':0,'bankName':'TEST 은행','accountNumber':f'900000000{index:04}','holderName':'테스트 전용'},actor)
if not data.get('financeEventId'):
    club = data['clubId']
    event = post(f'/clubs/{club}/events',{'version':get(f'/clubs/{club}')['version'],
        'title':'TEST 실제 정산·환불·선지출 흐름','kind':'LIGHTNING','publicEvent':True,
        'startsAt':iso(now+timedelta(seconds=10)), 'endsAt':iso(now+timedelta(seconds=20)), 'settlementMode':'POSTPAY'})['id']
    round_ = post(f'/events/{event}/rounds',{'version':get(f'/events/{event}')['version'],
        'capacity':10,'closesAt':iso(now+timedelta(seconds=5)),'cancellationFee':1000})['id']
    for actor in (owner,member):
        state=post(f'/rounds/{round_}/participations',{'version':get(f'/events/{event}')['rounds'][0]['version']},actor)
        if state['status']=='LATE_REQUESTED':
            post(f'/rounds/{round_}/participations/{state["id"]}/approve',{'version':state['version'],'reason':'본인 마감 후 합류 요청 승인 · 테스트'})
    post(f'/events/{event}/finance/open',{'version':0,'mode':'POSTPAY'})
    post(f'/events/{event}/finance/expenses',{'version':version(event),'roundId':round_,'title':'TEST 원주최자 개인 선지출','amount':20000,
        'fundings':[{'paidByUserId':owner['userId'],'source':'PERSONAL','amount':20000,'actualPaidAt':iso(now-timedelta(days=1,hours=1))}]})
    time.sleep(max(0,(now+timedelta(seconds=21)-datetime.now(timezone.utc)).total_seconds()))
    post(f'/events/{event}/finance/register',{'version':version(event),'deadline':iso(now+timedelta(days=2))})
    requests=get(f'/events/{event}/finance',member)['requests']
    request=next(q for q in requests if q['userId']==member['userId'] and q['remaining']>0)
    report=post(f'/events/{event}/finance/reports',{'version':version(event),'requestId':request['id'],'amount':15000},member)
    post(f'/events/{event}/finance/reports/{report["id"]}/verify',{'version':version(event),'amount':15000,
        'transactionReference':'TEST-SIMULATED-RECEIPT-'+str(uuid4()),'actualReceivedAt':iso(now-timedelta(minutes=1)),
        'allocations':[{'roundId':round_,'kind':'ATTENDANCE','amount':15000}]})
    post(f'/events/{event}/finance/refunds',{'version':version(event),'userId':member['userId'],'amount':5000})
    data['financeEventId']=event
    data['financeRoundId']=round_
    path.write_text(json.dumps(data,ensure_ascii=False),encoding='utf-8')
print('Loopback finance fixture ready: real API requests and canonical positions; no real bank transfer.')
