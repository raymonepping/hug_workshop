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
    else:raise ValueError(f'{args.command}: implementation pending next prompt stage')

if __name__=='__main__':
    try:main()
    except (ValueError,subprocess.CalledProcessError,OSError) as e:
        print('Lab error:',str(e),file=sys.stderr);sys.exit(1)
