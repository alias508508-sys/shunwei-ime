import {decode} from './decoder';
import type {Candidate,DecodeResult,InputMode,UserEntry} from './types';
export class Session {
  readonly id=`session-${Math.random().toString(36).slice(2)}`;
  revision=0; raw=''; cursor=0; selected=0; frozen=false; active=true;
  result:DecodeResult={sessionId:this.id,revision:0,candidates:[],rawFallback:''};
  constructor(public mode:InputMode='chinese',public context='',public userEntries:UserEntry[]=[]) {}
  update(raw:string,cursor=raw.length) {this.raw=raw;this.cursor=cursor;this.revision++;this.selected=0;this.frozen=false;this.active=true;this.result=decode(this.request(),this.userEntries);return this.result;}
  request() {return {sessionId:this.id,revision:this.revision,raw:this.raw,cursor:this.cursor,mode:this.mode,context:this.context};}
  accept(result:DecodeResult) {if(!this.active||this.frozen||result.sessionId!==this.id||result.revision!==this.revision)return false;this.result=result;return true;}
  navigate(direction:number) {if(!this.result.candidates.length)return;this.frozen=true;this.selected=(this.selected+direction+this.result.candidates.length)%this.result.candidates.length;}
  invalidate(){this.revision++;this.active=false;}
  choose(index=this.selected):Candidate|undefined {const c=this.result.candidates[index];this.invalidate();return c;}
}
