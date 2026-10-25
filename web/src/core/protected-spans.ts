export function protectedSpans(raw: string): {start:number;end:number}[] {
  // Explicit syntax only: ordinary words remain candidates, while identifiers and versions stay literal.
  const re = /(?:https?:\/\/|www\.)[^\s]+|[\w.+-]+@[\w.-]+\.[a-zA-Z]{2,}|(?:[A-Za-z]:[\\/]|(?:~|\.)?\/)[^\s]+|\b(?:v?\d+(?:\.\d+)+|[A-Za-z]+\d+[A-Za-z\d.-]*|[A-Za-z][\w]*_[\w]+)\b/g;
  return [...raw.matchAll(re)].map(m=>({start:m.index!,end:m.index!+m[0].length}));
}
