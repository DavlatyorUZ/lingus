export const normalize = (s) =>
  s
    .toLowerCase()
    .replace(/[‘’ʻʼ`´]/g, "'")
    .replace(/\s+/g, " ")
    .trim();
export function shuffle(list) {
  const a = [...list];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}
export function gameWords(words) {
  const seen = new Set();
  return words.filter(
    (w) => w.translation && !seen.has(w.translation) && seen.add(w.translation),
  );
}
export function questions(words, n = 10) {
  const pool = gameWords(words);
  if (pool.length < 4) return [];
  return shuffle(pool)
    .slice(0, n)
    .map((word) => ({
      word,
      options: shuffle([
        word,
        ...shuffle(pool.filter((x) => x.id !== word.id)).slice(0, 3),
      ]),
    }));
}
export function schedule(old = {}, grade, now = Date.now()) {
  const ease = Math.max(1.3, (old.ease || 2.5) + (grade === 0 ? -0.2 : 0.1)),
    reps = grade === 0 ? 0 : (old.reps || 0) + 1,
    interval =
      reps === 0
        ? 10 / 1440
        : reps === 1
          ? 1
          : reps === 2
            ? 6
            : Math.round((old.interval || 6) * ease);
  return { ease, reps, interval, due: now + interval * 86400000 };
}
export function offlineGrammar(text) {
  const rules = [
    [
      /\b(he|she|it) don['’]t\b/gi,
      "$1 doesn't",
      "He, she, it bilan inkorda doesn’t ishlatiladi.",
    ],
    [/\bi is\b/gi, "I am", "I bilan am ishlatiladi."],
    [/\byou is\b/gi, "you are", "You bilan are ishlatiladi."],
    [/\b(he|she|it) are\b/gi, "$1 is", "He, she, it bilan is ishlatiladi."],
    [/\bmore better\b/gi, "better", "Qiyosiy shaklda more ortiqcha."],
    [/\b(can|must|should) to\b/gi, "$1", "Modal fe’ldan keyin to qo‘yilmaydi."],
  ];
  const issues = [];
  for (const [regex, replacement, explanation] of rules)
    for (const m of text.matchAll(regex)) {
      let r = m[0].replace(regex, replacement);
      if (m[0][0] === m[0][0].toUpperCase())
        r = r[0].toUpperCase() + r.slice(1);
      issues.push({
        start: m.index,
        end: m.index + m[0].length,
        original: m[0],
        replacement: r,
        explanation,
      });
    }
  let corrected = text;
  for (const i of [...issues].sort((a, b) => b.start - a.start))
    corrected =
      corrected.slice(0, i.start) + i.replacement + corrected.slice(i.end);
  return {
    corrected,
    issues,
    explanation: "Oflayn tekshiruv: faqat sodda qoidalar tekshirildi.",
  };
}

export function escapeHtml(value) {
  return String(value ?? "").replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
}
export function csvCell(value) {
  const text = String(value ?? "");
  const safe = /^[=+@\-\t\r\n]|^\s+[=+@\-]/.test(text) ? "'" + text : text;
  return '"' + safe.replace(/"/g, '""') + '"';
}

export function reviewAfterGame(old,correct,now=Date.now()) { return correct && old.due > now ? {...old} : schedule(old,correct?2:0,now); }
