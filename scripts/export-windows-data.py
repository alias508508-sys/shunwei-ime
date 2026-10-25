import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
out=root/'windows/build/data';out.mkdir(parents=True,exist_ok=True)
rows=json.loads((root/'data/chinese-lexicon.json').read_text())
(out/'chinese.tsv').write_text(''.join(f'{text}\t{pin}\t{freq}\t{pos}\n' for text,pin,freq,pos in rows))
(out/'english.txt').write_text('\n'.join(json.loads((root/'data/english-lexicon.json').read_text()))+'\n')
(out/'abbreviations.tsv').write_text(''.join(f'{key}\t{value}\n' for key,value in json.loads((root/'data/abbreviations.json').read_text()).items()))
print('Exported Windows dictionaries',len(rows))
