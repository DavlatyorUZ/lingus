import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
const slang = JSON.parse(
  fs.readFileSync(new URL("../src/slang.json", import.meta.url)),
);
const offline = JSON.parse(
  fs.readFileSync(
    new URL("../../mobile/assets/informal_glosses.json", import.meta.url),
  ),
);
const aliases = JSON.parse(
  fs.readFileSync(
    new URL("../../mobile/assets/spelling_aliases.json", import.meta.url),
  ),
);
test("missing everyday and vulgar vocabulary have matching offline and API definitions", () => {
  for (const w of [
    "lullaby",
    "cradle song",
    "fuck",
    "fuck off",
    "fuck up",
    "sexual intercourse",
  ]) {
    assert.ok(slang[w]);
    assert.equal(slang[w], offline[w]);
  }
  assert.match(slang.fuck, /\[qo‘pol\].*jinsiy aloqa/);
  assert.ok(!slang.fuck.includes("vint"));
  assert.equal(aliases.lalluby, "lullaby");
});

test("All editorial meanings match across server and native client", () =>
  assert.deepEqual(slang, offline));

test('Clinical vocabulary stays neutral and distinct from vulgar usage', () => {
  for (const word of ['penis','vagina','uterus','ovary','sperm','semen','testicle','urethra']) {
    assert.ok(slang[word]);
    assert.ok(!slang[word].includes('qo‘pol'));
  }
  assert.match(slang.penis,/olat/);
  assert.match(slang.sperm,/hujayra/);
  assert.match(slang.semen,/suyuqligi/);
  assert.notEqual(slang.sperm,slang.semen);
  for (const word of ['fuck','shit','bullshit','asshole','bastard','bitch']) assert.match(slang[word],/qo‘pol|haqoratli/);
});
