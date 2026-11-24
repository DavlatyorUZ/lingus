export function lexicalList(value) {
  try {const parsed=typeof value==='string'?JSON.parse(value):value;return Array.isArray(parsed)?parsed:[];} catch{return [];}
}
const key=s=>s.toLowerCase().replaceAll('_',' ').replace(/\s+/g,' ').trim();
export function senseSynonyms(lemma,sense) {
 const words=lexicalList(sense.words).filter(w=>typeof w==='string');
 if(!words.some(w=>key(w)===key(lemma)))return [];
 const seen=new Set([key(lemma)]),result=[];
 for(const raw of words){const word=raw.replaceAll('_',' ').trim(),k=key(raw);if(!word||word.length>80||/[<>\n\r{}\[\]]/.test(word)||seen.has(k))continue;seen.add(k);result.push(word);if(result.length===6)break;}
 return result;
}
export function senseExamples(sense) {
 const candidates=[],seen=new Set();
 function add(en,uz){if(typeof en!=='string')return;en=en.trim();const k=key(en).replace(/[.!]+$/,'');if(!en||en.length>320||seen.has(k))return;seen.add(k);candidates.push({en,uz:typeof uz==='string'?uz.trim():null});}
 for(const e of lexicalList(sense.bilingual_examples))if(e&&typeof e==='object')add(e.en,e.uz);
 for(const e of lexicalList(sense.examples))add(e,null);
 const type=e=>e.en.endsWith('?')?'question':/\bnot\b|n't\b|n’t\b|\bnever\b/i.test(e.en)?'negative':'positive',result=[];
 for(const kind of ['positive','negative','question']){const e=candidates.find(e=>type(e)===kind);if(e)result.push(e);}
 for(const e of candidates){if(result.length===3)break;if(!result.includes(e))result.push(e);}
 return result;
}
export function sensePresentation(lemma,sense){return {synonyms:senseSynonyms(lemma,sense),examples:senseExamples(sense)};}
