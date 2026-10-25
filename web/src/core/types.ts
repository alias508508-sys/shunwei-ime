export type InputMode = 'auto' | 'english' | 'chinese';
export interface Segment { start: number; end: number; kind: 'pinyin'|'english'|'abbreviation'|'literal'; output: string; source?: string; pos?: string; }
export interface Candidate { id: string; text: string; segments: Segment[]; score: number; reason: string[]; }
export interface DecodeRequest { sessionId: string; revision: number; raw: string; cursor: number; mode: InputMode; context?: string; }
export interface DecodeResult { sessionId: string; revision: number; candidates: Candidate[]; rawFallback: string; }
export interface UserEntry { text: string; pinyin: string; }
