import spellingAliases from "../../mobile/assets/spelling_aliases.json" with { type: "json" };
import dictionaryRevision from "../../mobile/assets/dictionary_revision.json" with { type: "json" };
import { api, user } from "./api.js";
import { normalize } from "./domain.js";
export const owner = () => user?.id || "guest";
export function state() {
  try {
    return (
      JSON.parse(localStorage.getItem("lingoy-state-" + owner())) || {
        saved: {},
        queue: {},
        events: [],
        folders: ["Mening so‘zlarim"],
        lessons: [],
      }
    );
  } catch {
    return {
      saved: {},
      queue: {},
      events: [],
      folders: ["Mening so‘zlarim"],
      lessons: [],
    };
  }
}
export function save(s, key = owner()) {
  localStorage.setItem("lingoy-state-" + key, JSON.stringify(s));
}
// Viewed words belong to the active account; searching alone never adds one.
export function recentViewed() { return state().recent || []; }
export function rememberViewed(word, account = owner()) {
  if (account !== owner()) return;
  const s = state();
  s.recent = [word, ...(s.recent || []).filter(w => w.id !== word.id)].slice(0, 30);
  try { save(s, account); return true; } catch { return false; }
}
export async function toggleWord(w) {
  const s = state(),
    deleted = !!s.saved[w.id];
  if (deleted) delete s.saved[w.id];
  else
    s.saved[w.id] = {
      ...w,
      added: Date.now(),
      due: Date.now(),
      folder: "Mening so‘zlarim",
    };
  if (user) s.queue[w.id] = { id: crypto.randomUUID(), word_id: w.id, deleted };
  save(s);
  sync().catch(() => {});
  return !deleted;
}
let syncing;
export function sync() {
  if (!user) return Promise.resolve();
  return (syncing ||= (async () => {
    const account = owner();
    while (owner() === account) {
      const changes = Object.values(state().queue).slice(0, 500);
      if (!changes.length) break;
      const r = await api("/saved", { method: "POST", body: { changes } });
      if (owner() !== account) return;
      const s = state();
      for (const c of changes)
        if (r.acknowledged.includes(c.id) && s.queue[c.word_id]?.id === c.id)
          delete s.queue[c.word_id];
      save(s, account);
    }
    const r = await api("/saved");
    if (owner() !== account) return;
    const details = [];
    for (const w of r.words) {
      if (w.deleted || state().saved[w.word_id] || state().queue[w.word_id])
        continue;
      try {
        details.push((await lookup(w.word_id)).word);
      } catch {}
    }
    if (owner() !== account) return;
    const s = state();
    for (const w of r.words)
      if (w.deleted && !s.queue[w.word_id]) delete s.saved[w.word_id];
    for (const w of details)
      if (!s.queue[w.id])
        s.saved[w.id] = {
          ...w,
          added: Date.now(),
          due: Date.now(),
          folder: "Mening so‘zlarim",
        };
    save(s, account);
  })().finally(() => (syncing = null)));
}
let dbPromise;
function db() {
  return (dbPromise ||= new Promise((resolve, reject) => {
    const r = indexedDB.open("lingoy-content-v3", 1);
    r.onupgradeneeded = () => {
      const d = r.result,
        w = d.createObjectStore("words", { keyPath: "id" });
      w.createIndex("normalized", "normalized");
      w.createIndex("translation", "translation");
      d.createObjectStore("details", { keyPath: "id" });
      d.createObjectStore("meta");
    };
    r.onsuccess = () => resolve(r.result);
    r.onerror = () => reject(r.error);
  }));
}
export async function lookup(id) {
  try {
    const r = await api("/dictionary/" + id);
    const d = await db();
    d.transaction("details", "readwrite")
      .objectStore("details")
      .put({ id, ...r });
    return r;
  } catch (e) {
    const d = await db();
    return new Promise((resolve, reject) => {
      const r = d.transaction("details").objectStore("details").get(id);
      r.onsuccess = () => (r.result ? resolve(r.result) : reject(e));
      r.onerror = () => reject(e);
    });
  }
}
export async function search(q = "", reverse = false, offset = 0) {
  const correction = reverse ? null : spellingAliases[normalize(q)];
  q = correction || q;
  try {
    const result = await api(
      `/dictionary?q=${encodeURIComponent(q)}&reverse=${reverse ? 1 : 0}&offset=${offset}`,
    );
    return { ...result, correction: correction || result.correction };
  } catch (e) {
    if (!(await installed())) throw e;
    const d = await db();
    return new Promise((resolve, reject) => {
      const words = [];
      let skip = offset;
      const t = normalize(q),
        index = d
          .transaction("words")
          .objectStore("words")
          .index(reverse ? "translation" : "normalized"),
        r = index.openCursor(t ? IDBKeyRange.bound(t, t + "\uffff") : null);
      r.onsuccess = () => {
        const c = r.result;
        if (!c || words.length === 40) {
          resolve({ words, more: words.length === 40, offline: true, correction });
          return;
        }
        if (skip) skip--;
        else words.push(c.value);
        c.continue();
      };
      r.onerror = () => reject(r.error);
    });
  }
}
export async function installed() {
  const d = await db();
  return new Promise((resolve) => {
    const r = d.transaction("meta").objectStore("meta").get("installed");
    r.onsuccess = () => resolve(!!r.result);
    r.onerror = () => resolve(false);
  });
}
export async function dictionaryUpdateAvailable() {
  if (!(await installed())) return false;
  const d = await db();
  return new Promise((resolve) => {
    const r = d.transaction("meta").objectStore("meta").get("dictionaryRevision");
    r.onsuccess = () => resolve(r.result !== dictionaryRevision.sha256 + ":meanings-v3");
    r.onerror = () => resolve(true);
  });
}
async function unzip(url) {
  const r = await fetch(url);
  if (!r.ok) throw Error("Lug‘at fayli yuklanmadi.");
  return new Response(
    r.body.pipeThrough(new DecompressionStream("gzip")),
  ).json();
}
export async function installDictionary(progress) {
  if (!("DecompressionStream" in window))
    throw Error("Brauzeringizni yangilang.");
  const d = await db();
  const response = await fetch("/data/offline-manifest.json", {
    cache: "no-store",
  });
  if (!response.ok) throw Error("Lug‘at ro‘yxati yuklanmadi.");
  const manifest = await response.json();
  let completed = 0;
  const total = manifest.packages.reduce((sum, item) => sum + item.count, 0);
  for (const item of manifest.packages) {
    progress(`Lug‘at yuklanmoqda: ${completed} / ${total}`);
    const rows = await unzip(item.url);
    for (let start = 0; start < rows.length; start += 500) {
      await new Promise((resolve, reject) => {
        const t = d.transaction(item.store, "readwrite");
        for (const row of rows.slice(start, start + 500))
          t.objectStore(item.store).put(row);
        t.oncomplete = resolve;
        t.onerror = () => reject(t.error);
        t.onabort = () =>
          reject(t.error || Error("Saqlash uchun qurilmada joy yetarli emas."));
      });
      completed += Math.min(500, rows.length - start);
      progress(`Saqlanmoqda: ${completed} / ${total}`);
    }
  }
  await new Promise((resolve, reject) => {
    const t = d.transaction("meta", "readwrite");
    t.objectStore("meta").put(true, "installed");
    t.objectStore("meta").put(manifest.dictionaryRevision || manifest.version, "dictionaryRevision");
    t.oncomplete = resolve;
    t.onerror = () => reject(t.error);
  });
  progress("Oflayn lug‘at tayyor.");
}
