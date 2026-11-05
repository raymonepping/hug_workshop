#!/usr/bin/env python3
"""Transactional PostgreSQL configuration/seed helper invoked by Ansible."""
import csv
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]


def sql(name, statement):
    p=subprocess.run(['podman','exec','-i',name+'-postgres','psql','-X','-qAt','-v','ON_ERROR_STOP=1','-U','postgres','-d','workshop'],input=statement,text=True,capture_output=True)
    if p.returncode:
        raise RuntimeError('Database operation failed (details suppressed to protect credentials)')
    return p.stdout.strip()


def main():
    action,runtime,name=sys.argv[1:]
    if not re.fullmatch(r'hug-[a-z0-9-]+',name):raise ValueError('Invalid lab name')
    if action=='configure':
        password=json.loads((Path(runtime)/'bootstrap/secrets.json').read_text())['app_password']
        if not re.fullmatch('[a-f0-9]{48}',password):raise ValueError('Invalid generated credential')
        fingerprint=hashlib.sha256(password.encode()).hexdigest()
        before=sql(name,"SELECT count(*) FROM pg_roles WHERE rolname='workshop_app';")
        # Server-owned marker tracks intentional credential version, not only a local file.
        sql(name,"CREATE TABLE IF NOT EXISTS workshop_configuration (key text PRIMARY KEY, value text NOT NULL);")
        saved=sql(name,"SELECT value FROM workshop_configuration WHERE key='app_password_fingerprint';")
        grants=sql(name,"SELECT count(*) FROM information_schema.role_table_grants WHERE grantee='workshop_app' AND table_name='messages' AND privilege_type='SELECT';")
        changed=before!='1' or saved!=fingerprint or grants!='1'
        statement="BEGIN; REVOKE CREATE ON SCHEMA public FROM PUBLIC; REVOKE ALL ON DATABASE workshop FROM PUBLIC; CREATE TABLE IF NOT EXISTS messages(id integer PRIMARY KEY, idx integer UNIQUE NOT NULL, title text NOT NULL); "
        if before!='1':statement+="CREATE ROLE workshop_app LOGIN; "
        if saved!=fingerprint or before!='1':statement+=f"ALTER ROLE workshop_app PASSWORD '{password}'; "
        statement+="ALTER ROLE workshop_app NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION; REVOKE ALL ON ALL TABLES IN SCHEMA public FROM workshop_app; GRANT CONNECT ON DATABASE workshop TO workshop_app; GRANT USAGE ON SCHEMA public TO workshop_app; GRANT SELECT ON messages TO workshop_app; "
        statement+=f"INSERT INTO workshop_configuration VALUES ('app_password_fingerprint','{fingerprint}') ON CONFLICT(key) DO UPDATE SET value=EXCLUDED.value; COMMIT;"
        sql(name,statement)
    elif action=='seed':
        rows=[json.loads(x) for x in (ROOT/'workshop/dataset.jsonl').read_text().splitlines()]
        expected='\n'.join(f"{r['id']}|{r['idx']}|{r['title']}" for r in rows)
        actual=sql(name,'SELECT id,idx,title FROM messages ORDER BY idx,id;')
        changed=actual!=expected
        if changed:
            data=io.StringIO();writer=csv.writer(data,lineterminator='\n')
            for row in rows:writer.writerow([row['id'],row['idx'],row['title']])
            sql(name,'BEGIN; TRUNCATE messages; COPY messages(id,idx,title) FROM STDIN WITH (FORMAT csv);\n'+data.getvalue()+'\\.\nCOMMIT;')
    else:raise ValueError('Unknown database action')
    print(json.dumps({'changed':changed}))

if __name__=='__main__':
    try:main()
    except Exception:
        print('Database helper failed; inspect service readiness and private configuration.',file=sys.stderr);sys.exit(1)
