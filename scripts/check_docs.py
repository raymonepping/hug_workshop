#!/usr/bin/env python3
"""Check local Markdown links/anchors without contacting external article sites."""
from pathlib import Path
import re
import sys
ROOT=Path(__file__).resolve().parents[1]
count=0;errors=[]
for p in [ROOT/'README.md',*ROOT.glob('docs/**/*.md'),*ROOT.glob('prompts/*.md')]:
    for _,link in re.findall(r'\[([^\]]*)\]\(([^)]+)\)',p.read_text()):
        if link.startswith(('http:','https:','mailto:')):continue
        path,_,anchor=link.partition('#');target=p.parent/path if path else p
        count+=1
        if not target.exists():errors.append(f'{p.relative_to(ROOT)}: missing {link}')
        elif anchor and target.suffix=='.md':
            headings=[re.sub(r'[^\w\- ]','',re.sub(r'^#+\s*','',line).strip().lower()).replace(' ','-') for line in target.read_text().splitlines() if line.startswith('#')]
            if anchor not in headings:errors.append(f'{p.relative_to(ROOT)}: missing anchor {link}')
for error in errors:print(error,file=sys.stderr)
print(f'Local Markdown links checked: {count}; errors: {len(errors)}')
sys.exit(bool(errors))
