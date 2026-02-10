import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
demo_dir = root / 'flows' / 'demo'
print('cwd:', Path.cwd())
print('repo root:', root)
print('demo dir:', demo_dir)
if not demo_dir.exists():
    print('DEMO DIR MISSING')
    sys.exit(1)
flows = sorted([p for p in demo_dir.glob('IDCEVODEV-*.yaml')])
print('found flows:', len(flows))
for p in flows:
    rel = p.relative_to(root)
    resolved = (root / rel).resolve()
    print(p.name, '->', rel, 'exists?', resolved.exists())

sys.exit(0)
