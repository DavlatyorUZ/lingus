import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import {
  makeBank,
  prepareSession,
  generateSynonymOptions,
  generateTranslateOptions,
  similarity,
  studyWord,
  selectMeaning,
} from "../src/study-game.js";
const bank = makeBank(
  JSON.parse(
    fs.readFileSync(
      new URL("../../mobile/assets/quiz_bank.json", import.meta.url),
    ),
  ),
);
const word = (s) => bank.byLemma.get(s);
test("Synonym distractors are orthographically close and exclude all known true synonyms", () => {
  for (const lemma of ["big", "large", "lullaby"])
    for (let i = 0; i < 12; i++) {
      const w = word(lemma),
        q = generateSynonymOptions(w, bank);
      assert.ok(q, lemma);
      assert.equal(q.options.length, 4);
      assert.equal(new Set(q.options.map((o) => o.text)).size, 4);
      assert.ok(w.synonyms.includes(q.correct));
      for (const o of q.options.filter((o) => o.text !== q.correct)) {
        assert.ok(!w.synonyms.includes(o.text));
        assert.ok(!bank.byLemma.get(q.correct)?.synonyms.includes(o.text));
        assert.ok(similarity(q.correct, o.text) >= 45);
        assert.ok(o.explanation.endsWith("."));
        assert.ok(o.meaning);
      }
    }
});
test("Translate includes a real confusable and a non-word misspelling, with correct spelling feedback", () => {
  const positions = new Set();
  for (let i = 0; i < 80; i++) {
    const q = generateTranslateOptions(word("receive"), bank);
    assert.equal(q.question, "olmoq; qabul qilmoq");
    positions.add(q.options.findIndex((o) => o.kind === "correct"));
    const typo = q.options.find((o) => o.kind === "spelling");
    assert.equal(typo.text, "recieve");
    assert.equal(bank.valid.has(typo.text), false);
    assert.match(typo.explanation, /«ie» o‘rniga «ei»/);
    assert.equal(q.options.filter((o) => o.kind === "word").length, 2);
  }
  assert.equal(positions.size, 4);
});
test("single selected word works; empty, synonym-free, duplicate prompts and sets are handled", () => {
  assert.equal(
    prepareSession("translate", [word("receive")], bank).questions.length,
    1,
  );
  assert.equal(prepareSession("translate", [], bank).questions.length, 0);
  assert.equal(
    generateSynonymOptions(
      { ...word("receive"), synonyms: [], choices: [] },
      bank,
    ),
    null,
  );
  const r = prepareSession(
    "translate",
    [word("receive"), word("receive"), word("big")],
    bank,
  );
  assert.equal(r.questions.length, 2);
  assert.equal(r.skipped, 1);
});
test("dictionary-linked selection uses a single sense for answers while excluding all valid senses", () => {
  const w = studyWord({ id: 1, lemma: "big", translation: "katta" }, [
    { id: "a1", words: '["big","large"]', meaning_uz: "katta" },
    { id: "a2", words: '["big","grownup"]' },
  ]);
  assert.deepEqual(w.choices, ["large"]);
  assert.deepEqual(w.synonyms, ["large", "grownup"]);
  assert.equal(generateSynonymOptions(w, bank).correct, "large");
});
test("sample data and corpus retain all original headwords for typo validation", () => {
  assert.ok(bank.valid.size >= 147332);
  assert.ok(bank.entries.length >= 5500);
  assert.equal(
    word("lullaby").translation,
    "alla; bolani uxlatish uchun aytiladigan qo‘shiq",
  );
});

test('An ordinary selected word never receives a vulgar surprise distractor', () => {
  assert.ok(bank.byLemma.has('shit'));
  for(let i=0;i<12;i++) {
    const q=generateTranslateOptions({id:1,lemma:'sit',translation:'o‘tirmoq',synonyms:[],groups:[]},bank);
    assert.ok(q);
    assert.ok(!q.options.some(o=>o.text==='shit'));
  }
});

test('Polysemous synonyms cannot borrow an unrelated translation; an empty sense stays empty',()=>{
 assert.equal(generateSynonymOptions({id:1,lemma:'run',translation:'yugurmoq',groups:['v1','n1'],synonyms:['tally'],choices:['tally']},bank),null);
 const w=studyWord({id:1,lemma:'run',translation:'yugurmoq'},[{id:'v1',words:'["run"]'},{id:'n1',words:'["run","tally"]'}]);assert.deepEqual(w.choices,['tally']);assert.equal(generateSynonymOptions(w,bank),null);
});

test('Start exposes verb synonyms even when the first noun sense is a singleton',()=>{
 const w=word('start');assert.ok(w.meanings.length>1);assert.ok(w.choices.includes('begin'));assert.equal(w.context,'boshlamoq; boshlab yubormoq');
 for(let i=0;i<20;i++){const q=generateSynonymOptions(w,bank);assert.ok(q);assert.ok(w.choices.includes(q.correct));assert.equal(q.context,w.context);}
 const noun=w.meanings.find(s=>s.choices.includes('beginning'));assert.ok(noun);
 const selected=selectMeaning(w,noun.id);assert.ok(selected.choices.includes('beginning'));assert.ok(!selected.choices.includes('begin'));assert.equal(w.choices.includes('begin'),true);
});
