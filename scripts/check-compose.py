"""Validate the resolved security boundary, including local .env overrides."""
import json
import sys

c = json.load(sys.stdin)
assert list(c['services']) == ['crafty'], 'Only Crafty belongs in this stack'
s = c['services']['crafty']
assert not s.get('privileged', False)
assert s.get('network_mode') != 'host'
assert 'latest' not in s['image'] and ':4.' in s['image'], 'Pin a stable Crafty tag'
assert 'ALL' in s['cap_drop']
assert 'KILL' in s['cap_add'], 'sudo must forward SIGTERM across UIDs'
assert not s.get('user'), 'Preserve upstream user handling'
assert s['environment']['TZ'] == 'Europe/Zagreb'
expected = {'/crafty/backups', '/crafty/logs', '/crafty/servers', '/crafty/app/config', '/crafty/import'}
assert {v['target'] for v in s['volumes']} == expected
assert all(v['type'] == 'bind' and 'docker.sock' not in v['source'] for v in s['volumes'])
ports = s['ports']
assert len(ports) <= 4
assert all(p['protocol'] == 'tcp' for p in ports)
panel = [p for p in ports if p['target'] == 8443]
assert len(panel) == 1 and panel[0]['host_ip'] == '127.0.0.1'
assert len({(p['host_ip'], p['published']) for p in ports}) == len(ports)
for p in ports:
    if p['target'] != 8443:
        assert int(p['published']) == p['target'], 'Match Crafty listener and host port'
print('Resolved Compose security checks passed.')
