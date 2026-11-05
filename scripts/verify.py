#!/usr/bin/env python3
"""Real local lab assertions; prints no credential values."""
import json
from pathlib import Path
import subprocess
import sys
from urllib.request import Request,urlopen
from urllib.error import HTTPError,URLError


def request(base,path,method='GET',body=None,token=None):
    headers={'Content-Type':'application/json'}
    if token:headers['X-Vault-Token']=token
    req=Request(base+path,data=json.dumps(body).encode() if body is not None else None,headers=headers,method=method)
    try:
        with urlopen(req,timeout=5) as r:return r.status,json.loads(r.read() or b'{}')
    except HTTPError as e:
        return e.code,{}
    except (URLError,TimeoutError):return 0,{}


def require(condition,message):
    if not condition:raise RuntimeError(message)


def identities(runtime):
    d=Path(runtime);meta=json.loads((d/'metadata.json').read_text());base=meta['urls']['vault']
    creds=json.loads((d/'bootstrap/secrets.json').read_text());app=json.loads((d/'app/config.json').read_text())
    root=(d/'vault/root-token').read_text()
    code,data=request(base,'/v1/auth/userpass/users?list=true',token=root)
    require(code==200 and data['data']['keys']==['albert','brenda','charlie'],'Exact synthetic identity set/order')
    for name in ['albert','brenda','charlie']:
        code,data=request(base,'/v1/auth/userpass/login/'+name,'POST',{'password':creds['users'][name]})
        require(code==200,name+' authenticates')
        token=data['auth']['client_token']
        try:
            code,_=request(base,'/v1/kv/data/workshop/db',token=token)
            require(code==(403 if name=='charlie' else 200),name+' read permission')
            code,_=request(base,'/v1/kv/data/workshop/db','POST',{'data':{'username':'workshop_app','password':creds['app_password']}},token)
            require(code==(200 if name=='brenda' else 403),name+' write permission')
            require(request(base,'/v1/sys/mounts',token=token)[0]==403,name+' cannot administer Vault')
        finally:request(base,'/v1/auth/token/revoke-self','POST',token=token)
    code,_=request(base,'/v1/auth/userpass/login/albert','POST',{'password':'invalid-not-a-lab-password'})
    require(code in [400,403],'Invalid password rejected')
    code,data=request(base,'/v1/auth/approle/login','POST',{'role_id':app['role_id'],'secret_id':app['secret_id']})
    require(code==200,'AppRole authenticates')
    token=data['auth']['client_token']
    try:
        code,data=request(base,'/v1/kv/data/workshop/db',token=token)
        require(code==200 and data['data']['data']['password']==creds['app_password'],'AppRole obtains correct DB credentials')
        require(request(base,'/v1/kv/data/workshop/db','POST',{'data':{}},token)[0]==403,'AppRole cannot write')
    finally:request(base,'/v1/auth/token/revoke-self','POST',token=token)
    print('PASS: persona authentication, read/write denials, admin denial, AppRole scope')


def database(runtime):
    meta=json.loads((Path(runtime)/'metadata.json').read_text());name=meta['name']
    cmd=['podman','exec','-i',name+'-postgres','psql','-X','-qAt','-v','ON_ERROR_STOP=1','-U','postgres','-d','workshop']
    r=subprocess.run(cmd,input='SET ROLE workshop_app; SELECT count(*) FROM messages;',capture_output=True,text=True)
    require(r.returncode==0 and r.stdout.strip()=='500','Read-only role reads all records')
    r=subprocess.run(cmd,input="SET ROLE workshop_app; INSERT INTO messages VALUES(-1,-1,'denied');",capture_output=True,text=True)
    require(r.returncode!=0 and 'permission denied' in r.stderr,'Read-only role cannot insert')
    r=subprocess.run(cmd,input='SET ROLE workshop_app; CREATE TABLE forbidden(id integer);',capture_output=True,text=True)
    require(r.returncode!=0 and 'permission denied' in r.stderr,'App cannot create tables')
    print('PASS: dataset count and application DB privilege denials')


def main():
    if len(sys.argv)!=2:raise RuntimeError('Usage: verify.py <instance runtime path>')
    identities(sys.argv[1]);database(sys.argv[1])

if __name__=='__main__':
    try:main()
    except Exception as e:print('FAIL:',str(e),file=sys.stderr);sys.exit(1)
