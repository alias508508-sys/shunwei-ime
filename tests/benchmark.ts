import {decode} from '../web/src/core/decoder';
import {writeFileSync} from 'node:fs';
const inputs=['aizidongdazi','woaini','jintiantianqihenhao','wo yong python xie daima','hello world','can','nihao','https://example.com/a','a@example.com','foo_bar','xi\u0027an','lǜ'];
const times:number[]=[];
for(let k=0;k<25;k++)for(const raw of inputs){const start=performance.now();decode({raw,sessionId:'bench',revision:k,mode:'auto',cursor:raw.length});if(k>0)times.push(performance.now()-start);}
times.sort((a,b)=>a-b);
const report={date:'2026-10-09',environment:process.version,platform:process.platform,arch:process.arch,samples:times.length,inputRange:'short development scenarios, not held-out accuracy set',p50Ms:times[Math.floor(times.length*.5)],p95Ms:times[Math.floor(times.length*.95)],maxMs:times.at(-1),coldStartup:'not included',model:'no neural model'};
writeFileSync('docs/performance.json',JSON.stringify(report,null,2));console.log(report);
