#!/usr/bin/env python3
"""Portable workshop entry point. Terraform owns infrastructure; Ansible configures it."""
import argparse
import contextlib
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import secrets
import socket
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
DEFAULTS = json.loads((ROOT / 'workshop/config.json').read_text())
COMMANDS = ['help','doctor','init','build','plan','infra','configure','seed','up','status','verify','test','down','destroy','reset']


def run(args, **kwargs):
    return subprocess.run([str(x) for x in args], check=True, **kwargs)


def output(args):
    return run(args, capture_output=True, text=True).stdout.strip()


def config(environ=None):
    env = os.environ if environ is None else environ
    instance = env.get('INSTANCE', 'default')
    prefix = env.get('PREFIX', DEFAULTS['prefix'])
    if not re.fullmatch(r'[a-z][a-z0-9-]{0,24}', instance):
        raise ValueError('INSTANCE must be a lowercase name (maximum 25 characters)')
    if not re.fullmatch(r'hug-[a-z0-9-]{3,30}-', prefix):
        raise ValueError('PREFIX must be a unique hug-...- prefix')
    ports = {k: int(env.get(k.upper() + '_PORT', v)) for k,v in DEFAULTS['ports'].items()}
    if len(set(ports.values())) != 4 or any(not 1024 <= v <= 65535 for v in ports.values()):
        raise ValueError('Ports must be distinct integers between 1024 and 65535')
    profile = env.get('PROFILE', 'starter')
    mode = env.get('MODE', 'required')
    if profile not in ['starter','solution'] or mode not in ['required','baseline']:
        raise ValueError('PROFILE=starter|solution and MODE=required|baseline')
    return {**DEFAULTS, 'instance':instance, 'prefix':prefix, 'name':prefix+instance,
            'runtime':str(ROOT/'.workshop'/instance), 'ports':ports, 'profile':profile, 'mode':mode}


def engine_socket():
    explicit = os.environ.get('PODMAN_SOCKET')
    if explicit:
        return explicit if explicit.startswith('unix://') else 'unix://' + explicit
    if platform.system() == 'Darwin':
        machines = json.loads(output(['podman','machine','inspect']))
        active = [m for m in machines if m.get('State') == 'running']
        if not active:
            raise ValueError('Start your Podman machine first')
        return 'unix://' + active[0]['ConnectionInfo']['PodmanSocket']['Path']
    return 'unix://' + os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}') + '/podman/podman.sock'


def doctor(c):
    for tool in ['git','make','terraform','podman']:
        if not shutil.which(tool):
            raise ValueError('Install prerequisite: ' + tool)
    if sys.version_info < (3,12):
        raise ValueError('Python 3.12 or newer is required')
    info=json.loads(output(['podman','info','--format','json']))
    print('Python',platform.python_version(),'Podman',info['version']['Version'],info['host']['arch'])
    print('Terraform',json.loads(output(['terraform','version','-json']))['terraform_version'])
    sock=engine_socket()
    if not Path(sock.removeprefix('unix://')).is_socket():
        raise ValueError('Podman API socket is unavailable; see docs/SETUP.md')
    owned=output(['podman','ps','-a','--filter','label=workshop.instance='+c['name'],'--format','{{.Names}}']).splitlines()
    for service,port in c['ports'].items():
        if c['name']+'-'+service in owned:
            continue
        with socket.socket() as s:
            try:s.bind(('127.0.0.1',port))
            except OSError:raise ValueError(f'{service} port {port} is occupied; override {service.upper()}_PORT') from None
    print('Instance:',c['name'],'API:',sock,'ports:',c['ports'])


def private_json(path, value):
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
    path.write_text(json.dumps(value,indent=2)+'\n');path.chmod(0o600)


