#!/usr/bin/env python3
"""Portable workshop entry point. Terraform owns infrastructure; Ansible configures it."""
import argparse
import contextlib
import hashlib
import fcntl
import http.client
import json
import os
from pathlib import Path
import platform
import re
import shutil
import secrets
import shlex
import socket
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
DEFAULTS = json.loads((ROOT / 'workshop/config.json').read_text())
COMMANDS = ['help','doctor','init','build','plan','infra','configure','seed','up','status','verify','test','down','destroy','reset','persona','test-browser']


def run(args, **kwargs):
    return subprocess.run([str(x) for x in args], check=True, **kwargs)


def output(args):
    return run(args, capture_output=True, text=True).stdout.strip()


def license_value():
    value=os.environ.get('VAULT_LICENSE','')
    if value:return value
    envfile=ROOT/'.env'
    if envfile.exists():
        match=re.search(r'^\s*(?:export\s+)?VAULT_LICENSE\s*=\s*(.*)$',envfile.read_text(),re.M)
        if match:
            try:parts=shlex.split(match.group(1),comments=True)
            except ValueError:raise ValueError('Invalid VAULT_LICENSE quoting in local .env') from None
            return parts[0] if len(parts)==1 else ''
    return ''


def config(environ=None):
    env = os.environ if environ is None else environ
    invariants={'database':'workshop','app_user':'workshop_app','vault_mount':'kv','vault_secret':'workshop/db'}
    if any(DEFAULTS.get(k)!=v for k,v in invariants.items()):raise ValueError('Core DB/Vault schema changes require updating the service contracts together')
    instance = env.get('INSTANCE', 'default')
    saved={}
    if environ is None:
        f=ROOT/'.workshop'/instance/'settings.json'
        if f.exists():saved=json.loads(f.read_text())
    prefix = env.get('PREFIX', saved.get('prefix', DEFAULTS['prefix']))
    if not re.fullmatch(r'[a-z][a-z0-9-]{0,24}', instance):
        raise ValueError('INSTANCE must be a lowercase name (maximum 25 characters)')
    if not re.fullmatch(r'hug-[a-z0-9-]{3,30}-', prefix):
        raise ValueError('PREFIX must be a unique hug-...- prefix')
    if instance in ['tools','tmp','browsers','browser-results','local-backup','ansible-home']:raise ValueError('Reserved INSTANCE name')
    if saved.get('prefix',prefix) != prefix:raise ValueError('An existing instance cannot change PREFIX; choose a new INSTANCE')
    edition = env.get('VAULT_EDITION', saved.get('edition','auto'))
    if edition not in ['auto','enterprise','community']:raise ValueError('VAULT_EDITION=auto|enterprise|community')
    licensed = bool(license_value()) if environ is None else bool(env.get('VAULT_LICENSE'))
    if edition == 'enterprise' and not licensed:raise ValueError('Enterprise requires a local VAULT_LICENSE')
    enterprise = edition == 'enterprise' or (edition == 'auto' and licensed)
    ports = {k: int(env.get(k.upper() + '_PORT', v)) for k,v in saved.get('ports',DEFAULTS['ports']).items()}
    if len(set(ports.values())) != 4 or any(not 1024 <= v <= 65535 for v in ports.values()):
        raise ValueError('Ports must be distinct integers between 1024 and 65535')
    profile = env.get('PROFILE', saved.get('profile','starter'))
    mode = env.get('MODE', saved.get('mode','required'))
    if profile not in ['starter','solution'] or mode not in ['required','baseline']:
        raise ValueError('PROFILE=starter|solution and MODE=required|baseline')
    return {**DEFAULTS, 'instance':instance, 'prefix':prefix, 'name':prefix+instance,
            'runtime':str(ROOT/'.workshop'/instance), 'ports':ports, 'profile':profile, 'mode':mode, 'enterprise':enterprise,'edition':edition}


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
    tool_python()
    info=json.loads(output(['podman','info','--format','json']))
    print('Python',platform.python_version(),'Podman',info['version']['Version'],info['host']['arch'])
    tf_version=json.loads(output(['terraform','version','-json']))['terraform_version']
    if not ( (1,6) <= tuple(int(x) for x in tf_version.split('.')[:2]) < (2,0) ):raise ValueError('Terraform >=1.6,<2 is required')
    if 'GNU Make' not in output(['make','--version']):raise ValueError('GNU Make is required')
    print('Terraform',tf_version)
    sock=engine_socket()
    if not sock.startswith('unix://'):raise ValueError('Use a local/forwarded Podman Unix API socket')
    if not Path(sock.removeprefix('unix://')).is_socket():
        raise ValueError('Podman API socket is unavailable; see docs/SETUP.md')
    connection=UnixConnection(sock.removeprefix('unix://'))
    try:
        connection.request('GET','/version');version=json.loads(connection.getresponse().read())
        if not any(x.get('Name')=='Podman Engine' for x in version.get('Components',[])):raise ValueError('PODMAN_SOCKET must address Podman, not Docker')
    finally:connection.close()
    owned=output(['podman','ps','-a','--filter','label=workshop.instance='+c['name'],'--format','{{.Names}}']).splitlines()
    for service,port in c['ports'].items():
        if c['name']+'-'+service in owned:
            mapping=output(['podman','port',c['name']+'-'+service])
            if any(line.endswith(':'+str(port)) for line in mapping.splitlines()):continue
        with socket.socket() as s:
            s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
            try:s.bind(('127.0.0.1',port))
            except OSError:raise ValueError(f'{service} port {port} is occupied; override {service.upper()}_PORT') from None
    print('Instance:',c['name'],'API:',sock,'ports:',c['ports'])


