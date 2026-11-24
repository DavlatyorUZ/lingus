import { makeBank, studyWord, selectMeaning, prepareSession } from "./study-game.js";
import { escapeHtml as esc } from "./domain.js";
let bankPromise;
// The build gives each quiz bank a content hash. An older installed service
// worker must never supply a previous release's meanings to the new UI.
const bankUrl = typeof __LINGOY_QUIZ_BANK_URL__ === 'string'
  ? __LINGOY_QUIZ_BANK_URL__ : '/data-quiz-bank.json';
const getBank = () =>
  (bankPromise ||= fetch(bankUrl)
    .then((r) => {
      if (!r.ok)
        throw Error(
          "Oflayn mashq ma’lumotlari yuklanmadi. Internetni tekshirib qayta urinib ko‘ring.",
        );
      return r.json();
    })
    .then(makeBank)
    .catch((e) => {
      bankPromise = null;
      throw e;
    }));

// Both modes use this selector, loop, and result renderer.
export function studyUI({
  modal,
  openModal,
  dialogVersion,
  search,
  lookup,
  saved,
  record,
  owner,
  main,
  back,
}) {
  let game = null;
  async function picker(mode, previous = []) {
    const account = owner();
    openModal(
      mode === "synonyms" ? "Sinonimlar" : "Tarjima",
      `<div class="study-picker"><div class="study-scroll"><label>So‘z yoki ibora<input id="study-query" placeholder="Qidirish…" autocomplete="off" maxlength="160"></label><div id="study-count" class="help">0 ta tanlandi · 30 tagacha</div><div id="study-selected" class="actions"></div><p class="error" id="study-error" role="alert"></p><div id="study-rows" class="study-rows">Tayyorlanmoqda…</div></div><div class="study-footer"><button id="study-start" class="primary" disabled>O‘yinni boshlash</button></div></div>`,
    );
    const version = dialogVersion(),
      current = () =>
        modal.open && dialogVersion() === version && owner() === account;
    const $ = (s) => modal.querySelector(s),
      selected = new Map(previous.map((w) => [w.id, w])),
      details = new Map(),
      expanded = new Set(),
      pending = new Map();
    let bank,
      words = [],
      queryGeneration = 0,
      timer,
      starting = false,
      prepared = null;
    function controls() {
      if (!current()) return;
      $("#study-count").textContent =
        `${selected.size} ta tanlandi · 30 tagacha`;
      $("#study-start").disabled = !selected.size || starting || !bank;
      $("#study-start").textContent = starting
        ? "Tayyorlanmoqda…"
        : "O‘yinni boshlash";
      $("#study-selected").innerHTML = [...selected.values()]
        .map(
          (w) =>
            `<button class="ghost" data-remove="${w.id}" aria-label="${esc(w.lemma)} tanlovini olib tashlash">${esc(w.lemma)} ×</button>`,
        )
        .join("");
    }
    function rows() {
      if (!current()) return;
      $("#study-rows").innerHTML = words.length
        ? words
            .map((w) => {
              const d = selected.get(w.id) || details.get(w.id),
                synonyms = (d?.choices || []).slice(0,6);
              const senses = d?.meanings?.length ? `<label class="study-sense-label">Mashq uchun ma’no<select data-sense="${w.id}">${d.meanings.map(s=>`<option value="${esc(s.id)}" ${s.id===d.senseId?'selected':''}>${esc(({v:'Fe’l',n:'Ot',a:'Sifat',s:'Sifat',r:'Ravish'})[s.pos]||s.pos)} · ${esc(s.context||s.definition)}</option>`).join('')}</select></label>` : '';
              return `<section class="study-word"><div class="row"><input type="checkbox" id="study-${w.id}" data-select="${w.id}" ${selected.has(w.id) ? "checked" : ""}><label for="study-${w.id}" class="grow"><strong>${esc(w.lemma)}</strong><span class="help">${esc((w.translation || "Tarjimasi hali yo‘q").split(';').slice(0,3).join('; '))}</span></label><button class="ghost" data-expand="${w.id}" aria-expanded="${expanded.has(w.id)}">Ma’nolar</button></div>${expanded.has(w.id) ? `<div class="study-synonyms">${!d ? "Yuklanmoqda…" : senses + (synonyms.length ? synonyms.map((s) => `<button class="ghost" data-syn="${esc(s)}">${esc(s)}</button>`).join("") : "Lug‘atdagi ma’nolarda sinonim bog‘lanmagan. Tarjima rejimida mashq qilishingiz mumkin.")}</div>` : ""}</section>`;
            })
            .join("")
        : '<div class="empty"><h3>So‘z topilmadi</h3><p class="help">Boshqa yozilish yoki qisqaroq so‘z bilan qidiring.</p></div>';
      controls();
    }
    async function detail(w) {
      if (details.has(w.id)) return details.get(w.id);
      if (pending.has(w.id)) return pending.get(w.id);
      const task = (async () => {
        let d;
        try {
          const r = await lookup(w.id);
          d = studyWord(r.word, r.senses);
        } catch (e) {
          d = bank?.byLemma.get(w.lemma);
          if (!d) throw e;
        }
        details.set(w.id, d);
        if (current()) rows();
        return d;
      })().finally(() => pending.delete(w.id));
      pending.set(w.id, task);
      return task;
    }
    async function toggle(w) {
      if (starting) return;
      if (selected.has(w.id)) {
        selected.delete(w.id);
        prepared = null;
        rows();
        return;
      }
      if (selected.size >= 30) {
        $("#study-error").textContent = "Bir turda 30 tagacha so‘z tanlang.";
        return;
      }
      try {
        const d = await detail(w);
        if (!current() || starting) return;
        if (mode === "synonyms" && !d.choices.length)
          throw Error("Bu so‘zga sinonim topilmadi. Tarjima rejimini tanlang.");
        if (!d.translation)
          throw Error("Avval lug‘at bo‘limida so‘zning ma’nosini aniqlang.");
        if (selected.size >= 30) return;
        selected.set(w.id, d);
        if (mode === "synonyms") expanded.add(w.id);
        prepared = null;
        $("#study-error").textContent = "";
        rows();
      } catch (e) {
        if (current()) {
          $("#study-error").textContent = e.message;
          rows();
        }
      }
    }
    async function load() {
      const generation = ++queryGeneration;
      try {
        const q = $("#study-query").value.trim();
        const result = q
          ? await search(q)
          : { words: saved() };
        if (!current() || generation !== queryGeneration) return;
        words = result.words;
        rows();
      } catch (e) {
        if (current() && generation === queryGeneration) {
          const q = $("#study-query").value.trim().toLowerCase();
          words = bank.entries.filter((w) => w.lemma.includes(q)).slice(0, 40);
          rows();
          $("#study-error").textContent =
            "Tarmoq mavjud emas. Qurilmadagi mashq ro‘yxati ko‘rsatilmoqda.";
        }
      }
    }
    $("#study-query").oninput = () => {
      queryGeneration++;
      clearTimeout(timer);
      timer = setTimeout(load, 230);
    };
    $("#study-selected").onclick = (e) => {
      const b = e.target.closest("[data-remove]");
      if (b && !starting) {
        selected.delete(Number(b.dataset.remove));
        prepared = null;
        rows();
      }
    };
    $("#study-rows").onchange = (e) => {
      if (e.target.dataset.sense && !starting) {
        const id = Number(e.target.dataset.sense);
        const d = selectMeaning(details.get(id), e.target.value);
        details.set(id,d);
        if (selected.has(id)) selected.set(id,d);
        prepared = null;
        rows();
        return;
      }
      const id = Number(e.target.dataset.select),
        w = words.find((w) => w.id === id);
      if (w) toggle(w);
    };
    $("#study-rows").onclick = async (e) => {
      const expand = e.target.closest("[data-expand]"),
        syn = e.target.closest("[data-syn]");
      try {
        if (expand) {
          const id = Number(expand.dataset.expand);
          if (expanded.has(id)) {
            expanded.delete(id);
            rows();
          } else {
            expanded.add(id);
            rows();
            await detail(words.find((w) => w.id === id));
          }
        }
        if (syn) {
          const q = syn.dataset.syn,
            w =
              bank.byLemma.get(q) ||
              (await search(q)).words.find((w) => w.lemma.toLowerCase() === q);
          if (!current()) return;
          if (!w) throw Error("Sinonimni lug‘atdan tekshirib ko‘ring.");
          await toggle(w);
        }
      } catch (e) {
        if (current()) $("#study-error").textContent = e.message;
      }
    };
    $("#study-start").onclick = async () => {
      if (starting || !selected.size || !bank) return;
      starting = true;
      controls();
      await new Promise((resolve) => requestAnimationFrame(resolve));
      if (!current()) return;
      try {
        const result =
          prepared || prepareSession(mode, [...selected.values()], bank);
        if (!result.questions.length)
          throw Error(
            "Yaqin va aniq variantlar yetarli emas. Boshqa so‘z yoki sinonim tanlang.",
          );
        if (result.skipped && !prepared) {
          prepared = result;
          $("#study-error").textContent =
            `${result.questions.length} ta savol tayyor. Takroriy yoki variant yetishmagan so‘zlar chiqarildi. Boshlash uchun yana bosing.`;
          return;
        }
        game = {
          mode,
          questions: result.questions,
          index: 0,
          answer: null,
          correct: 0,
          owner: account,
          selection: [...selected.values()],
        };
        modal.close();
        draw();
      } catch (e) {
        if (current()) $("#study-error").textContent = e.message;
      } finally {
        starting = false;
        controls();
      }
    };
    try {
      bank = await getBank();
      if (!current()) return;
      await load();
      controls();
    } catch (e) {
      if (current()) {
        $("#study-error").textContent = e.message;
        $("#study-rows").innerHTML =
          '<button id="study-retry" class="ghost">Qayta urinish</button>';
        $("#study-retry").onclick = () => picker(mode, [...selected.values()]);
      }
    }
  }
  function draw() {
    if (!game || owner() !== game.owner) {
      back();
      return;
    }
    const host = main(),
      q = game.questions[game.index];
    if (!q) {
      host.innerHTML = `<section class="card question stack"><span class="eyebrow">Natija</span><h1>${game.correct} / ${game.questions.length}</h1><p class="muted">${game.correct === game.questions.length ? "Barchasi to‘g‘ri. Yangi so‘zlar bilan davom eting." : "Adashgan so‘zlarni keyingi turda yana ko‘rib chiqing."}</p><button id="study-replay" class="primary">Qayta o‘ynash</button><button id="study-exit" class="ghost">Mashqlarga qaytish</button></section>`;
      host.querySelector("#study-replay").onclick = () =>
        picker(game.mode, game.selection);
      host.querySelector("#study-exit").onclick = back;
      return;
    }
    const answer = game.answer,
      chosen = answer === null ? null : q.options[answer];
    host.innerHTML = `<section class="card question stack"><div class="row between"><span class="pill">${game.index + 1} / ${game.questions.length}</span><button class="ghost" id="study-exit">Chiqish</button></div><p class="muted">${game.mode === "synonyms" ? "Sinonimini toping" : "Inglizchasini toping"}</p><h1>${esc(q.question)}</h1>${q.context ? `<p class="help">${esc(q.context)}</p>` : ""}<div class="options">${q.options.map((o, i) => `<button data-study-answer="${i}" ${answer !== null ? "disabled" : ""}>${esc(o.text)}</button>`).join("")}</div><div id="study-feedback" aria-live="polite">${chosen ? `${chosen.text !== q.correct ? `<p class="study-explanation">${esc(chosen.explanation)}</p>` : ""}<button class="primary" id="study-continue">Davom etish</button>` : ""}</div></section>`;
    host.querySelector("#study-exit").onclick = back;
    for (const b of host.querySelectorAll("[data-study-answer]"))
      b.onclick = () => {
        if (game.answer !== null || game.owner !== owner()) return;
        game.answer = Number(b.dataset.studyAnswer);
        const right = q.options[game.answer].text === q.correct;
        if (right) game.correct++;
        record(q.word, right);
        draw();
      };
    const next = host.querySelector("#study-continue");
    if (next)
      next.onclick = () => {
        game.index++;
        game.answer = null;
        draw();
      };
  }
  return { picker };
}
