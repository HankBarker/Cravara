from pathlib import Path
import json
import re

root=Path(__file__).resolve().parents[1]
source=(root/'tools/verify_forest.ps1').read_text(encoding='utf-8-sig')
names=re.findall(r"Name='([^']+)'",source)
rows=[]
for name in names:
    path=root/'art/forest-playtest'/f'suite-{name}.log'
    text=path.read_text(encoding='utf-8-sig') if path.exists() else ''
    passed=bool(re.search(r'(FOREST_WORLD_TEST_PASS|failures=0|0 failures)',text)) and not re.search(r'(?m)^(SCRIPT ERROR|ERROR):',text)
    rows.append({'suite':name,'passed':passed,'log':str(path.relative_to(root))})
(root/'art/forest-pass6/suite-results.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
print(f'{len(rows)} suites; {sum(row["passed"] for row in rows)} passed')
for row in rows:
    if not row['passed']: print('FAILED:',row['suite'])
raise SystemExit(0 if all(row['passed'] for row in rows) else 1)