def private_json(path, value):
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
    path.write_text(json.dumps(value,indent=2)+'\n');path.chmod(0o600)


def initialize(c):
    d=Path(c['runtime'])
    if d.is_symlink():raise ValueError('Instance runtime may not be a symlink')
    d.mkdir(parents=True,exist_ok=True,mode=0o700);d.chmod(0o700)
    private_json(d/'settings.json',{k:c[k] for k in ['prefix','ports','profile','mode','edition']})
    for name in ['postgres','vault','bootstrap','app']:
        (d/name).mkdir(exist_ok=True,mode=0o700)
    for name in ['postgres/admin-password','vault/root-token']:
        f=d/name
        if not f.exists():f.write_text(secrets.token_hex(24));f.chmod(0o600)
    f=d/'bootstrap/secrets.json'
    if not f.exists():
        private_json(f,{'app_password':secrets.token_hex(24),'users':{u['name']:secrets.token_hex(16) for u in json.loads((ROOT/'workshop/users.yml').read_text())['users']}})
    if c['enterprise']:
        f=d/'vault/vault.hclic';f.write_text(license_value());f.chmod(0o600)
    if not (d/'app/config.json').exists():private_json(d/'app/config.json',{})
    if not (d/'images.json').exists():private_json(d/'images.json',{'backend':'localhost/'+c['name']+'-backend:pending','frontend':'localhost/'+c['name']+'-frontend:pending'})
    tf(c,['init','-input=false','-reconfigure','-backend-config=path='+str(d/'terraform.tfstate')],variables=False)
    ensure_tools()


def tf(c,args,variables=True):
    d=Path(c['runtime']);env=os.environ.copy();env['TF_DATA_DIR']=str(d/'terraform')
    env['TF_IN_AUTOMATION']='1'
    command=['terraform','-chdir='+str(ROOT/'infra'),*args]
    if variables:
        images={k:v for k,v in c['images'].items() if k != 'node'}
        if c['enterprise']:images['vault']=c['enterprise_image']
        images.update(json.loads((d/'images.json').read_text()))
        values={'name':c['name'],'runtime':str(d),'podman_socket':engine_socket(),'ports':c['ports'],
                'images':images,'profile':c['profile'],'mode':c['mode'],'running':c.get('running',True),'enterprise':c['enterprise']}
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


def tool_python():
    for executable in [os.environ.get('TOOLS_PYTHON'),shutil.which('python3.13'),shutil.which('python3.14'),shutil.which('python3.12'),sys.executable]:
        if executable:
            version=json.loads(output([executable,'-c','import sys,json; print(json.dumps(list(sys.version_info[:2])))']))
            if [3,12] <= version < [3,15]:return executable
    raise ValueError('Install Python 3.12–3.14 for pinned Ansible; set TOOLS_PYTHON if needed')


