import fs from "node:fs";
import {
  makeBank,
  generateSynonymOptions,
  generateTranslateOptions,
} from "../web/src/study-game.js";
const root = new URL("../", import.meta.url);
const bank = makeBank(
  JSON.parse(fs.readFileSync(new URL("mobile/assets/quiz_bank.json", root))),
);
let seed = 340;
const version = JSON.parse(fs.readFileSync(new URL('server/package.json',root))).version;
const rng = () => {
  seed = (seed * 1664525 + 1013904223) >>> 0;
  return seed / 4294967296;
};
const examples = [];
for (const [mode, lemma] of [
  ["synonyms", "big"],
  ["synonyms", "large"],
  ["synonyms", "start"],
  ["translate", "receive"],
  ["translate", "lullaby"],
]) {
  const q = (
    mode === "synonyms" ? generateSynonymOptions : generateTranslateOptions
  )(bank.byLemma.get(lemma), bank, rng);
  if (!q) throw Error(`Sample question unavailable: ${lemma}`);
  examples.push({ mode, ...q });
}
fs.writeFileSync(
  new URL(`docs/GAME_SAMPLE_DATA_${version.replaceAll('.','_')}.json`, root),
  JSON.stringify(
    {
      examples,
      edge_cases: [
        "empty selection disables Start",
        "one word can start",
        "no synonyms offers Translate",
        "unavailable confusables skip with notice",
        "only one answer per question",
      ],
    },
    null,
    2,
  ) + "\n",
);
console.log(`${examples.length} reproducible question examples exported`);
