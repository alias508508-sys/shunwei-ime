import {writeFileSync} from 'node:fs';
import {decode} from '../web/src/core/decoder';
const raws=['aizidongdazi','woaini','nihao',"xi'an",'lǜ','lu:','lu\u0308\u0300','hello world','can','a@example.com','foo_bar','中文🙂abc','wo yong python xie daima'];
const rows=raws.map(raw=>({raw,candidates:decode({raw,sessionId:'fixture',revision:1,mode:'auto',cursor:raw.length}).candidates.map(c=>c.text)}));
writeFileSync('macos/build/fixtures.json',JSON.stringify(rows));