def initialize(c):
    d=Path(c['runtime']);d.mkdir(parents=True,exist_ok=True,mode=0o700);d.chmod(0o700)
    for name in ['postgres','vault','bootstrap','app']:
        (d/name).mkdir(exist_ok=True,mode=0o700)
    for name in ['postgres/admin-password','vault/root-token']:
        f=d/name
        if not f.exists():f.write_text(secrets.token_hex(24));f.chmod(0o600)
    f=d/'bootstrap/secrets.json'
    if not f.exists():
        private_json(f,{'app_password':secrets.token_hex(24),'users':{u['name']:secrets.token_hex(16) for u in json.loads((ROOT/'workshop/users.yml').read_text())['users']}})
    if not (d/'app/config.json').exists():private_json(d/'app/config.json',{})
    if not (d/'images.json').exists():private_json(d/'images.json',{'backend':'localhost/'+c['name']+'-backend:pending','frontend':'localhost/'+c['name']+'-frontend:pending'})
    tf(c,['init','-input=false','-reconfigure','-backend-config=path='+str(d/'terraform.tfstate')],variables=False)


def tf(c,args,variables=True):
    d=Path(c['runtime']);env=os.environ.copy();env['TF_DATA_DIR']=str(d/'terraform')
    env['TF_IN_AUTOMATION']='1'
    command=['terraform','-chdir='+str(ROOT/'infra'),*args]
    if variables:
        images={k:v for k,v in c['images'].items() if k != 'node'}
        images.update(json.loads((d/'images.json').read_text()))
        values={'name':c['name'],'runtime':str(d),'podman_socket':engine_socket(),'ports':c['ports'],
                'images':images,'profile':c['profile'],'mode':c['mode'],'running':c.get('running',True)}
        private_json(d/'inputs.json',values)
        command+=['-var-file='+str(d/'inputs.json')]
    return run(command,env=env)


def build(c):
    tags={}
    for service in ['backend','frontend']:
        context=ROOT/service
        files=sorted(p for p in context.rglob('*') if p.is_file() and not any(x in p.parts for x in ['node_modules','.git']) and not p.name.startswith('.env') and p.name != '.DS_Store')
        digest=hashlib.sha256(b''.join(str(p.relative_to(context)).encode()+p.read_bytes() for p in files)).hexdigest()[:12]
        tag='localhost/'+c['name']+'-'+service+':'+digest
        run(['podman','build','--format','docker','-t',tag,str(context)])
        tags[service]=tag
    private_json(Path(c['runtime'])/'images.json',tags)


def provision(c):
    doctor(c)
    existing=output(['podman','ps','-a','--filter','name=^'+c['name']+'-','--format','{{.Names}}'])
    if existing and not (Path(c['runtime'])/'terraform.tfstate').exists():
        raise ValueError('Instance resources exist without local state; restore state or choose a different INSTANCE')
    tf(c,['apply']+(['-auto-approve'] if os.environ.get('AUTO_APPROVE')=='1' else []))
    env=os.environ.copy();env['TF_DATA_DIR']=str(Path(c['runtime'])/'terraform')
    metadata=json.loads(output_with_env(['terraform','-chdir='+str(ROOT/'infra'),'output','-json','metadata'],env))
    private_json(Path(c['runtime'])/'metadata.json',metadata)


def output_with_env(args,env):
    return run(args,env=env,capture_output=True,text=True).stdout


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command',choices=COMMANDS,nargs='?',default='help')
    args=parser.parse_args()
    if args.command=='help':
        print('Local Podman workshop: make '+' | '.join(COMMANDS[1:]))
        print('Overrides: INSTANCE, PREFIX, POSTGRES_PORT, VAULT_PORT, BACKEND_PORT, FRONTEND_PORT, PROFILE=starter|solution, MODE=required|baseline')
        return
    c=config()
    if args.command=='doctor':doctor(c)
    elif args.command=='init':initialize(c)
    elif args.command=='build':initialize(c);build(c)
    elif args.command=='plan':initialize(c);tf(c,['plan'])
    elif args.command=='infra':initialize(c);provision(c)
    elif args.command=='down':
        c['running']=False;tf(c,['apply']+(['-auto-approve'] if os.environ.get('AUTO_APPROVE')=='1' else []))
    elif args.command=='destroy':
        if os.environ.get('CONFIRM') != c['instance']:raise ValueError('Destructive action: set CONFIRM='+c['instance'])
        tf(c,['destroy','-auto-approve'])
    else:raise ValueError(f'{args.command}: implementation pending next prompt stage')

if __name__=='__main__':
    os.umask(0o077)
    try:main()
    except (ValueError,subprocess.CalledProcessError,OSError) as e:
        print('Lab error:',str(e),file=sys.stderr);sys.exit(1)
