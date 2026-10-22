"""Reject runtime paths and known local secrets in the Git index without printing them."""
import json
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parents[1]
paths = subprocess.check_output(['git', 'diff', '--cached', '--name-only', '--diff-filter=ACMR', '-z'], cwd=root).split(b'\0')
secrets = []
creds = root / 'runtime/config/default-creds.txt'
if creds.exists():
    secrets.append(json.loads(creds.read_text())['password'].encode())
key = root / '.secrets/restic-password'
if key.exists():
    secrets.append(key.read_bytes().strip())
for raw_path in filter(None, paths):
    path = raw_path.decode()
    assert not path.startswith(('runtime/', 'recovery/', '.secrets/', '.tools/')), 'Runtime path staged'
    assert path != '.env' and (not path.startswith('.env.') or path == '.env.example'), 'Local environment staged'
    data = subprocess.check_output(['git', 'show', ':' + path], cwd=root)
    assert all(not secret or secret not in data for secret in secrets), 'Known local secret staged'
    assert not re.search(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----', data), 'Private key staged'
    assert not re.search(rb'gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}', data), 'GitHub token staged'
print('Staged paths and known-secret checks passed. Review the diff as well.')
