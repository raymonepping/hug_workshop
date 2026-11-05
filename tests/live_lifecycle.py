#!/usr/bin/env python3
"""Isolated lifecycle acceptance run. No unrelated resource is changed."""
import json
import os
from pathlib import Path
import subprocess
import sys
from urllib.request import urlopen

ROOT=Path(__file__).resolve().parents[1]
INSTANCE='cycle'
PREFIX=json.loads((ROOT/'workshop/config.json').read_text())['prefix']
NAME=PREFIX+INSTANCE
ENV={**os.environ,'INSTANCE':INSTANCE,'PREFIX':PREFIX,'POSTGRES_PORT':'35432','VAULT_PORT':'38200','BACKEND_PORT':'33004','FRONTEND_PORT':'35173','AUTO_APPROVE':'1','CONFIRM':INSTANCE,'PROFILE':'solution','MODE':'required','VAULT_EDITION':'community'}
RUNTIME=ROOT/'.workshop'/INSTANCE
LOGS=ROOT/'.workshop/validation';LOGS.mkdir(parents=True,exist_ok=True)

def output(args):return subprocess.check_output(args,text=True).strip()
def run(target):
    with (LOGS/('cycle-'+target+'.log')).open('w') as log:
        subprocess.run(['make',target],cwd=ROOT,env=ENV,stdout=log,stderr=subprocess.STDOUT,check=True)
    print('PASS:',target,flush=True)
def health():
    with urlopen('http://127.0.0.1:33004/health',timeout=10) as r:return json.load(r)
def resources(kind):
    command=['podman','ps','-a','--filter','label=workshop.instance='+NAME,'--format','{{.ID}}'] if kind=='container' else ['podman',kind,'ls','--filter','label=workshop.instance='+NAME,'--format','{{.Name}}']
    return output(command).splitlines()

if resources('container') or resources('volume'):
    raise SystemExit('Refusing to reuse existing cycle resources; choose/clean a dedicated test instance explicitly')
before=set(output(['podman','ps','-a','--format','{{.ID}}']).splitlines())
run('up');run('verify')
initial=json.loads((RUNTIME/'bootstrap/secrets.json').read_text())
run('configure');run('seed')
assert 'changed=0' in (LOGS/'cycle-configure.log').read_text()
assert 'changed=0' in (LOGS/'cycle-seed.log').read_text()
run('down');assert not resources('container') and resources('volume')
run('up');assert health()['unlocked'];assert json.loads((RUNTIME/'bootstrap/secrets.json').read_text())==initial
# Recreate lost Vault contents and a partially rendered app file.
subprocess.run(['podman','restart',NAME+'-vault'],check=True,capture_output=True)
assert health()['unlocked'] is False
(RUNTIME/'app/config.json').unlink()
run('configure');assert health()['unlocked'];run('verify')
# DB interruption must be visible and recover on the next request.
subprocess.run(['podman','stop',NAME+'-postgres'],check=True,capture_output=True)
assert health()['state']=='db_unavailable'
run('infra');run('configure');assert health()['unlocked']
run('reset');assert health()['unlocked'];assert json.loads((RUNTIME/'bootstrap/secrets.json').read_text())!=initial
run('verify');run('destroy')
assert not resources('container') and not resources('volume') and not resources('network')
after=set(output(['podman','ps','-a','--format','{{.ID}}']).splitlines())
assert before.issubset(after),'An unrelated container disappeared'
print('PASS: convergence, retained data/credentials, interrupted configure recovery, DB/Vault recovery, reset, scoped teardown, unrelated resource preservation')
