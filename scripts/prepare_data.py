import gzip, re, json, math, hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[1]
freq={}
pos={}
for line in (root/'data/upstream/jieba.txt').read_text().splitlines():
    fields=line.split()
    if len(fields)>1:
        freq[fields[0]]=int(fields[1])
        pos[fields[0]]=fields[2] if len(fields)>2 else ''
entries={}
for line in gzip.open(root/'data/upstream/cedict.txt.gz','rt'):
    m=re.match(r'\S+ (\S+) \[([^]]+)\]',line)
    if not m: continue
    text,pin=m.groups()
    if not re.fullmatch(r'[\u3400-\u9fff]+',text) or len(text)>8: continue
    syllables=[re.sub(r'[0-5]','',p.lower()).replace('u:','v') for p in pin.split()]
    if not all(re.fullmatch(r'[a-zv]+',p) for p in syllables): continue
    if len(syllables)!=len(text): continue
    f=freq.get(text,0)
    if f<2 and len(text)>1: continue
    key=(text,' '.join(syllables))
    entries[key]=[text,' '.join(syllables),f,pos.get(text,'')]
rows=sorted(entries.values(),key=lambda r:-r[2])
(root/'data/chinese-lexicon.json').write_text(json.dumps(rows,ensure_ascii=False,separators=(',',':')))
words=sorted({re.sub(r'\(\d+\)$','',line.split()[0]).lower() for line in (root/'data/upstream/cmudict.dict').read_text().splitlines() if line and re.fullmatch(r'[a-z]+(?:\(\d+\))?',line.split()[0])})
(root/'data/english-lexicon.json').write_text(json.dumps(words,separators=(',',':')))
syllables=sorted({s for _,pin,_,_ in rows for s in pin.split()})
(root/'data/pinyin-syllables.json').write_text(json.dumps([{'canonical':s.replace('v','ü'),'keyboardAliases':[s],'sourceId':'cc-cedict','reviewStatus':'pending'} for s in syllables],ensure_ascii=False,indent=2))
(root/'data/abbreviations.json').write_text(json.dumps({'ai':'AI','api':'API','ui':'UI','ux':'UX','html':'HTML','css':'CSS','json':'JSON','gpt':'GPT','sql':'SQL','pdf':'PDF','ppt':'PPT','cpu':'CPU','gpu':'GPU','python':'Python','javascript':'JavaScript','typescript':'TypeScript'},indent=2))
source_specs=[('cc-cedict','cedict.txt.gz','https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.txt.gz','CC-BY-SA-4.0'),('jieba','jieba.txt','https://github.com/fxsjy/jieba','MIT'),('cmudict','cmudict.dict','https://github.com/cmusphinx/cmudict','BSD-style')]
sources=[]
for ident,file,url,license in source_specs:
    sources.append({'id':ident,'url':url,'license':license,'retrievedAt':'2026-10-09','file':'data/upstream/'+file,'sha256':hashlib.sha256((root/'data/upstream'/file).read_bytes()).hexdigest(),'reviewStatus':'source header checked; teaching review pending'})
sources.append({'id':'project-abbreviations','license':'project-authored factual labels','note':'常用技术缩写；不是英文词频或教学规范'})
(root/'docs/sources.json').write_text(json.dumps({'sources':sources,'counts':{'chinese':len(rows),'english':len(words),'syllables':len(syllables)},'transform':'CC-CEDICT 简体词及无调读音，筛选 jieba 频次≥2的多字词；单字保留。派生中文数据按 CC-BY-SA-4.0 提供。音节表是词库抽取的输入识别表，未经完整规范/教学审核。'},ensure_ascii=False,indent=2))
print(len(rows),'Chinese entries;',len(words),'English words;',len(syllables),'observed syllables')
