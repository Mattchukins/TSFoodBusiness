"""Package/schema SQL contracts; does not execute MySQL or prove persistence."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
files = sorted(p.name for p in (root / 'sql').glob('*.sql'))
assert files == ['install.sql', 'uninstall.sql'], files
install = (root / 'sql/install.sql').read_text()
uninstall = (root / 'sql/uninstall.sql').read_text()
created = re.findall(r'CREATE TABLE IF NOT EXISTS (tsfb_\w+)', install)
dropped = re.findall(r'DROP TABLE IF EXISTS (tsfb_\w+)', uninstall)
assert len(created) == 8 and set(created) == set(dropped)
assert len(dropped) == len(set(dropped))
assert install.count('ENGINE=InnoDB') == len(created)
assert not re.search(r'^\s*(DROP|TRUNCATE|DELETE)\b', install, re.MULTILINE)
assert 'FOREIGN_KEY_CHECKS' not in uninstall
for child, parent in [('tsfb_production_profiles', 'tsfb_recipes'), ('tsfb_recipes', 'tsfb_businesses'),
                      ('tsfb_suppliers', 'tsfb_businesses'), ('tsfb_stations', 'tsfb_businesses'),
                      ('tsfb_operations', 'tsfb_businesses')]:
    assert created.index(parent) < created.index(child)
    assert dropped.index(child) < dropped.index(parent)
assert install.rfind('INSERT IGNORE') > install.rfind('CREATE TABLE')
assert 'VALUES (1), (2), (3), (4), (5)' in install
print('Two-file SQL package and dependency-order contracts passed (no live SQL execution)')
