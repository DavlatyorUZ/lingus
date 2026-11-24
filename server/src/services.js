import { sensePresentation } from "./lexical-presentation.js";
import { suggestions } from "./spelling.js";
import { DatabaseSync } from "node:sqlite";
import { readFileSync, statSync } from "node:fs";
import path from "node:path";
import { z } from "zod";
import sharp from "sharp";
import { Failure } from "./security.js";
import { tx } from "./db.js";
import { gemini, resultSchema } from "./gemini.js";
const slang = JSON.parse(
  readFileSync(new URL("./slang.json", import.meta.url), "utf8"),
);
const spellingAliases = JSON.parse(readFileSync(new URL('../../mobile/assets/spelling_aliases.json', import.meta.url), 'utf8'));
const normalize = (s) =>
  s
    .toLowerCase()
    .replace(/[‘’ʻʼ`´]/g, "'")
    .replace(/\s+/g, " ")
    .trim();
const textInput = z.object({
  text: z.string().trim().min(1).max(4000),
  source_language: z.enum(["en", "uz"]).default("en"),
  target_language: z.enum(["en", "uz"]).default("uz"),
  style: z.enum(["neutral", "formal", "informal"]).default("neutral"),
});
export function serviceRoutes(app, { c, db, sec, now, generate = gemini }) {
  let dictionary;
  const dict = () =>
    (dictionary ||= new DatabaseSync(c.dictionary, { readOnly: true }));
  let glosses = {},
    examples = {},
    sensePriority = {};
  try {
    glosses = JSON.parse(
      readFileSync(
        path.join(path.dirname(c.dictionary), "base_glosses.json"),
        "utf8",
      ),
    ).glosses;
    examples = JSON.parse(
      readFileSync(
        path.join(path.dirname(c.dictionary), "sense_examples.json"),
        "utf8",
      ),
    ).senses;
    sensePriority = JSON.parse(readFileSync(path.join(path.dirname(c.dictionary), "sense_priority.json"), "utf8")).first_senses;
  } catch {}
  const decorate = (w) => {
    if (!w) return null;
    const extra = db
      .prepare(
        "SELECT translation,explanation,source FROM supplements WHERE normalized=?",
      )
      .get(w.normalized || normalize(w.lemma));
    const editorial = slang[normalize(w.lemma)] || (['LEXORA original editorial','Lingoy original editorial','Lingoy AI definition-aligned editorial'].includes(w.translation_source) ? w.translation : '') || ['v','n','a','s','r'].map(pos => glosses[w.lemma+':'+pos]).find(Boolean);
    return {
      ...w,
      translation:
        editorial ||
        w.translation ||
        extra?.translation ||
        "",
      translation_source: slang[normalize(w.lemma)]
        ? "Lingoy original editorial"
        : w.translation_source || extra?.source || "",
      explanation: extra?.explanation || "",
    };
  };
  function word(id) {
    return decorate(
      dict().prepare("SELECT * FROM entries WHERE id=?").get(id) ||
        db.prepare("SELECT * FROM supplements WHERE id=?").get(id),
    );
  }
  const pending = new Map();
  async function ai(req, task, data) {
    if (!c.aiKey)
      throw new Failure(
        503,
        "ai_config",
        "Onlayn xizmat hali sozlanmagan. Lug‘at va oflayn grammatika ishlaydi.",
      );
    const owner = req.user?.id || "guest:" + sec.hmac(req.ip),
      key = sec.hmac(
        JSON.stringify({ owner, task, data, model: c.model, v: 1 }),
      );
    const cached = db
      .prepare("SELECT value FROM cache WHERE key=? AND expires>?")
      .get(key, now());
    if (cached) return { result: JSON.parse(cached.value), cached: true };
    if (pending.has(key))
      return { result: await pending.get(key), cached: true };
    const day = new Date(now()).toLocaleDateString("en-CA", {
        timeZone: "Asia/Tashkent",
      }),
      limit = req.user ? c.daily : 10;
    tx(db, () => {
      db.prepare("INSERT OR IGNORE INTO usage VALUES(?,?,0)").run(owner, day);
      if (
        !db
          .prepare("UPDATE usage SET n=n+1 WHERE user_id=? AND day=? AND n<?")
          .run(owner, day, limit).changes
      )
        throw new Failure(
          429,
          "daily_limit",
          `Bugungi ${limit} ta so‘rov limiti tugadi. Ertaga davom eting.`,
        );
    });
    const promise = Promise.resolve().then(async () => {
      try {
        const result = resultSchema.parse(await generate(c, task, data));
        db.prepare("INSERT OR REPLACE INTO cache VALUES(?,?,?)").run(
          key,
          JSON.stringify(result),
          now() + 86400000,
        );
        return result;
      } catch (e) {
        db.prepare(
          "UPDATE usage SET n=max(0,n-1) WHERE user_id=? AND day=?",
        ).run(owner, day);
        throw e;
      } finally {
        pending.delete(key);
      }
    });
    pending.set(key, promise);
    return { result: await promise, cached: false };
  }
  app.get("/api/v1/dictionary", (req, res) => {
    const p = z
        .object({
          q: z.string().max(160).default(""),
          reverse: z.enum(["0", "1"]).default("0"),
          offset: z.coerce.number().int().min(0).max(150000).default(0),
        })
        .parse(req.query),
      q = p.reverse === "1" ? normalize(p.q) : spellingAliases[normalize(p.q)] || normalize(p.q),
      tokens = q.match(/[a-z0-9]+(?:'[a-z]+)?/g) || [],
      fts = tokens.map((t) => '"' + t + '"*').join(" ");
    let rows = [];
    if (!q)
      rows = dict()
        .prepare(
          "SELECT * FROM entries WHERE translation<>'' ORDER BY CASE WHEN translation_source='LEXORA original editorial' THEN 0 ELSE 1 END,id LIMIT 40 OFFSET ?",
        )
        .all(p.offset);
    else if (fts) {
      const roots =
        p.reverse === "1"
          ? []
          : dict()
              .prepare("SELECT lemma FROM morph WHERE form=? LIMIT 12")
              .all(q)
              .map((r) => r.lemma);
      const clause = roots.length
        ? " OR normalized IN (" + roots.map(() => "?").join(",") + ")"
        : "";
      let translated = "lower(trim(translation))";
      for (const code of [8216,8217,699,700,96,697]) translated = `replace(${translated},char(${code}),char(39))`;
      const reverse = p.reverse === "1";
      const rank = reverse
        ? `CASE WHEN ${translated}=? OR ${translated} LIKE ? THEN 0 WHEN ${translated} LIKE ? OR ${translated} LIKE ? THEN 1 WHEN ${translated} LIKE ? THEN 2 ELSE 3 END`
        : "CASE WHEN normalized=? THEN 0 ELSE 1 END";
      rows = dict().prepare(
        `SELECT * FROM entries WHERE id IN (SELECT docid FROM search WHERE ${reverse ? "translation" : "lemma"} MATCH ?)${reverse ? "" : " OR normalized=?" + clause} ORDER BY ${rank},CASE WHEN translation_source IN ('LEXORA original editorial','Lingoy original editorial') THEN 0 WHEN level<>'' THEN 1 ELSE 2 END,CASE WHEN translation='' THEN 1 ELSE 0 END,length(lemma),id LIMIT 40 OFFSET ?`,
      ).all(fts,...(reverse ? [] : [q,...roots]),q,...(reverse ? [q+';%',q+' %',q+',%',q+'%'] : []),p.offset);
    }
    if (q && p.offset === 0 && p.reverse !== "1") {
      const extras = db
        .prepare("SELECT * FROM supplements WHERE normalized LIKE ? LIMIT 10")
        .all(q.replace(/[\\%_]/g, "") + "%");
      rows = [
        ...rows,
        ...extras.filter(
          (e) => !rows.some((r) => r.normalized === e.normalized),
        ),
      ];
    }
    res.json({ suggestions: !rows.length && p.reverse !== "1" ? suggestions(dict(), q).map(decorate) : [], words: rows.map(decorate), more: rows.length >= 40, correction: p.reverse === "1" ? null : spellingAliases[normalize(p.q)] || null });
  });
  app.get("/api/v1/dictionary/:id", (req, res) => {
    const id = z.coerce.number().int().positive().parse(req.params.id),
      w = word(id);
    if (!w) throw new Failure(404, "word", "So‘z topilmadi.");
    const senses =
      id >= 1000000000
        ? []
        : dict()
            .prepare(
              "SELECT s.* FROM senses s JOIN entry_senses e ON e.sense_id=s.id WHERE e.entry_id=? ORDER BY e.ordinal",
            )
            .all(id)
            .map((s) => ({
              ...s,
              meaning_uz: examples[s.id]?.meaning_uz || "",
              bilingual_examples: JSON.stringify(
                examples[s.id]?.examples || [],
              ),
            }));
    const groups = new Map();
    for (const s of senses) {
      if (!groups.has(s.pos)) groups.set(s.pos, []);
      groups.get(s.pos).push(s);
    }
    for (const group of groups.values()) {
      const preferred = sensePriority[normalize(w.lemma) + ':' + group[0].pos];
      const index = group.findIndex(s => s.id === preferred);
      if (index > 0) group.unshift(group.splice(index, 1)[0]);
    }
    const list=[...groups.values()],reviewed=g=>!!sensePriority[normalize(w.lemma)+':'+g[0].pos];
    const ordered=[...list.filter(reviewed),...list.filter(g=>!reviewed(g))];
    res.json({ word: w, senses: ordered.flat().map(s=>({...s,presentation:sensePresentation(w.lemma,s)})) });
  });
  const optionalAccount = (req, res, next) =>
    req.get("authorization") ? sec.auth(req, res, next) : next();
  app.post(
    "/api/v1/dictionary/translate",
    optionalAccount,
    async (req, res) => {
      const { text } = z
          .object({ text: z.string().trim().min(1).max(160) })
          .parse(req.body),
        q = spellingAliases[normalize(text)] || normalize(text),
        original = dict()
          .prepare("SELECT * FROM entries WHERE normalized=?")
          .get(q),
        known = decorate(
          original ||
            db.prepare("SELECT * FROM supplements WHERE normalized=?").get(q),
        );
      if (known?.translation) return res.json({ word: known, cached: true });
      let result;
      if (slang[q])
        result = {
          translation: slang[q],
          explanation:
            "Norasmiy inglizcha ibora. Ma’no gap kontekstiga qarab o‘zgarishi mumkin.",
        };
      else
        result = (
          await ai(req, "dictionary", {
            text,
            source_language: "en",
            target_language: "uz",
            style: "neutral",
          })
        ).result;
      if (!result.translation.trim())
        throw new Failure(
          502,
          "empty_translation",
          "Ma’no aniqlanmadi. So‘zni gap ichida tarjima qilib ko‘ring.",
        );
      db.prepare(
        "INSERT INTO supplements(normalized,lemma,translation,explanation,updated) VALUES(?,?,?,?,?) ON CONFLICT(normalized) DO UPDATE SET translation=excluded.translation,explanation=excluded.explanation,updated=excluded.updated",
      ).run(q, text, result.translation, result.explanation, now());
      const w = decorate(
        original ||
          db.prepare("SELECT * FROM supplements WHERE normalized=?").get(q),
      );
      res.json({ word: w, result });
    },
  );
  app.get("/api/v1/saved", sec.auth, (req, res) => {
    const since = z.coerce
      .number()
      .int()
      .min(0)
      .default(0)
      .parse(req.query.since);
    res.json({
      revision: req.user.revision,
      words: db
        .prepare(
          "SELECT word_id,deleted,revision FROM saved WHERE user_id=? AND revision>? ORDER BY revision",
        )
        .all(req.user.id, since),
    });
  });
  app.post("/api/v1/saved", sec.auth, (req, res) => {
    const p = z
      .object({
        changes: z
          .array(
            z.object({
              id: z.string().min(16).max(128),
              word_id: z.number().int().positive(),
              deleted: z.boolean(),
            }),
          )
          .max(500),
      })
      .parse(req.body);
    const result = tx(db, () => {
      const acknowledged = [];
      for (const v of p.changes) {
        if (
          db
            .prepare("SELECT id FROM mutations WHERE user_id=? AND id=?")
            .get(req.user.id, v.id)
        ) {
          acknowledged.push(v.id);
          continue;
        }
        if (!word(v.word_id))
          throw new Failure(400, "word", "Bunday so‘z lug‘atda yo‘q.");
        db.prepare("UPDATE users SET revision=revision+1 WHERE id=?").run(
          req.user.id,
        );
        const revision = db
          .prepare("SELECT revision FROM users WHERE id=?")
          .get(req.user.id).revision;
        db.prepare(
          "INSERT INTO saved VALUES(?,?,?,?) ON CONFLICT(user_id,word_id) DO UPDATE SET deleted=excluded.deleted,revision=excluded.revision",
        ).run(req.user.id, v.word_id, Number(v.deleted), revision);
        db.prepare("INSERT INTO mutations VALUES(?,?,?)").run(
          req.user.id,
          v.id,
          now(),
        );
        acknowledged.push(v.id);
      }
      return {
        acknowledged,
        revision: db
          .prepare("SELECT revision FROM users WHERE id=?")
          .get(req.user.id).revision,
      };
    });
    res.json(result);
  });
  app.post("/api/v1/translate", optionalAccount, async (req, res) =>
    res.json(await ai(req, "translation", textInput.parse(req.body))),
  );
  app.post("/api/v1/ai/translate", sec.auth, async (req, res) =>
    res.json(
      await ai(req, "contextual translation", textInput.parse(req.body)),
    ),
  );
  app.post("/api/v1/grammar", sec.auth, async (req, res) =>
    res.json(await ai(req, "grammar", textInput.parse(req.body))),
  );
  app.post("/api/v1/image/translate", sec.auth, async (req, res) => {
    const p = textInput
      .omit({ text: true })
      .extend({
        image: z
          .string()
          .max(4 * 1024 * 1024)
          .regex(/^[A-Za-z0-9+/]+={0,2}$/),
      })
      .parse(req.body);
    try {
      const s = sharp(Buffer.from(p.image, "base64"), {
          limitInputPixels: 20000000,
          animated: false,
        }),
        m = await s.metadata();
      if (!["jpeg", "png", "webp"].includes(m.format)) throw Error();
      p.image = (
        await s
          .rotate()
          .resize({
            width: 1600,
            height: 1600,
            fit: "inside",
            withoutEnlargement: true,
          })
          .jpeg({ quality: 80 })
          .toBuffer()
      ).toString("base64");
    } catch {
      throw new Failure(
        400,
        "image",
        "Yaroqli JPG, PNG yoki WebP rasm tanlang.",
      );
    }
    res.json(await ai(req, "image", p));
  });
  app.get("/api/v1/usage", sec.auth, (req, res) => {
    const day = new Date(now()).toLocaleDateString("en-CA", {
      timeZone: "Asia/Tashkent",
    });
    res.json({
      used:
        db
          .prepare("SELECT n FROM usage WHERE user_id=? AND day=?")
          .get(req.user.id, day)?.n || 0,
      limit: c.daily,
    });
  });
  app.get("/api/v1/downloads", (req, res) => {
    try {
      const f = path.join(c.downloads, "Lingoy.apk"),
        s = statSync(f);
      res.json({
        apk: "/downloads/Lingoy.apk",
        bytes: s.size,
        available: true,
      });
    } catch {
      res.json({ available: false, message: "APK fayli hali joylanmagan." });
    }
  });
  return () => dictionary?.close();
}
