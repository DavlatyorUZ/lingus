import {senseSynonyms} from "../../server/src/lexical-presentation.js";
const norm = (s) => s.toLowerCase().replaceAll("_", " ").trim();
export function studyWord(word, senses = []) {
  const meanings = senses.map(s => {
    return {id:s.id, pos:s.pos || '', definition:s.definition || '',
      context:s.meaning_uz || '',
      choices:senseSynonyms(word.lemma,s).map(norm)};
  }).filter(s=>s.choices.length);
  const result = {
    ...word,
    choices: [], meanings,
    groups: senses.map((s) => s.id),
    synonyms: [
      ...new Set(
        senses
          .flatMap((s) =>
            typeof s.words === "string" ? JSON.parse(s.words) : s.words,
          )
          .map(norm),
      ),
    ].filter((w) => w !== norm(word.lemma)),
    context: "",
  };
  const glosses = (word.translation || '').split(';').map(norm).filter(Boolean);
  const score = sense => Math.max(0, ...glosses.map((g,i)=>
    sense.context.split(';').map(norm).includes(g) ? glosses.length-i+1 : 0));
  const first = [...meanings].sort((a,b)=>score(b)-score(a))[0];
  return first ? selectMeaning(result,first.id) : result;
}
export function selectMeaning(word, id) {
  const sense = word.meanings?.find(s=>s.id === id);
  if (!sense) throw Error('Ma’noni qayta tanlang.');
  return {...word, senseId:sense.id, context:sense.context, choices:sense.choices};
}
export function makeBank(data) {
  return {
    ...data,
    valid: new Set(data.validWords),
    byLemma: new Map(data.entries.map((w) => [w.lemma, w])),
  };
}
export function editDistance(a, b) {
  let row = Array.from({ length: b.length + 1 }, (_, i) => i);
  for (let i = 1; i <= a.length; i++) {
    const next = [i];
    for (let j = 1; j <= b.length; j++)
      next[j] = Math.min(
        row[j] + 1,
        next[j - 1] + 1,
        row[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1),
      );
    row = next;
  }
  return row[b.length];
}
// Conservative Uzbek gloss overlap: normalize apostrophes and a few derivations.
const stopTerms = new Set(['bir','bilan','uchun','emas','yoki','holda','juda','nisbatan',"qo'pol",'norasmiy',"bo'l",'qil','et','odam','kishi','narsa']);
const meaningTerms = s=>new Set((s||'').toLowerCase().replace(/[‘’ʻʼ`]/g,"'").split(/[^a-z']+/).map(w=>w.replace(/(moq|uvchi|ish|lik)$/,'')).filter(w=>w.length>2&&!stopTerms.has(w)));
const meaningOverlap = (a,b)=>[...meaningTerms(a)].some(w=>meaningTerms(b).has(w));
function synonymMeaning(word,target) {
 if(word.context) return word.context;
 if((word.groups||[]).length<=1) return word.translation||target?.translation||'';
 // Never explain a polysemous answer using an unrelated primary gloss.
 for(const part of (word.translation||'').split(';')) if(meaningOverlap(part,target?.translation)) return part.trim();
 return '';
}
const phonetic = (w) =>
  w
    .replace(/ph/g, "f")
    .replace(/kn/g, "n")
    .replace(/ck/g, "k")
    .replace(/[aeiouy]/g, "")
    .replace(/(.)\1+/g, "$1");
export function similarity(a, b) {
  const d = editDistance(a, b);
  let prefix = 0,
    suffix = 0;
  while (prefix < Math.min(a.length, b.length) && a[prefix] === b[prefix])
    prefix++;
  while (
    suffix < Math.min(a.length, b.length) &&
    a[a.length - 1 - suffix] === b[b.length - 1 - suffix]
  )
    suffix++;
  return (
    100 -
    12 * d +
    Math.min(prefix, 4) * 4 +
    Math.min(suffix, 4) * 3 +
    (phonetic(a) === phonetic(b) ? 20 : 0)
  );
}
function shuffled(items, rng) {
  const a = [...items];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}
function sameWordFamily(a, b) {
  const [base, longer] = a.length <= b.length ? [a,b] : [b,a];
  if (longer.endsWith(base) && ['en','re','un','dis','over','under','mis'].includes(longer.slice(0,-base.length))) return true;
  if (!longer.startsWith(base)) return false;
  return ['s','es','ed','ing','ly','ness','less','ful','er','est',...(base.endsWith('e')?['r','st']:[])].includes(longer.slice(base.length));
}
function candidates(word, correct, bank, rng) {
  const target = bank.byLemma.get(correct),
    banned = new Set([
      norm(word.lemma),
      correct,
      ...(word.synonyms || []),
      ...(target?.synonyms || []),
    ]),
    groups = new Set([...(word.groups || []), ...(target?.groups || [])]);
  // Exclude indirect lexical neighbours too: a related meaning must not become
  // a supposedly wrong answer merely because it belongs to another synset.
  for (const lemma of [...banned]) {
    const neighbour = bank.byLemma.get(lemma);
    for (const synonym of neighbour?.synonyms || []) banned.add(synonym);
  }
  return bank.entries
    .filter(
      (w) =>
        !banned.has(w.lemma) &&
        Math.abs(w.lemma.length - correct.length) <= 4 &&
        similarity(correct, w.lemma) >= 45 &&
        !sameWordFamily(correct, w.lemma) &&
        w.translation &&
        !/qo[‘’ʻʼ']pol|haqorat|so[‘’ʻʼ']kinish|\bjinsiy\b|\bqin\b|\bnajas\b/i.test(w.translation) &&
        w.translation !== word.translation &&
        w.translation !== target?.translation &&
        !meaningOverlap(w.translation, word.translation) &&
        !meaningOverlap(w.translation, target?.translation) &&
        !w.groups.some((g) => groups.has(g)),
    )
    .map((w) => ({ w, score: similarity(correct, w.lemma) + rng() * 4 }))
    .sort((a, b) => b.score - a.score)
    .slice(0, 3)
    .map((x) => x.w);
}
function spelling(word, bank) {
  const options = [...(bank.typicalMisspellings[word] || [])];
  for (let i = 0; i < word.length - 1; i++)
    options.push(word.slice(0, i) + word[i + 1] + word[i] + word.slice(i + 2));
  for (let i = 0; i < word.length; i++)
    options.push(
      word.slice(0, i) + word.slice(i + 1),
      word.slice(0, i) + word[i] + word.slice(i),
    );
  options.push(word + word.at(-1), word + "e");
  return options.find(
    (w) =>
      w !== word &&
      w.length > 1 &&
      !bank.valid.has(w) &&
      /^[a-z]+(?:[ '-][a-z]+){0,5}$/.test(w) &&
      w.split(/[ '-]/).some((t) => !bank.valid.has(t)),
  );
}
function spellingDetail(correct, wrong) {
  let a = 0,
    b = 0;
  while (a < Math.min(correct.length, wrong.length) && correct[a] === wrong[a])
    a++;
  while (
    b < Math.min(correct.length, wrong.length) - a &&
    correct.at(-1 - b) === wrong.at(-1 - b)
  )
    b++;
  const x = wrong.slice(a, wrong.length - b),
    y = correct.slice(a, correct.length - b);
  return x && y
    ? `«${x}» o‘rniga «${y}» yoziladi`
    : x
      ? `«${x}» ortiqcha yozilgan`
      : `«${y}» tushib qolgan`;
}
const brief = (s) =>
  (s || "").split(";").slice(0, 2).join("; ").slice(0, 120).trim();
function realOption(w, correct, meaning) {
  return {
    text: w.lemma,
    kind: "word",
    meaning: w.translation,
    explanation: `«${w.lemma}» — ${brief(w.translation)}; yozilishi o‘xshash, ma’nosi boshqa. To‘g‘ri javob «${correct}» — ${brief(meaning)}.`,
  };
}
export function generateSynonymOptions(word, bank, rng = Math.random) {
  for (const correct of shuffled(
    (word.choices ?? word.synonyms ?? []).filter(
      (w) => /^[a-z]+(?: [a-z]+){0,2}$/.test(w) && w !== norm(word.lemma),
    ),
    rng,
  )) {
    const meaning = synonymMeaning(word,bank.byLemma.get(correct));
    if (!meaning) continue;
    const others = candidates(word, correct, bank, rng);
    if (others.length < 3) continue;
    return {
      word,
      question: word.lemma,
      context: meaning,
      correct,
      options: shuffled(
        [
          { text: correct, kind: "correct", meaning, explanation: "" },
          ...others.map((w) => realOption(w, correct, meaning)),
        ],
        rng,
      ),
    };
  }
  return null;
}
export function generateTranslateOptions(word, bank, rng = Math.random) {
  const correct = norm(word.lemma),
    typo = spelling(correct, bank),
    others = candidates(word, correct, bank, rng);
  if (!word.translation || !typo || others.length < 2) return null;
  return {
    word,
    question: word.translation,
    context: "",
    correct,
    options: shuffled(
      [
        {
          text: correct,
          kind: "correct",
          meaning: word.translation,
          explanation: "",
        },
        {
          text: typo,
          kind: "spelling",
          meaning: "",
          explanation: `«${typo}» imlosida ${spellingDetail(correct, typo)}. To‘g‘risi «${correct}» — ${brief(word.translation)}.`,
        },
        ...others
          .slice(0, 2)
          .map((w) => realOption(w, correct, word.translation)),
      ],
      rng,
    ),
  };
}
export function prepareSession(mode, words, bank, rng = Math.random) {
  const questions = [],
    seen = new Set(),
    sets = new Set();
  for (const w of shuffled(words, rng)) {
    const q = (
      mode === "synonyms" ? generateSynonymOptions : generateTranslateOptions
    )(w, bank, rng);
    if (!q) continue;
    const key = norm(q.question),
      set = q.options
        .map((o) => o.text)
        .sort()
        .join("|");
    if (seen.has(key) || sets.has(set)) continue;
    seen.add(key);
    sets.add(set);
    questions.push(q);
  }
  return { questions, skipped: words.length - questions.length };
}
