import {decode} from './decoder';
import type {DecodeRequest,UserEntry} from './types';
export function decodeJSON(request:string,entries='[]') {return JSON.stringify(decode(JSON.parse(request) as DecodeRequest,JSON.parse(entries) as UserEntry[]));}
