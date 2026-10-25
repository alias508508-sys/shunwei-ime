/** Keep one offset per normalized character; accents and combining marks retain original spans. */
export function normalize(raw: string) {
  let text = ''; const starts: number[] = []; const ends: number[] = [];
  const graphemes = new Intl.Segmenter('zh', { granularity: 'grapheme' });
  const parts=[...graphemes.segment(raw)];
  for(let part=0;part<parts.length;part++) {
    const {segment,index}=parts[part];
    if(segment.toLowerCase()==='u' && parts[part+1]?.segment===':') { text+='v';starts.push(index);ends.push(index+2);part++;continue; }
    const value = segment.toLowerCase().normalize('NFD').replace(/u\u0308/g, 'v').replace(/[\u0300-\u036f]/g, '');
    for (const c of value) { text += c; for (let i=0;i<c.length;i++) { starts.push(index); ends.push(index+segment.length); } }
  }
  return {text, starts, ends};
}
