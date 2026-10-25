import chinese from '../../../data/chinese-lexicon.json';
import english from '../../../data/english-lexicon.json';
import abbreviations from '../../../data/abbreviations.json';
import {normalize} from './normalizer';
import {protectedSpans} from './protected-spans';
import type {Candidate, DecodeRequest, DecodeResult, Segment, UserEntry} from './types';
interface Word {text:string; syllables:string[]; frequency:number; pos?:string; user?:boolean}
interface Trie {children:Map<string,Trie>; words:Word[]}
const root:Trie={children:new Map(),words:[]};
function addWord(entry:Word, tree:Trie) {
  let node=tree;
  for(const c of entry.syllables.join('')) { if(!node.children.has(c)) node.children.set(c,{children:new Map(),words:[]}); node=node.children.get(c)!; }
  node.words.push(entry); node.words.sort((a,b)=>b.frequency-a.frequency); const counts=new Map<string,number>();node.words=node.words.filter(w=>{const key=w.syllables.join(' '),n=counts.get(key)??0;counts.set(key,n+1);return n<8;});
}
for(const [text,pin,frequency,pos] of chinese as [string,string,number,string][]) addWord({text,syllables:pin.split(' '),frequency,pos},root);
const englishSet=new Set(english);
const commonEnglish=new Set('a i an am are as at be been but by can cat car code data do dog for from go had has have he her here him his how if in into is it its like me my no not of on one or our out she so some than that the their them then there these they this time to two up us use was we were what when where which who why will with work would you your hello world love good morning thanks today tomorrow please name test input automatic school student book computer apple music game happy yes and english'.split(' '));
const abbreviationMap=abbreviations as Record<string,string>;
const beam=32;
interface Path {segments:Segment[];score:number;last:Segment['kind']|null}
function makeText(segments:Segment[],raw:string) {
  let result='';
  for(let i=0;i<segments.length;i++) {
    const s=segments[i],p=segments[i-1];
    // Spaces separating Chinese pinyin words are consumed; English word boundaries are retained.
    if(s.kind==='literal' && /^\s+$/.test(s.output)) {
      const before=segments.slice(0,i).reverse().find(x=>x.kind!=='literal');
      const after=segments.slice(i+1).find(x=>x.kind!=='literal');
      if(before?.kind==='pinyin'&&after?.kind==='pinyin') continue;
    }
    if(p && p.end===s.start && p.kind!=='literal' && s.kind!=='literal' &&
      ((p.kind==='pinyin')!==(s.kind==='pinyin'))) result+=' ';
    result+=s.output;
  }
  return result || raw;
}
function prune(paths:Path[],raw:string) {
  const seen=new Set<string>(); const groups=new Map<string,number>();
  return paths.sort((a,b)=>b.score-a.score).filter(p=>{
    const text=makeText(p.segments,raw);if(seen.has(text))return false;seen.add(text);
    const key=String(p.segments.some(s=>s.kind==='pinyin'))+String(p.segments.some(s=>s.kind==='english'||s.kind==='abbreviation'));
    const count=groups.get(key)??0;if(count>=16)return false;groups.set(key,count+1);return true;
  }).slice(0,beam);
}
function syntaxBonus(previous:Segment[],current:Segment) {
  const prev=previous.slice().reverse().find(s=>s.kind!=='literal');
  if(current.kind!=='pinyin')return 0;
  if(current.pos==='q' && prev?.pos!=='m')return -2;
  if(prev?.pos?.startsWith('v') && current.pos?.startsWith('n'))return 2;
  if(prev?.pos==='r' && current.pos?.startsWith('v'))return 1;
  return 0;
}
export function decode(request:DecodeRequest, userEntries:UserEntry[]=[]):DecodeResult {
  const {raw,mode}=request;
  const literal:Candidate={id:'raw',text:raw,score:0,segments:raw?[{start:0,end:raw.length,kind:'literal',output:raw}]:[],reason:['原文完整保留']};
  const result=(candidates:Candidate[]):DecodeResult=>({sessionId:request.sessionId,revision:request.revision,candidates,rawFallback:raw});
  if(!raw)return result([]);
  if(mode==='english' || raw.length>256) return result([{...literal,reason:[raw.length>256?'超过256字符，原文保留':mode==='english'?'英文锁定，原样提交':'等待输入']}]);
  const userRoot:Trie={children:new Map(),words:[]};
  for(const entry of userEntries) {
    if(!entry.text || !/^[a-zv]+(?:[ '\-][a-zv]+)*$/i.test(entry.pinyin))continue;
    addWord({text:entry.text,syllables:entry.pinyin.toLowerCase().split(/[ '\-]+/),frequency:100000,user:true},userRoot);
  }
  const {text,starts,ends}=normalize(raw); const spans=protectedSpans(raw);
  const paths:Path[][]=Array.from({length:text.length+1},()=>[]);paths[0]=[{segments:[],score:0,last:null}];
  const aiContext=/\b(ai|gpt|api|model)\b|人工智能|智能|模型|自动|代码/i.test(request.context??'');
  for(let i=0;i<text.length;i++) {
    if(!paths[i].length)continue;
    paths[i]=prune(paths[i],raw);
    const edges:{end:number;segment:Segment;score:number}[]=[];
    const protectedSpan=spans.find(s=>s.start<=starts[i] && starts[i]<s.end);
    if(protectedSpan) {
      let j=i+1;while(j<text.length&&starts[j]<protectedSpan.end)j++;
      edges.push({end:j,segment:{start:starts[i],end:ends[j-1],kind:'literal',output:raw.slice(starts[i],ends[j-1]),source:'受保护原文'},score:0});
    } else if(/[a-zv]/.test(text[i])) {
      for(const tree of [root,userRoot]) {
        let node=tree;let letters='';const explicitBoundaries:number[]=[];
        for(let j=i;j<Math.min(text.length,i+32);j++) {
          if(text[j]==="'") {explicitBoundaries.push(letters.length);continue;}
          if(!/[a-zv]/.test(text[j]) || spans.some(s=>s.start<=starts[j]&&starts[j]<s.end))break;
          node=node.children.get(text[j])!;if(!node)break;letters+=text[j];
          for(const w of node.words) {
            let n=0;const boundaries=w.syllables.slice(0,-1).map(s=>n+=s.length);
            if(explicitBoundaries.some(b=>!boundaries.includes(b)))continue;
            const score=letters.length*2+Math.log(w.frequency+2)*0.7-8+6*(w.syllables.length-1)*Math.min(1,Math.log(w.frequency+2)/Math.log(100))+(mode==='chinese'?2:0)+(w.user?5:0);
            edges.push({end:j+1,segment:{start:starts[i],end:ends[j],kind:'pinyin',output:w.text,pos:w.pos,source:w.user?'用户词条':w.syllables.join(' ')},score});
          }
        }
      }
      let word='';
      for(let j=i;j<Math.min(text.length,i+32)&&/[a-z]/.test(text[j]);j++) {
        if(spans.some(s=>s.start<=starts[j]&&starts[j]<s.end))break;
        word+=text[j];const abbr=abbreviationMap[word];
        if(abbr || (englishSet.has(word)&&word.length>=3) || (commonEnglish.has(word) && (word.length>=2 || ((i===0||!/[a-z]/.test(text[i-1])) && (j+1===text.length||!/[a-z]/.test(text[j+1])))))) {
          const known=commonEnglish.has(word);
          edges.push({end:j+1,segment:{start:starts[i],end:ends[j],kind:abbr?'abbreviation':'english',output:abbr??raw.slice(starts[i],ends[j]),source:abbr?'常用技术缩写':'CMU/常用英文'},score:word.length*2-8+(known?8:0)+(abbr?8:0)+(abbr&&aiContext?5:0)-(mode==='chinese'?2:0)});
        }
      }
      edges.push({end:i+1,segment:{start:starts[i],end:ends[i],kind:'literal',output:raw.slice(starts[i],ends[i])},score:-4});
    } else {
      // One original grapheme per literal edge, so surrogate pairs/combining marks are not duplicated.
      let j=i+1;while(j<text.length&&starts[j]===starts[i])j++;
      edges.push({end:j,segment:{start:starts[i],end:ends[j-1],kind:'literal',output:raw.slice(starts[i],ends[j-1])},score:0});
    }
    for(const edge of edges) {
      for(const p of paths[i]) {
        const switchCost=p.last && p.last!=='literal' && edge.segment.kind!=='literal' &&
          ((p.last==='pinyin')!==(edge.segment.kind==='pinyin'))?1:0;
        paths[edge.end].push({segments:[...p.segments,edge.segment],score:p.score+edge.score-switchCost+syntaxBonus(p.segments,edge.segment),last:edge.segment.kind});
      }
      if(paths[edge.end].length>beam*8)paths[edge.end]=prune(paths[edge.end],raw);
    }
  }
  const ranked=prune(paths[text.length],raw).map((p,index)=>{
    const kinds=new Set(p.segments.filter(s=>s.kind!=='literal').map(s=>s.kind));
    const reason:string[]=[];
    if(kinds.has('pinyin'))reason.push('拼音词典匹配');
    if(kinds.has('english'))reason.push('英文词典匹配');
    if(kinds.has('abbreviation'))reason.push(aiContext?'技术上下文支持缩写':'保留技术缩写');
    if(kinds.has('pinyin')&&(kinds.has('english')||kinds.has('abbreviation')))reason.push('中英混合分段');
    if(p.segments.some(s=>s.source==='用户词条'))reason.push('你的用户词条');
    return {id:`candidate-${index}`,text:makeText(p.segments,raw),segments:p.segments,score:p.score,reason};
  }).filter(c=>c.text!==raw);
  // Include a fully Chinese alternative when ambiguity produces many mixed variants.
  const chosen=ranked.slice(0,4);
  const allChinese=ranked.find(c=>c.segments.some(s=>s.kind==='pinyin')&&!c.segments.some(s=>s.kind==='english'||s.kind==='abbreviation'));
  if(allChinese && !chosen.includes(allChinese))chosen.splice(3,1,allChinese);
  if(ranked.length===0)return result([literal]);
  // A complete English word is the conservative default, except for known technical casing.
  if((englishSet.has(text)||commonEnglish.has(text))&&!abbreviationMap[text]&&mode==='auto')return result([literal,...chosen].slice(0,5));
  return result([...chosen,literal]);
}
