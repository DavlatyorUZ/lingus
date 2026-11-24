import test from "node:test";
import assert from "node:assert/strict";
import {
  questions,
  schedule,
  offlineGrammar,
  escapeHtml,
  csvCell,
  reviewAfterGame,
} from "../src/domain.js";
const words = Array.from({ length: 8 }, (_, i) => ({
  id: i + 1,
  lemma: "word" + i,
  translation: "ma’no" + i,
}));
test("all quiz questions and options belong to saved words", () => {
  const ids = new Set(words.map((w) => w.id));
  for (let t = 0; t < 30; t++)
    for (const q of questions(words)) {
      assert.ok(ids.has(q.word.id));
      assert.equal(q.options.length, 4);
      assert.equal(new Set(q.options.map((w) => w.id)).size, 4);
      q.options.forEach((w) => assert.ok(ids.has(w.id)));
    }
});
test("insufficient or duplicate meanings cannot start a game", () => {
  assert.deepEqual(questions([]), []);
  assert.deepEqual(questions(words.slice(0, 3)), []);
  assert.deepEqual(
    questions(words.map((w) => ({ ...w, translation: "same" }))),
    [],
  );
});
test("SRS failure uses ten-minute retry; success advances", () => {
  assert.equal(schedule({}, 0, 0).due, 600000);
  assert.equal(schedule({}, 2, 0).due, 86400000);
  assert.ok(schedule({ reps: 2, interval: 6, ease: 2.5 }, 2, 0).interval > 6);
});
test("offline grammar preserves capitalization and reports exact original spans", () => {
  const text = "I is ready. You is here.",
    r = offlineGrammar(text);
  assert.equal(r.corrected, "I am ready. You are here.");
  assert.equal(r.issues.length, 2);
  for (const i of r.issues)
    assert.equal(text.slice(i.start, i.end), i.original);
});

test("untrusted names, folders and AI text remain inert HTML", () => {
  const escaped = escapeHtml('<img src=x onerror="alert(1)"> & test');
  assert.ok(!escaped.includes("<"));
  assert.ok(!escaped.includes(">"));
  assert.ok(escaped.includes("&lt;img"));
  assert.ok(escaped.includes("&quot;"));
  assert.equal(escapeHtml(null), "");
});
test("CSV export neutralizes spreadsheet formulas, including leading whitespace", () => {
  for (const value of ["=1+1", "+SUM(A1)", "@call", "-2+3", " \t=HYPERLINK(1)"])
    assert.ok(csvCell(value).startsWith("\"'"));
  assert.equal(csvCell("don't"), `"don't"`);
  assert.equal(csvCell('a,"b"'), '"a,""b"""');
});

test('early correct game answers cannot inflate future review intervals',()=>{const old={due:86400000,interval:1,reps:1,ease:2.5};assert.deepEqual(reviewAfterGame(old,true,0),old);assert.equal(reviewAfterGame(old,false,0).due,600000);assert.ok(reviewAfterGame(old,true,86400001).due>86400001);});
