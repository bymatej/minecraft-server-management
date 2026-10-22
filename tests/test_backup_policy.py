"""Exercise real restic retention/restore on synthetic data, never live worlds."""
import datetime
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
RESTIC = ROOT / '.tools/restic'


@unittest.skipUnless(RESTIC.exists(), 'Install the pinned restic binary first')
class BackupPolicyTests(unittest.TestCase):
    def test_rotation_restore_and_separate_baseline(self):
        with tempfile.TemporaryDirectory(prefix='minecraft-backup-test-') as tmp:
            root = Path(tmp)
            source = root / 'fixture'
            source.mkdir()
            (source / 'world.txt').write_text('synthetic known-good world\n')
            key = root / 'password'
            key.write_text('test-only-nonproduction-password')
            key.chmod(0o600)
            normal, baseline = root / 'normal', root / 'baseline'
            env = dict(os.environ, RESTIC_PASSWORD_FILE=str(key))

            def run(repo, *args):
                result = subprocess.run([str(RESTIC), '-r', str(repo), *args],
                                        cwd=root, env=env, check=True,
                                        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                        text=True)
                return result.stdout

            run(normal, 'init')
            run(baseline, 'init')
            run(baseline, 'backup', '--tag', 'baseline', 'fixture')
            protected = run(baseline, 'snapshots', '--json')
            today = datetime.date.today()
            # Daily samples plus weekly/monthly history, all with identical content.
            for days in sorted(set(list(range(11)) + [14, 21, 28, 35, 60, 90, 120]), reverse=True):
                timestamp = str(today - datetime.timedelta(days=days)) + ' 12:00:00'
                run(normal, 'backup', '--tag', 'rotation', '--time', timestamp, 'fixture')
            before = json.loads(run(normal, 'snapshots', '--json'))
            policy = ('forget', '--tag', 'rotation', '--group-by', 'host,paths,tags',
                      '--keep-daily', '7', '--keep-weekly', '4', '--keep-monthly', '3')
            run(normal, *policy, '--dry-run')
            self.assertEqual(before, json.loads(run(normal, 'snapshots', '--json')))
            run(normal, *policy, '--prune')
            after = json.loads(run(normal, 'snapshots', '--json'))
            self.assertLess(len(after), len(before))
            self.assertGreaterEqual(len(after), 7)
            self.assertEqual(protected, run(baseline, 'snapshots', '--json'))
            run(normal, 'check', '--read-data')
            run(baseline, 'check', '--read-data')
            restored = root / 'restored'
            run(normal, 'restore', 'latest', '--target', str(restored), '--verify')
            self.assertEqual((restored / 'fixture/world.txt').read_bytes(),
                             (source / 'world.txt').read_bytes())
            run(baseline, 'restore', 'latest', '--target', str(root / 'restored-baseline'), '--verify')
            self.assertEqual((root / 'restored-baseline/fixture/world.txt').read_bytes(),
                             (source / 'world.txt').read_bytes())


if __name__ == '__main__':
    unittest.main()
