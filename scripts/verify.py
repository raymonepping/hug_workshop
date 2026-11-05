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


def api(runtime):
    d=Path(runtime);meta=json.loads((d/'metadata.json').read_text());base=meta['urls']['backend']
    code,health=request(base,'/health')
    require(code==200 and health.get('unlocked') is True and health.get('mode')=='required','Core verification requires completed Vault exercise in required mode')
    code,body=request(base,'/api/items?limit=32');rows=body.get('items',[])
    require(code==200 and len(rows)==32,'Authorized API returns requested limit')
    require(all(set(r)=={'id','idx','title'} and type(r['id']) is int and type(r['idx']) is int and isinstance(r['title'],str) for r in rows),'Normalized item shape')
    require(rows==sorted(rows,key=lambda r:(r['idx'],r['id'])),'Explicit puzzle ordering')
    require(''.join(r['title'][0] for r in rows)=='WEARETHEGUARDIANSOFOUROWNSYSTEMS','Puzzle initials')
    require(len(request(base,'/api/items?limit=999')[1].get('items',[]))==100,'Maximum limit cap')
    for limit in ['0','-1','abc','1.5']:
        require(request(base,'/api/items?limit='+limit)[0]==400,'Invalid limit rejected')
    root=(d/'vault/root-token').read_text();vault=meta['urls']['vault'];path='/v1/sys/policies/acl/workshop-app'
    code,original=request(vault,path,token=root);require(code==200,'Read app policy for isolated denial fixture')
    try:
        require(request(vault,path,'PUT',{'policy':'path "kv/data/workshop/db" { capabilities = ["deny"] }'},root)[0]==204,'Apply temporary app denial')
        require(request(base,'/api/items')[0]==403,'Strict mode denies despite baseline credentials')
        require(request(base,'/health')[1].get('unlocked') is False,'Health reflects denied policy immediately')
    finally:
        require(request(vault,path,'PUT',{'policy':original['data']['policy']},root)[0]==204,'Restore app policy')
    require(request(base,'/health')[1].get('unlocked') is True,'Recover after policy restoration')
    for path in ['/package.json','/frontend.js','/.env','/node_modules/express/package.json']:
        require(request(meta['urls']['frontend'],path)[0]==404,'Frontend private route denied')
    print('PASS: API provenance, puzzle, limits, real policy denial/recovery and private-file denial')


def privacy(runtime):
    d=Path(runtime)
    for relative in ['bootstrap/secrets.json','postgres/admin-password','vault/root-token','app/config.json']:
        require((d/relative).stat().st_mode & 0o077==0,'Private credential file permissions')
    credentials=json.loads((d/'bootstrap/secrets.json').read_text())
    secrets=[credentials['app_password'],*credentials['users'].values(),(d/'postgres/admin-password').read_text(),(d/'vault/root-token').read_text()]
    if (d/'vault/vault.hclic').exists():secrets.append((d/'vault/vault.hclic').read_text())
    state=(d/'terraform.tfstate').read_text()
    require(not any(value in state for value in secrets if value),'No credential values in Terraform state')
    app_raw=(d/'app/config.json').read_text()
    forbidden=[*credentials['users'].values(),(d/'postgres/admin-password').read_text(),(d/'vault/root-token').read_text()]
    if (d/'vault/vault.hclic').exists():forbidden.append((d/'vault/vault.hclic').read_text())
    require(not any(value in app_raw for value in forbidden if value),'Application configuration excludes human/admin/license material')
    print('PASS: runtime permissions and Terraform credential-value exclusion')


def main():
    if len(sys.argv)!=2:raise RuntimeError('Usage: verify.py <instance runtime path>')
    identities(sys.argv[1]);database(sys.argv[1]);api(sys.argv[1]);privacy(sys.argv[1])

if __name__=='__main__':
    try:main()
    except Exception as e:print('FAIL:',str(e),file=sys.stderr);sys.exit(1)
