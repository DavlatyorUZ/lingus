import test from 'node:test';import assert from 'node:assert/strict';import{DatabaseSync}from'node:sqlite';import{senseSynonyms,senseExamples}from'../src/lexical-presentation.js';
test('Synonyms stay in the selected meaning and exclude self and duplicates',()=>{
 const money={words:JSON.stringify(['bank','depository','Depository','financial institution'])};
 assert.deepEqual(senseSynonyms('bank',money),['depository','financial institution']);
 assert.ok(!senseSynonyms('bank',money).includes('riverbank'));
 assert.deepEqual(senseSynonyms('run',{words:'["walk","stroll"]'}),[]);
});
test('An imported thousand-item group never renders more than six synonyms',()=>{
 const s={words:JSON.stringify(['big',...Array.from({length:1000},(_,i)=>'word'+i)])};assert.equal(senseSynonyms('big',s).length,6);
 assert.deepEqual(senseSynonyms('big',{words:'not-json'}),[]);
});
test('Examples combine sources without duplicates and prefer statement, negative and question',()=>{
 const s={bilingual_examples:JSON.stringify([{en:'I start now.',uz:'Hozir boshlayman.'}]),examples:JSON.stringify(['I start now.','We start early.','I do not start late.','Do you start today?','They start again.'])};
 assert.deepEqual(senseExamples(s).map(e=>e.en),['I start now.','I do not start late.','Do you start today?']);assert.equal(senseExamples(s)[0].uz,'Hozir boshlayman.');
});
test('Every real sense respects presentation limits and synonym membership',()=>{
 const db=new DatabaseSync(new URL('../../mobile/assets/dictionary.db',import.meta.url).pathname,{readOnly:true});let checked=0;
 for(const s of db.prepare('select * from senses').iterate()){
  const words=JSON.parse(s.words);if(!words.length)continue;
  const synonyms=senseSynonyms(words[0],s);assert.ok(synonyms.length<=6,s.id);assert.ok(senseExamples(s).length<=3,s.id);assert.equal(new Set(synonyms.map(w=>w.toLowerCase())).size,synonyms.length);checked++;
 }
 assert.ok(checked>100000);db.close();
});

test('Every quiz meaning and answer is linked to its exact dictionary sense',async()=>{
 const {readFileSync}=await import('node:fs');const root=new URL('../../',import.meta.url);
 const bank=JSON.parse(readFileSync(new URL('mobile/assets/quiz_bank.json',root)));
 const db=new DatabaseSync(new URL('mobile/assets/dictionary.db',root).pathname,{readOnly:true});
 const query=db.prepare('SELECT s.* FROM senses s JOIN entry_senses e ON s.id=e.sense_id WHERE e.entry_id=?');
 for(const w of bank.entries){
   const linked=new Map(query.all(w.id).map(s=>[s.id,s]));
   for(const sense of w.meanings){assert.ok(linked.has(sense.id),w.lemma);assert.deepEqual(sense.choices,senseSynonyms(w.lemma,linked.get(sense.id)).map(x=>x.toLowerCase()),w.lemma);assert.ok(sense.choices.length>0 && sense.choices.length<=6);}
   if(w.choices.length){const selected=w.meanings.find(s=>s.id===w.senseId);assert.ok(selected,w.lemma);assert.deepEqual(w.choices,selected.choices);assert.equal(w.context,selected.context);}
 }
 const start=bank.entries.find(w=>w.lemma==='start');assert.ok(start.choices.includes('begin'));assert.equal(start.context,'boshlamoq; boshlab yubormoq');
 assert.ok(bank.entries.find(w=>w.lemma==='large').choices.includes('big'));db.close();assert.ok(bank.entries.length>10000);
});
