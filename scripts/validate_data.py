import json, hashlib, re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'docs/sources.json').read_text())
for source in manifest['sources']:
    if 'file' in source: assert hashlib.sha256((root/source['file']).read_bytes()).hexdigest()==source['sha256'],source['id']
rows=json.loads((root/'data/chinese-lexicon.json').read_text())
seen=set()
for text,pin,freq,pos in rows:
    assert re.fullmatch(r'[\u3400-\u9fff]+',text)
    assert re.fullmatch(r'[a-zv]+(?: [a-zv]+)*',pin)
    assert len(pin.split())==len(text)
    assert freq>=0
    assert (text,pin) not in seen
    seen.add((text,pin))
print(f'Validated {len(rows)} Chinese entries and {len(manifest["sources"])} sources; teaching review remains pending.')