def ensure_tools():
    tools=ROOT/'.workshop/tools'
    python=tools/'bin/python'
    requirement=ROOT/'ansible/requirements.txt'
    marker=tools/'requirements.sha256'
    digest=hashlib.sha256(requirement.read_bytes()).hexdigest()
    if not python.exists():
        run([tool_python(),'-m','venv',str(tools)])
    if not marker.exists() or marker.read_text()!=digest:
        run([str(python),'-m','pip','install','--disable-pip-version-check','-r',str(requirement)])
        marker.write_text(digest)
    return tools


def ansible(c,playbook):
    tools=ensure_tools();python=tools/'bin/python'
    env=os.environ.copy();env['ANSIBLE_HOME']=str(ROOT/'.workshop/ansible-home')
    env['ANSIBLE_LOCAL_TEMP']=str(ROOT/'.workshop/tmp');env['ANSIBLE_NOCOLOR']='1'
    args=[str(tools/'bin/ansible-playbook'),'-i',str(ROOT/'ansible/inventory.yml'),str(ROOT/'ansible'/playbook),
          '-e',json.dumps({'runtime':c['runtime'],'ansible_python_interpreter':str(python)})]
    run(args,env=env)


class UnixConnection(http.client.HTTPConnection):
    def __init__(self,path):
        super().__init__('localhost',timeout=5);self.path=path
    def connect(self):
        self.sock=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM);self.sock.settimeout(5);self.sock.connect(self.path)


