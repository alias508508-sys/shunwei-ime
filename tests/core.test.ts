import test from 'node:test';
import assert from 'node:assert/strict';
import {decode} from '../web/src/core/decoder';
import {normalize} from '../web/src/core/normalizer';
import {Session} from '../web/src/core/session';
const run=(raw:string,context='')=>decode({raw,context,sessionId:'test',revision:1,cursor:raw.length,mode:'auto'});
for(const [raw,wanted,context] of [['aizidongdazi','AI 自动打字','讨论 AI 工具'],['woaini','我爱你',''],['nihao','你好',''],['jintiantianqihenhao','今天天气很好',''],['woxiedaima','我写代码',''],['wo yong python xie daima','我用 Python 写代码','']] as const) {
 test(`general decoding: ${raw}`,()=>assert.ok(run(raw,context).candidates.slice(0,3).some(c=>c.text===wanted),run(raw,context).candidates.map(c=>c.text).join(' | ')));
}
for(const raw of ['https://example.com/a','a@example.com','foo_bar','v1.2.3','/Users/example/test.txt','C:\\Users\\test.txt','hello world','unknownzzq','中文🙂abc','zh','aizidongdazi.'])test(`raw preservation and complete offsets: ${raw}`,()=>{const result=run(raw);assert.equal(result.rawFallback,raw);assert.ok(result.candidates.some(c=>c.id==='raw'&&c.text===raw));for(const c of result.candidates){let pos=0;for(const s of c.segments){assert.equal(s.start,pos);assert.ok(s.end>s.start);pos=s.end;}assert.equal(pos,raw.length);}});
for(const raw of ['https://example.com/a','a@example.com','foo_bar','v1.2.3','/Users/example/test.txt','C:\\Users\\test.txt'])test(`protected raw: ${raw}`,()=>assert.deepEqual(run(raw).candidates.map(c=>c.text),[raw]));
for(const raw of ['can','an','shi','ai'])test(`ambiguity retains raw and Chinese: ${raw}`,()=>{assert.ok(run(raw).candidates.some(c=>c.id==='raw'));assert.ok(run(raw).candidates.some(c=>c.segments.some(s=>s.kind==='pinyin')));});
test('AI and 爱 are both represented',()=>{const r=run('aizidongdazi','AI 工具');assert.ok(r.candidates.some(c=>c.text==='爱自动打字'));});
test('explicit apostrophe preserves syllable boundary',()=>{assert.ok(run("xi'an").candidates.some(c=>c.text==='西安'));assert.ok(!run("xi'an").candidates.some(c=>c.text==='先'));});
test('accent spans and ü',()=>{assert.equal(normalize('lǜ').text,'lv');assert.equal(normalize('lu\u0308\u0300').text,'lv');assert.ok(run('lǜ').candidates.some(c=>c.text==='绿'));});
test('English lock and long strings return original',()=>{assert.equal(decode({...new Session('english').request(),raw:'woaini'}).candidates[0].text,'woaini');assert.equal(run('a'.repeat(400)).candidates[0].text,'a'.repeat(400));});
test('user dictionary participates in general decoding',()=>{const r=decode({sessionId:'x',revision:1,raw:'shunwei',cursor:7,mode:'auto'},[{text:'顺位',pinyin:'shun wei'}]);assert.equal(r.candidates[0].text,'顺位');});
test('stale, cross-session, frozen and deactivated results rejected',()=>{const s=new Session();const old=s.update('wo');s.update('woai');assert.equal(s.accept(old),false);assert.equal(s.accept({...s.result,sessionId:'other'}),false);s.navigate(1);assert.equal(s.accept(s.result),false);s.update('nihao');s.invalidate();assert.equal(s.accept(s.result),false);});
test('independent clients have no shared state',()=>{const a=new Session(),b=new Session();a.update('wo');b.update('hello');a.invalidate();assert.equal(b.raw,'hello');assert.equal(b.active,true);});
test('many generated unknown and unicode strings retain complete coverage',()=>{
  let seed=19;
  const chars=['a','z','q','x','ü','🙂','中',' ','\n',"'",'.','0','é'];
  for(let n=0;n<100;n++){
    let raw='';for(let j=0;j<12;j++){seed=(seed*1664525+1013904223)>>>0;raw+=chars[seed%chars.length];}
    const r=run(raw);assert.equal(r.rawFallback,raw);
    for(const c of r.candidates){let end=0;for(const s of c.segments){assert.equal(s.start,end);assert.ok(s.end>s.start);end=s.end;}assert.equal(end,raw.length);}
  }
});

test('keyboard u: alias maps to ü and preserves original offsets',()=>{assert.equal(normalize('lu:').text,'lv');const result=run('lu:');assert.ok(result.candidates.some(c=>c.text==='绿'));for(const c of result.candidates)assert.equal(c.segments.at(-1)?.end,3);});

test('empty composition has no phantom candidate',()=>assert.deepEqual(run('').candidates,[]));
