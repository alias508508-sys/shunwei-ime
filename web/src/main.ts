import './style.css';
import {Session} from './core/session';
import {decode} from './core/decoder';
import type {Candidate,InputMode,UserEntry} from './core/types';
const app=document.querySelector<HTMLDivElement>('#app')!;
app.innerHTML=`
<header><a class="brand" href="#">顺位<span>SHUNWEI</span></a><span class="local">本地识别 · 内容不上传</span></header>
<main><section class="intro"><p class="eyebrow">中英文，顺着写。</p><h1>把注意力留给你想说的话。</h1><p>直接输入拼音、英文或两者的组合，选择合适的表达。</p></section>
<div class="workspace"><section class="desk">
<div class="tabs" role="tablist" aria-label="体验方式"><button id="live-tab" role="tab" aria-selected="true">逐键输入</button><button id="repair-tab" role="tab" aria-selected="false">修复误输拼音</button></div>
<div class="toolbar"><label>识别方式 <select id="mode"><option value="auto">自动混输</option><option value="english">英文锁定</option><option value="chinese" selected>拼音（中文优先）</option></select></label><button id="undo" class="text-button" disabled>撤销上次提交</button></div>
<div id="live-pane"><label class="field-label" for="editor">你的文字</label><textarea id="editor" placeholder="点击这里，试着输入 aizidongdazi" spellcheck="false" aria-describedby="live-help"></textarea><p id="live-help" class="hint">使用系统英文键盘体验。空格选词，Return 保留原文，Esc 取消组合。</p></div>
<div id="repair-pane" hidden><label class="field-label" for="repair">误打成英文的拼音</label><textarea id="repair" spellcheck="false" placeholder="把误输内容粘贴到这里，例如 wo yong python xie daima"></textarea><div class="repair-actions"><button id="analyze" class="primary">识别这段文字</button><span class="hint">只分析你主动输入的内容。</span></div><label class="field-label" for="repair-output">选定的结果</label><textarea id="repair-output" readonly placeholder="选择下方候选后，结果会出现在这里。"></textarea></div>
<div class="candidate-heading"><span id="status" role="status">等待输入</span><span id="timing"></span></div><div id="candidates" aria-label="转换候选"></div>
<div class="examples"><span>试一试</span><button data-example="aizidongdazi">AI 自动打字</button><button data-example="woaini">我爱你</button><button data-example="hello world">hello world</button><button data-example="wo yong python xie daima">混合表达</button></div>
</section><aside>
<section class="explanation"><h2>它如何理解这段输入</h2><label class="field-label" for="context">可选语境</label><input id="context" placeholder="例如：正在讨论 AI 工具"><p class="hint">不读取其他应用；只使用你填写的语境。</p><div id="segments" class="segments"><p class="empty">输入后查看拼音、英文和原文片段。</p></div><div id="reasons"></div></section>
<section class="dictionary"><h2>你的词条</h2><p class="hint">只保存你主动添加的词条，可随时删除。</p><form id="entry-form"><label for="entry-text">文字</label><input id="entry-text" required maxlength="32" placeholder="例如：顺位"><label for="entry-pinyin">拼音，音节用空格分开</label><input id="entry-pinyin" required maxlength="128" placeholder="shun wei" pattern="[a-zA-ZvV]+([ '\\-][a-zA-ZvV]+)*"><button class="secondary" type="submit">添加词条</button></form><div id="entries"></div><p id="entry-message" role="status" class="hint"></p></section>
</aside></div>
<footer>当前为词典与规则驱动的验证原型。Mac 系统输入法另需安装启用，本地 AI 重排待接入。</footer></main>`;
function el<T extends HTMLElement>(id:string){return document.getElementById(id) as T;}
const editor=el<HTMLTextAreaElement>('editor'),repair=el<HTMLTextAreaElement>('repair');
let storageAvailable=true;
let entries:UserEntry[]=[];
try {const saved=JSON.parse(localStorage.getItem('shunwrite.entries')??'[]');if(Array.isArray(saved))entries=saved.filter(x=>typeof x?.text==='string'&&typeof x?.pinyin==='string').slice(0,100);}catch{storageAvailable=false;}
const session=new Session('chinese','',entries);
let tab:'live'|'repair'='live';let composing=false;let suppressComposition=false;
let range:{start:number;end:number}|null=null;
let transaction:{before:string;after:string;selection:number;tab:'live'|'repair'}|null=null;
function saveEntries(){try{localStorage.setItem('shunwrite.entries',JSON.stringify(entries));}catch{storageAvailable=false;}el('entry-message').textContent=storageAvailable?'词条保存于本浏览器，可在下方删除。':'浏览器存储不可用；词条仅在当前页面有效。';}
function renderEntries(){const list=el('entries');list.replaceChildren();for(const [i,entry] of entries.entries()){const row=document.createElement('div');row.className='entry';const text=document.createElement('span');text.textContent=`${entry.text} · ${entry.pinyin}`;const button=document.createElement('button');button.textContent='删除';button.setAttribute('aria-label',`删除词条 ${entry.text}`);button.onclick=()=>{entries.splice(i,1);saveEntries();renderEntries();refresh();};row.append(text,button);list.append(row);}}
function render(){
  const list=el('candidates');list.replaceChildren();const candidates=session.result.candidates;
  el('status').textContent=!session.raw?'等待输入':session.mode==='english'?'英文锁定':candidates.filter(x=>x.id!=='raw').length?'选择一个合适的表达':'保留原文';
  for(const [index,c] of candidates.entries()){
    const button=document.createElement('button');button.className=`candidate ${index===session.selected?'selected':''}`;button.setAttribute('aria-label',`提交候选 ${c.text}`);
    const text=document.createElement('span');text.textContent=c.text;const tag=document.createElement('small');tag.textContent=c.id==='raw'?'原文':c.reason.includes('中英混合分段')?'混输':'候选';button.append(text,tag);
    button.onpointerdown=e=>e.preventDefault();button.onclick=()=>commit(index);button.onmouseenter=()=>{session.selected=index;renderDetails(c);};list.append(button);
  }
  renderDetails(candidates[session.selected]);
}
function renderDetails(c?:Candidate){const host=el('segments');host.replaceChildren();if(!c||!session.raw){host.innerHTML='<p class="empty">输入后查看拼音、英文和原文片段。</p>';el('reasons').textContent='';return;}
  for(const s of c.segments){const item=document.createElement('div');item.className=`segment ${s.kind}`;const raw=document.createElement('code');raw.textContent=session.raw.slice(s.start,s.end);const output=document.createElement('strong');output.textContent=s.output;const label=document.createElement('small');label.textContent={pinyin:'拼音',english:'英文',abbreviation:'缩写',literal:'原文'}[s.kind];item.append(raw,output,label);host.append(item);}el('reasons').textContent=c.reason.join(' · ');
}
function refresh(raw=tab==='repair'?repair.value:range?editor.value.slice(range.start,range.end):''){
  session.mode=el<HTMLSelectElement>('mode').value as InputMode;session.context=el<HTMLInputElement>('context').value;session.userEntries=entries;
  const start=performance.now();session.update(raw,tab==='live'&&range?(editor.selectionStart-range.start):raw.length);el('timing').textContent=raw?`${(performance.now()-start).toFixed(1)} ms`:'';render();
}
function commit(index=session.selected,raw=false,suffix=''){
  const c=raw?{text:session.raw}:session.choose(index);if(!c||!session.raw)return;
  if(tab==='repair') {const output=el<HTMLTextAreaElement>('repair-output');transaction={before:output.value,after:c.text+suffix,selection:0,tab};output.value=c.text+suffix;}
  else if(range){const before=editor.value;const value=c.text+suffix;editor.setRangeText(value,range.start,range.end,'end');transaction={before,after:editor.value,selection:range.start,tab};range=null;}
  session.update('');session.invalidate();el<HTMLButtonElement>('undo').disabled=false;render();if(tab==='live')editor.focus();
}
function undo(){if(!transaction)return;const t=transaction;const target=t.tab==='live'?editor:el<HTMLTextAreaElement>('repair-output');if(target.value!==t.after){transaction=null;el<HTMLButtonElement>('undo').disabled=true;return;}target.value=t.before;if(t.tab==='live')target.setSelectionRange(t.selection,t.selection);transaction=null;range=null;session.update('');render();el<HTMLButtonElement>('undo').disabled=true;}
function switchTab(next:'live'|'repair'){if(tab==='live'&&range){range=null;session.invalidate();}tab=next;session.update('');el('live-pane').hidden=next!=='live';el('repair-pane').hidden=next!=='repair';el('live-tab').setAttribute('aria-selected',String(next==='live'));el('repair-tab').setAttribute('aria-selected',String(next==='repair'));render();}
let beforeEdit={value:'',start:0,end:0,inputType:''};
editor.addEventListener('beforeinput',(e)=>{const event=e as InputEvent;beforeEdit={value:editor.value,start:editor.selectionStart,end:editor.selectionEnd,inputType:event.inputType};});
editor.addEventListener('input',(event)=>{
  if(composing||(event as InputEvent).isComposing||['insertCompositionText','insertFromComposition'].includes((event as InputEvent).inputType))return;
  if(session.mode==='english'){range=null;refresh('');return;}
  if(suppressComposition){suppressComposition=false;range=null;refresh('');return;}
  const start=beforeEdit.start,end=beforeEdit.end,delta=editor.value.length-beforeEdit.value.length;
  if(range&&start>=range.start&&end<=range.end){range.end+=delta;if(range.end<=range.start)range=null;}
  else {const count=editor.value.length-(beforeEdit.value.length-(end-start));const inserted=editor.value.slice(start,start+Math.max(count,0));range=inserted&&/[a-zA-ZüÜāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ]/.test(inserted)?{start,end:start+inserted.length}:null;}
  if(transaction&&editor.value!==transaction.after){transaction=null;el<HTMLButtonElement>('undo').disabled=true;}
  refresh();
});
editor.addEventListener('keydown',(e)=>{
  if(composing||e.isComposing)return;
  if(e.metaKey||e.ctrlKey||e.altKey)return;
  if(!range||!session.raw)return;
  if(e.key===' '){e.preventDefault();commit();}
  else if(e.key==='Enter'){e.preventDefault();commit(session.selected,true);}
  else if(e.key==='Escape'){e.preventDefault();editor.setRangeText('',range.start,range.end,'end');range=null;session.update('');session.invalidate();render();}
  else if(e.key==='ArrowDown'||e.key==='ArrowUp'){e.preventDefault();session.navigate(e.key==='ArrowDown'?1:-1);render();}
});
editor.addEventListener('compositionstart',()=>{composing=true;range=null;session.update('');session.invalidate();render();});
editor.addEventListener('compositionend',()=>{composing=false;suppressComposition=true;range=null;session.update('');render();queueMicrotask(()=>suppressComposition=false);});
editor.addEventListener('blur',()=>session.invalidate());
editor.addEventListener('focus',()=>{if(range)refresh();});
editor.addEventListener('click',()=>{if(range&&(editor.selectionStart<range.start||editor.selectionEnd>range.end)){range=null;session.update('');render();}});
el('live-tab').onclick=()=>switchTab('live');el('repair-tab').onclick=()=>switchTab('repair');el('analyze').onclick=()=>refresh(repair.value);el('undo').onclick=undo;
el('mode').onchange=()=>{if(tab==='live'&&range&&el<HTMLSelectElement>('mode').value==='english')commit(session.selected,true);refresh();};el('context').oninput=()=>refresh();
repair.addEventListener('input',()=>{session.update('');render();});
for(const button of document.querySelectorAll<HTMLButtonElement>('[data-example]'))button.onclick=()=>{switchTab('repair');repair.value=button.dataset.example!;refresh();};
el<HTMLFormElement>('entry-form').onsubmit=e=>{e.preventDefault();const text=el<HTMLInputElement>('entry-text').value.trim(),pinyin=el<HTMLInputElement>('entry-pinyin').value.trim().toLowerCase();if(!text||!/^[a-zv]+(?:[ '\-][a-zv]+)*$/.test(pinyin))return;entries=entries.filter(x=>x.text!==text||x.pinyin!==pinyin);entries.push({text,pinyin});entries=entries.slice(-100);saveEntries();renderEntries();refresh();el<HTMLFormElement>('entry-form').reset();};
renderEntries();render();
