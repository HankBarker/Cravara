"""Aggregate every currently configured forest regression plus rendered wardrobe QA."""
from pathlib import Path
import json,re
root=Path(__file__).resolve().parents[1]
names=re.findall(r"Name='([^']+)'",(root/'tools/verify_forest.ps1').read_text(encoding='utf-8-sig'))
paths=[(n,root/'art/forest-playtest'/f'suite-{n}.log') for n in names]
paths.append(('wardrobe-world-pass7',root/'art/character-pass7/world-render.log'))
rows=[]
for name,path in paths:
    text=path.read_text(encoding='utf-8-sig') if path.exists() else ''
    passed=bool(re.search(r'FOREST_WORLD_TEST_PASS|failures=0|0 failures',text)) and not re.search(r'(?m)^(SCRIPT ERROR|ERROR):',text)
    rows.append({'suite':name,'passed':passed,'log':str(path.relative_to(root))})
(root/'art/character-pass7/suite-results.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
print(f'{len(rows)} suites; {sum(x["passed"] for x in rows)} passed')
for row in rows:
    if not row['passed']:print('FAILED:',row['suite'])
raise SystemExit(0 if all(x['passed'] for x in rows) else 1)