@contextlib.contextmanager
def operation_lock():
    d=ROOT/'.workshop';d.mkdir(exist_ok=True,mode=0o700)
    with (d/'operation.lock').open('a') as handle:
        try:fcntl.flock(handle,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:raise ValueError('Another workshop operation is running; retry when it finishes') from None
        try:yield
        finally:fcntl.flock(handle,fcntl.LOCK_UN)


def ensure_scope(c):
    d=Path(c['runtime'])
    if d.is_symlink():raise ValueError('Refusing symlinked runtime directory')
    state=d/'terraform.tfstate'
    if not state.exists():raise ValueError('No instance state; restore its state before teardown')
    resources=json.loads(state.read_text()).get('resources',[])
    for resource in resources:
        if resource['mode'] != 'managed':continue
        if resource['type'] not in ['docker_image','docker_container','docker_volume','docker_network']:
            raise ValueError('Unexpected resource type in instance state; teardown refused')
        for instance in resource.get('instances',[]):
            values=instance['attributes']
            if resource['type']=='docker_image':
                if not values.get('keep_locally'):raise ValueError('Teardown may not remove shared base images')
                continue
            labels={x['label']:x['value'] for x in values.get('labels',[])}
            if not values.get('name','').startswith(c['name']+'-') or labels.get('workshop.instance')!=c['name']:
                raise ValueError('State resource ownership mismatch; teardown refused')


def confirm(c):
    if os.environ.get('CONFIRM')!=c['instance']:
        raise ValueError('Destructive action: set CONFIRM='+c['instance'])


def destroy(c):
    ensure_scope(c)
    print('Destroying only Terraform resources for',c['name'])
    tf(c,['destroy','-auto-approve'])


def status(c):
    from verify import request
    path=Path(c['runtime'])/'metadata.json'
    if not path.exists():raise ValueError('No deployed instance; run make up first')
    meta=json.loads(path.read_text());code,data=request(meta['urls']['backend'],'/health')
    print('Instance:',meta['name'],'Viewer:',meta['urls']['frontend'])
    print(json.dumps({k:data.get(k) for k in ['dbReady','mode','channel','unlocked','state']}))
    if code!=200:raise ValueError('API is unavailable')


def persona(c):
    from verify import request
    user=os.environ.get('USER_NAME','albert');action=os.environ.get('ACTION','read')
    if user not in ['albert','brenda','charlie'] or action not in ['read','write','admin']:raise ValueError('USER_NAME=albert|brenda|charlie, ACTION=read|write|admin')
    d=Path(c['runtime']);base=json.loads((d/'metadata.json').read_text())['urls']['vault']
    credentials=json.loads((d/'bootstrap/secrets.json').read_text())
    code,result=request(base,'/v1/auth/userpass/login/'+user,'POST',{'password':credentials['users'][user]})
    if code!=200:raise ValueError('Persona authentication failed')
    token=result['auth']['client_token']
    try:
        if action=='read':code,_=request(base,'/v1/kv/data/workshop/db',token=token)
        elif action=='write':code,_=request(base,'/v1/kv/data/workshop/db','POST',{'data':{'username':'workshop_app','password':credentials['app_password']}},token)
        else:code,_=request(base,'/v1/sys/mounts',token=token)
        print(user+': authenticated; '+action+': '+('allowed' if code==200 else 'denied' if code==403 else 'unavailable'))
        if code not in [200,403]:raise ValueError('Unexpected Vault response')
    finally:request(base,'/v1/auth/token/revoke-self','POST',token=token)


def browser_test(c):
    run(['npm','ci','--no-audit','--no-fund'],cwd=ROOT/'tests/browser')
    env=os.environ.copy();env['PLAYWRIGHT_BROWSERS_PATH']=str(ROOT/'.workshop/browsers')
    meta=json.loads((Path(c['runtime'])/'metadata.json').read_text());env['WORKSHOP_FRONTEND']=meta['urls']['frontend']
    run(['npx','playwright','install','chromium'],cwd=ROOT/'tests/browser',env=env)
    run(['npm','test'],cwd=ROOT/'tests/browser',env=env)


def execute(command,c):
    if command=='init':initialize(c)
    elif command=='build':initialize(c);build(c)
    elif command=='plan':initialize(c);tf(c,['plan'])
    elif command=='infra':initialize(c);provision(c)
    elif command=='configure':ansible(c,'configure.yml')
    elif command=='seed':ansible(c,'seed.yml')
    elif command=='up':
        doctor(c);initialize(c);build(c);provision(c);ansible(c,'configure.yml');ansible(c,'seed.yml')
    elif command=='status':status(c)
    elif command=='persona':persona(c)
    elif command=='verify':run([sys.executable,ROOT/'scripts/verify.py',c['runtime']])
    elif command=='test':
        run([sys.executable,'-m','unittest','discover','-s',str(ROOT/'tests'),'-v'])
        tags=json.loads((Path(c['runtime'])/'images.json').read_text())
        run(['podman','run','--rm','--name',c['name']+'-tests','--label','workshop.instance='+c['name'],'--network','none',tags['backend'],'npm','test'])
    elif command=='test-browser':browser_test(c)
    elif command=='down':
        ensure_scope(c);c['running']=False
        tf(c,['apply']+(['-auto-approve'] if os.environ.get('AUTO_APPROVE')=='1' else []))
    elif command=='destroy':confirm(c);destroy(c)
    elif command=='reset':
        confirm(c);destroy(c);shutil.rmtree(c['runtime']);initialize(c);build(c);provision(c);ansible(c,'configure.yml');ansible(c,'seed.yml')


def main():
    os.chdir(ROOT)
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command',choices=COMMANDS,nargs='?',default='help')
    args=parser.parse_args()
    if args.command=='help':
        print('Local Podman workshop: make '+' | '.join(COMMANDS[1:]))
        print('Overrides: INSTANCE, PREFIX, *_PORT, PROFILE=starter|solution, MODE=required|baseline, VAULT_EDITION=auto|community|enterprise')
        print('Defaults persist per instance. Destruction requires CONFIRM=<instance>. See docs/SETUP.md.')
        return
    c=config()
    if args.command=='doctor':doctor(c)
    elif args.command=='status':status(c)
    else:
        with operation_lock():execute(args.command,c)

if __name__=='__main__':
    os.umask(0o077)
    try:main()
    except (ValueError,RuntimeError,subprocess.CalledProcessError,OSError) as e:
        print('Lab error:',str(e),file=sys.stderr);sys.exit(1)
