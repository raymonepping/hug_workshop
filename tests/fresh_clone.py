#!/usr/bin/env python3
"""Build and verify a clean checkout without private developer files or cached app layers."""
import json
import fcntl
import os
from pathlib import Path
import secrets
import subprocess
import sys
from urllib.request import urlopen
from urllib.error import HTTPError

ROOT=Path(__file__).resolve().parents[1]
ID=secrets.token_hex(3)
DEST=ROOT/'.workshop'/('fresh-'+ID)
INSTANCE='fresh-'+ID
LOGS=ROOT/'.workshop/validation';LOGS.mkdir(parents=True,exist_ok=True)
ENV={**os.environ,'INSTANCE':INSTANCE,'POSTGRES_PORT':'45432','VAULT_PORT':'48200','BACKEND_PORT':'43004','FRONTEND_PORT':'45173','AUTO_APPROVE':'1','CONFIRM':INSTANCE,'PROFILE':'starter','MODE':'required','VAULT_EDITION':'community'}
os.umask(0o077)

def run(target,**extra):
    with (LOGS/('fresh-'+ID+'-'+target+'.log')).open('w') as log:
        subprocess.run(['make',target],cwd=DEST,env={**ENV,**extra},stdout=log,stderr=subprocess.STDOUT,check=True)
    print('PASS: clean checkout',target,extra,flush=True)

def health():
    with urlopen('http://127.0.0.1:43004/health',timeout=10) as r:return json.load(r)

def snapshot():
    lines=subprocess.check_output(['podman','ps','-a','--format','{{.Names}} {{.ID}}'],text=True).splitlines()
    return dict(line.split(' ',1) for line in lines)
# Hold the source checkout's operation lock; cloned commands have a separate lock.
SOURCE_LOCK=(ROOT/'.workshop/operation.lock').open('a')
try:fcntl.flock(SOURCE_LOCK,fcntl.LOCK_EX|fcntl.LOCK_NB)
except BlockingIOError:raise SystemExit('Another source-checkout mutation is running; retry fresh-clone acceptance afterward')
before=snapshot()
(LOGS/('fresh-'+ID+'-before.json')).write_text(json.dumps(before))
subprocess.run(['git','clone','--no-local',str(ROOT),str(DEST)],check=True)
assert not any((DEST/p).exists() for p in ['.env','backend/.env','backend/node_modules','frontend/node_modules','.workshop'])
assert (DEST/'backend/vault.js').exists() and (DEST/'backend/package-lock.json').exists()
run('doctor');run('init')
# No cache for application dependency layers; all inputs are from committed source.
script="""
import sys
sys.path.insert(0,'scripts')
import lab
real=lab.run

def uncached(args,**kwargs):
    if list(args[:2])==['podman','build']:args=[*args[:2],'--no-cache',*args[2:]]
    return real(args,**kwargs)
lab.run=uncached
lab.build(lab.config())
"""
with (LOGS/('fresh-'+ID+'-uncached-build.log')).open('w') as log:
    subprocess.run([sys.executable,'-c',script],cwd=DEST,env=ENV,stdout=log,stderr=subprocess.STDOUT,check=True)
print('PASS: uncached application builds from tracked manifests/locks',flush=True)
run('up');assert health()['state']=='exercise_incomplete'
try:urlopen('http://127.0.0.1:43004/api/items');raise AssertionError('starter exposed data')
except HTTPError as e:assert e.code==403
run('infra',MODE='baseline');h=health();assert h['dbReady'] and not h['unlocked'] and h['channel']=='env'
result=subprocess.run(['make','verify'],cwd=DEST,env=ENV,capture_output=True,text=True)
assert result.returncode!=0,'Verifier must fail on baseline/unfinished core'
print('PASS: real baseline and expected incomplete-core verification failure',flush=True)
run('infra',PROFILE='solution',MODE='required');assert health()['unlocked']
run('test');run('verify');run('test-browser')
run('destroy')
name=json.loads((DEST/'workshop/config.json').read_text())['prefix']+INSTANCE
for kind in ['network','volume']:
    assert not subprocess.check_output(['podman',kind,'ls','--filter','label=workshop.instance='+name,'--format','{{.Name}}'],text=True).strip()
after=snapshot()
(LOGS/('fresh-'+ID+'-after.json')).write_text(json.dumps(after))
changed=[name for name,value in before.items() if after.get(name)!=value]
if changed:print('Changed pre-existing resource names:',changed,flush=True)
assert not changed
print('PASS: clean-clone acceptance and unrelated-resource isolation; evidence checkout:',DEST,flush=True)
