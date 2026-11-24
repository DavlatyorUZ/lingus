import fs from 'node:fs';import zlib from 'node:zlib';import assert from 'node:assert/strict';import{studyWord}from'../web/src/study-game.js';
const root=new URL('../',import.meta.url),read=p=>JSON.parse(fs.readFileSync(new URL(p,root))),manifest=read('web/dist/data/offline-manifest.json'),priority=read('mobile/assets/sense_priority.json').first_senses,bank=new Map(read('mobile/assets/quiz_bank.json').entries.map(w=>[w.id,w]));let words=0,details=0,answers=0;
for(const pack of manifest.packages){const data=JSON.parse(zlib.gunzipSync(fs.readFileSync(new URL('web/dist'+pack.url,root))));assert.equal(data.length,pack.count);
 if(pack.store==='words'){for(const w of data)assert.ok(w.translation.trim(),w.lemma);words+=data.length;}
 if(pack.store==='details'){for(const row of data){assert.equal(row.id,row.word.id);const senses=row.senses,lemma=row.word.normalized;
 if(senses.length){const reviewed=senses.some(s=>priority[lemma+':'+s.pos]);if(reviewed)assert.ok(priority[lemma+':'+senses[0].pos],lemma);const first=priority[lemma+':'+senses[0].pos];if(first)assert.equal(senses[0].id,first,lemma);}
 if(bank.has(row.id)){const selected=bank.get(row.id), expected=studyWord(row.word,senses);assert.deepEqual(selected.choices,expected.choices,lemma);assert.equal(selected.senseId,expected.senseId||'',lemma);assert.equal(selected.context,expected.context,lemma);answers++;}
 }details+=data.length;}
}
assert.equal(words,147380);assert.equal(details,words);assert.equal(answers,bank.size);assert.ok(manifest.dictionaryRevision.endsWith(':meanings-v3'));
const report={offline_words:words,offline_details:details,quiz_selected_sense_matches:answers,dictionary_integrity:'verified',content_revision:manifest.dictionaryRevision};fs.writeFileSync(new URL('docs/OFFLINE_WEB_AUDIT_'+read('server/package.json').version.replaceAll('.','_')+'.json',root),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));
