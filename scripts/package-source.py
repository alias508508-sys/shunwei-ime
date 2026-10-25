"""Package tracked source only; never includes toolchains, credentials or build outputs."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile

root=Path(__file__).resolve().parents[1]
version=json.loads((root/'package.json').read_text())['version']
files=[Path(p.decode()) for p in subprocess.check_output(['git','ls-files','-z'],cwd=root).split(b'\0') if p]
for path in files:
    p=root/path
    if p.stat().st_size>20_000_000:raise ValueError(f'Oversized source file: {path}')
    if any(part in {'.tools','node_modules','.git','releases'} for part in path.parts):raise ValueError(f'Excluded path tracked: {path}')
    if p.suffix in {'.ts','.js','.cpp','.hpp','.swift','.md','.json','.yml','.sh','.command','.py'}:
        if re.search(r'(?:gh[opusr]_|sk-)[A-Za-z0-9_]{25,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',p.read_text(errors='ignore')):
            raise ValueError(f'Credential-like content in {path}')
out=root/'releases';out.mkdir(exist_ok=True)
archive=out/f'Shunwei-{version}-GitHub-source.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
    for path in files:z.write(root/path,'shunwei-ime/'+path.as_posix())
with zipfile.ZipFile(archive) as z:assert z.testzip() is None
lines=[]
for p in sorted(out.glob(f'Shunwei-{version}-*')):
    if p.suffix in {'.dmg','.exe','.zip'}:lines.append(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}')
(out/'SHA256SUMS.txt').write_text('\n'.join(lines)+'\n')
print(f'Packaged {len(files)} source files; checksum manifest written.')
