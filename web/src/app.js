import { sensePresentation } from "../../server/src/lexical-presentation.js";
import {trackViewport} from "./viewport.js";
import { voiceSearch } from "./voice.js";
import { studyUI } from "./study-ui.js";
import { CameraSession, cameraError } from "./camera.js";
import { api, user, accept, restore, logout } from "./api.js";
import {
  state,
  recentViewed,
  rememberViewed,
  save,
  owner,
  toggleWord,
  sync,
  lookup,
  search,
  installed,
  dictionaryUpdateAvailable,
  installDictionary,
} from "./store.js";
import {
  normalize,
  escapeHtml as esc,
  csvCell,
  shuffle,
  gameWords,
  questions,
  reviewAfterGame,
  offlineGrammar,
} from "./domain.js";
const $ = (s, r = document) => r.querySelector(s);
const appVersion = typeof __LINGOY_VERSION__ === 'string' ? __LINGOY_VERSION__ : 'development';
const paths = {
  mic: "M12 15a3 3 0 0 0 3-3V5a3 3 0 0 0-6 0v7a3 3 0 0 0 3 3ZM5 10v2a7 7 0 0 0 14 0v-2M12 19v3m-4 0h8",
  home: "m3 10 9-7 9 7v10a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1z",
  search: "M21 21l-5-5M19 10a9 9 0 1 1-18 0 9 9 0 0 1 18 0",
  book: "M3 3h7a2 2 0 0 1 2 2v16a4 4 0 0 0-4-2H3zM21 3h-7a2 2 0 0 0-2 2v16a4 4 0 0 1 4-2h5z",
  game: "m12 3 9 9-9 9-9-9zM9 9l6 6m0-6-6 6",
  user: "M20 21v-2a7 7 0 0 0-14 0v2M16 7a4 4 0 1 1-8 0 4 4 0 0 1 8 0",
  arrow: "M5 12h14m-5-5 5 5-5 5",
  translate:
    "M4 5h12M10 3v2m-4 4c1 4 4 6 8 8m0-12c0 5-4 10-10 12m10 4 4-10 4 10m-6-3h4",
  spark: "m12 3 2.7 6.3L21 12l-6.3 2.7L12 21l-2.7-6.3L3 12l6.3-2.7z",
  camera: "M9 3h6l2 3h4v15H3V6h4zM16 13a4 4 0 1 1-8 0 4 4 0 0 1 8 0",
  image: "M4 4h16v16H4zM4 16l5-5 4 4 3-3 4 4M9 8h.01",
  check: "m5 12 4 4L19 6",
  download: "M12 3v12m-5-5 5 5 5-5M4 17v4h16v-4",
  moon: "M20 15a9 9 0 0 1-11-11 9 9 0 1 0 11 11",
  sun: "M12 3V1m0 22v-2M3 12H1m22 0h-2M5 5 3.5 3.5M20.5 20.5 19 19M5 19l-1.5 1.5M20.5 3.5 19 5M17 12a5 5 0 1 1-10 0 5 5 0 0 1 10 0",
  star: "m12 3 2.8 5.7 6.3.9-4.5 4.4 1.1 6.2-5.7-3-5.7 3 1.1-6.2-4.5-4.4 6.3-.9z",
  sound: "m11 5-6 4H2v6h3l6 4zM15 8a5 5 0 0 1 0 8m3-11a9 9 0 0 1 0 14",
  close: "m6 6 12 12M6 18 18 6",
  clock: "M12 7v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0",
  folder: "M3 5h6l2 3h10v12H3z",
  help: "M9 9a3 3 0 1 1 5 2c-2 1-2 2-2 3m0 3h.01M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0",
};
const icon = (name, size = 20) =>
  `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="${paths[name] || paths.book}"/></svg>`;
const nav = [
  ["home", "home", "Asosiy"],
  ["dictionary", "search", "Lug‘at"],
  ["saved", "book", "So‘zlarim"],
  ["games", "game", "Mashqlar"],
  ["profile", "user", "Profil"],
];
const tools = [
  ["translate", "translate", "Matn tarjimasi", "Bir fikr, ikki til."],
  ["ai", "spark", "AI tarjima", "Kontekst va tabiiy ma’no."],
  ["image", "image", "Rasm tarjimasi", "Rasmdagi matnni tushuning."],
  ["grammar", "check", "Grammatika", "Xatoni toping, sababini biling."],
];
let route = location.hash.slice(1) || "home",
  runId = 0,
  theme = localStorage.getItem("lingoy-theme") || "light",
  words = [],
  query = "",
  reverse = false,
  searchTimer,
  game,
  photoMap = {},
  essentials = [],
  lessons = [],
  deferredInstall,
  folder = "Barchasi",
  modalVersion = 0;
document.body.classList.toggle("dark", theme === "dark");
const root = $("#app"),
  modal = $("#modal");
function toast(text) {
  const e = $("#toast");
  e.textContent = text;
  e.classList.add("visible");
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => e.classList.remove("visible"), 3500);
}
function go(page) {
  if (route === page) render();
  else location.hash = page;
}
function navHtml(mobile = false) {
  return nav
    .map(
      ([id, i, title]) =>
        `<button data-nav="${id}" class="${route === id ? "active" : ""}" title="${title}" aria-label="${title}" ${route === id ? 'aria-current="page"' : ""}>${icon(i)}${mobile ? "" : `<span>${title}</span>`}</button>`,
    )
    .join("");
}
function shell() {
  // Keep global controls mounted: route content must not move or recreate them.
  if (!root.querySelector('.layout')) {
    root.innerHTML = `<div class="layout"><header class="topbar"><button class="brand header-brand" data-nav="home" aria-label="Lingoy bosh sahifasi"><img src="/icons/lingoy-192.png" alt="" width="42" height="42"><span>Lingoy</span></button><div class="header-message">Har bir so‘z — yangi imkoniyat</div><div class="header-actions"><button class="icon ghost" data-action="theme" aria-label="Rang rejimini almashtirish"></button><button class="header-account ghost" data-nav="profile">Kirish</button></div></header><aside class="sidebar"><div class="brand-sub">O‘rganish uchun sizning joyingiz</div><nav aria-label="Asosiy menyu"></nav><div class="side-bottom"><p class="muted">Har kuni ozgina.<br>Har safar ishonchliroq.</p><a class="button ghost" href="/downloads/Lingoy.apk" download>${icon("download", 16)} Android ilovasi</a><p><a href="https://t.me/davlatyoruz" target="_blank" rel="noopener">Yordam xizmati</a></p></div></aside><div class="workspace"><main id="main" class="stack" tabindex="-1"></main></div><nav class="bottom-nav" aria-label="Mobil menyu"></nav></div>`;
  }
  $('.sidebar nav').innerHTML = navHtml();
  $('.bottom-nav').innerHTML = navHtml(true);
  const themeButton = $('[data-action="theme"]');
  themeButton.innerHTML = icon(theme === 'dark' ? 'sun' : 'moon', 20);
  themeButton.setAttribute('aria-pressed', String(theme === 'dark'));
  const accountButton = $('.header-account');
  if (user) {
    accountButton.dataset.nav = 'profile';
    delete accountButton.dataset.action;
  } else {
    accountButton.dataset.action = 'login';
    delete accountButton.dataset.nav;
  }
  accountButton.innerHTML = user
    ? `${icon('user',18)}<span>Profil</span>`
    : `<span>Kirish</span>`;
  accountButton.setAttribute('aria-label', user ? 'Profilni ochish' : 'Kirish');
  const main = $('#main');
  main.className = 'stack';
  void main.offsetWidth;
  main.classList.add('page-enter');
}

function empty(title, text, button = "Lug‘atni ochish", page = "dictionary") {
  return `<div class="empty"><div class="empty-icon">${icon("book", 38)}</div><h2>${esc(title)}</h2><p>${esc(text)}</p><button class="primary" data-nav="${page}">${esc(button)}</button></div>`;
}
function picture(w) {
  const src = photoMap[normalize(w)];
  return typeof src === "string" && src.startsWith("/assets/") ? src : null;
}
function rows(list) {
  const saved = state().saved;
  return list
    .map(
      (w) =>
        `<div class="word-row">${picture(w.lemma) ? `<img src="${esc(picture(w.lemma))}" alt="" loading="lazy">` : ""}<button class="open-word" data-word="${w.id}"><h3>${esc(w.lemma)}</h3><p>${esc((w.translation || "Ma’nosini aniqlash").split(";").slice(0,3).join("; "))}${w.ipa ? " · " + esc(w.ipa) : ""}</p></button><button class="save-btn ${saved[w.id] ? "selected" : ""}" data-save="${w.id}" aria-label="${saved[w.id] ? "Saqlanganlardan olib tashlash" : "So‘zni saqlash"}" aria-pressed="${!!saved[w.id]}">${icon("star", 21)}</button></div>`,
    )
    .join("");
}
function stats() {
  const s = state(),
    total = s.events.length,
    correct = s.events.filter((e) => e.correct).length,
    today = s.events.filter(
      (e) => e.day === new Date().toLocaleDateString("en-CA"),
    ).length;
  return { total, correct, today, saved: Object.keys(s.saved).length };
}
function toolCards() {
  return `<div class="tool-grid">${tools.map(([id, i, title, desc]) => `<button class="tool" data-nav="${id}"><span class="glyph">${icon(i, 23)}</span><div style="width:100%"><div class="title-row"><h3>${title}</h3></div><p>${desc}</p></div></button>`).join("")}</div>`;
}
function render() {
  activeVoice?.cancel();
  $('#main')?.classList.remove('dictionary-page');
  stopCamera();
  runId++;
  clearInterval(game?.timer);
  game = null;
  shell();
  const main = $("#main");
  if (route === "home") home(main);
  else if (route === "dictionary") dictionary(main);
  else if (route === "saved") savedPage(main);
  else if (route === "games") games(main);
  else if (route === "profile") profile(main);
  else if (tools.some((t) => t[0] === route)) tool(main);
  else if (route === "lessons") lessonsPage(main);
  else if (["daily", "speaking", "pictures"].includes(route)) collection(main);
  else {
    route = "home";
    home(main);
  }
  window.scrollTo({ top: 0, behavior: "instant" });
}
function home(main) {
  const s = stats();
  main.innerHTML = `<form id="home-search" class="home-search" role="search"><label class="sr-only" for="home-query">Lug‘atdan izlash</label>${icon('search',22)}<input id="home-query" placeholder="So‘z yoki ibora…" maxlength="160" autocomplete="off" enterkeyhint="search"><button class="gold" aria-label="Lug‘atdan qidirish">Izlash</button></form><section class="card hero"><div class="hero-copy"><div class="eyebrow" style="color:#d5bf93">Bugungi kichik qadam</div><h1>Yangi so‘zlar.<br>Kengroq dunyo.</h1><p>Ma’noni tushuning, o‘zingizga saqlang.<br>Keyin o‘yin orqali eslab qoling.</p><div class="actions"><button class="gold" data-nav="dictionary">So‘z izlash </button><button class="ghost" style="color:#e1d8e7;border-color:#ffffff30" data-nav="games">Mashq qilish</button></div></div><div class="daily-card"><div class="phrase-stamp" aria-hidden="true">EN <span>·</span> UZ</div><div class="line"></div><span class="eyebrow" style="color:#bbb0c3">Bugungi ibora</span><h2>a fresh start</h2><p>yangi boshlanish</p><small>“Every day is a fresh start.”</small></div></section><section><div class="section-head"><h2>Til uchun vositalar</h2><span class="pill">EN ${icon("translate", 13)} UZ</span></div>${toolCards()}</section><div class="stats">${[
    [s.saved, "saqlangan so‘z", "book"],
    [s.today, "bugungi mashq", "clock"],
    [
      s.total ? Math.round((s.correct / s.total) * 100) + "%" : "—",
      "javoblar aniqligi",
      "check",
    ],
  ]
    .map(
      ([n, l, i]) =>
        `<div class="card stat"><span class="stat-icon">${icon(i, 22)}</span><div><strong>${n}</strong><small>${l}</small></div></div>`,
    )
    .join(
      "",
    )}</div><section><div class="section-head"><h2>O‘rganishni davom ettiring</h2></div><div class="grid three">${[
    [
      "daily",
      "book",
      "Kundalik so‘zlar",
      "Hayotda tez-tez kerak bo‘ladigan so‘zlar.",
    ],
    [
      "speaking",
      "sound",
      "Speaking iboralari",
      "Suhbatga tayyor gap qoliplari.",
    ],
    [
      "lessons",
      "check",
      "Grammatika darslari",
      "Qoida, misol va kichik sinov.",
    ],
    ["pictures", "image", "Rasmli lug‘at", "Ko‘rib o‘rganing, eslab qoling."],
  ]
    .map(
      ([id, i, t, d]) =>
        `<button class="tool" data-nav="${id}"><span class="glyph">${icon(i)}</span><div><h3>${t}</h3><p>${d}</p></div></button>`,
    )
    .join("")}</div></section>`;
  $('#home-search').onsubmit = (event) => {
    event.preventDefault();
    query = $('#home-query').value.trim();
    reverse = false;
    go('dictionary');
  };
}
let activeVoice;
function dictionary(main) {
  main.classList.add('dictionary-page');
  main.innerHTML = `<h1>Lug‘at</h1><div class="tool-shortcuts">${tools.map(([page,glyph,label])=>`<button class="ghost" data-nav="${page}">${icon(glyph,17)}${esc(label.replace(' tarjimasi','').replace(' tarjima',''))}</button>`).join('')}</div><div id="results"></div><button id="more" class="ghost" hidden>Yana ko‘rsatish</button><div class="search-position"><form id="search-form" class="search-capsule" role="search"><button class="icon" aria-label="Qidirish">${icon('search')}</button><input id="query" aria-label="Lug‘atdan izlash" placeholder="So‘z qidiring" value="${esc(query)}" maxlength="160" autocomplete="off" enterkeyhint="search"><button type="button" id="voice-search" class="icon" aria-label="Ovozli qidiruv">${icon('mic')}</button><div class="language-segments" role="group" aria-label="Qidiruv tili"><button type="button" data-lang="en" aria-pressed="${!reverse}">EN</button><button type="button" data-lang="uz" aria-pressed="${reverse}">UZ</button></div></form><div id="voice-status" class="sr-only" role="status"></div></div>`;
  $('#search-form').onsubmit = event => { event.preventDefault(); $('#query').blur(); loadSearch(false, true); };
  $('#query').oninput = () => {
    query = $('#query').value;
    ++runId;
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => loadSearch(), 260);
  };
  main.querySelectorAll('[data-lang]').forEach(button => button.onclick = () => {
    activeVoice?.cancel();
    reverse = button.dataset.lang === 'uz';
    main.querySelectorAll('[data-lang]').forEach(b=>b.setAttribute('aria-pressed', String((b.dataset.lang==='uz')===reverse)));
    loadSearch();
  });
  $('#voice-search').onclick = async () => {
    if (activeVoice) { activeVoice.cancel(); return; }
    const account = owner(), button = $('#voice-search');
    try {
      activeVoice = voiceSearch(reverse);
      button.classList.add('listening'); button.setAttribute('aria-label','Tinglashni to‘xtatish');
      $('#voice-status').textContent = 'Tinglanmoqda. So‘z yoki iborani ayting.';
      const text = await activeVoice.result;
      if (route !== 'dictionary' || owner() !== account || !text) return;
      query = text; $('#query').value = text;
      await loadSearch();
    } catch(e) { if (route === 'dictionary') toast(e.message); }
    finally { activeVoice = null; button.classList.remove('listening'); button.setAttribute('aria-label','Ovozli qidiruv'); }
  };
  $('#more').onclick = () => loadSearch(true);
  loadSearch();
}
async function loadSearch(append = false, fill = false) {
  if (!$("#query")) return;
  query = $("#query").value;
  const generation = ++runId;
  try {
    const isRecent = !query.trim();
    const result = isRecent ? {words: recentViewed(), more: false} : await search(query, reverse, append ? words.length : 0);
    if (generation !== runId || route !== "dictionary") return;
    words = append ? [...words, ...result.words] : result.words;
    $("#results").innerHTML = words.length
      ? `${isRecent ? '<h2 class="recent-heading">Yaqinda ko‘rilgan</h2>' : ''}${rows(words)}`
      : isRecent ? `<div class="empty recent-empty"><div class="empty-icon">${icon("clock",32)}</div><h2>Qaysi so‘zni o‘rganamiz?</h2><p>Pastdan so‘z izlang. Ma’nosini ochgan so‘zlaringiz shu yerda qoladi.</p></div>` : `<div class="empty"><div class="empty-icon">${icon("search", 34)}</div><h2>Bu ibora hali lug‘atda yo‘q</h2><p>Norasmiy iboralar va yangi so‘zlarning ma’nosini kontekst bilan aniqlaymiz.</p><button class="primary" data-action="fill-word">Ma’nosini aniqlash</button><p id="fill-error" class="error"></p></div>`;
    if (!words.length && result.suggestions?.length) $("#results").insertAdjacentHTML("afterbegin", `<p class="help">Shuni nazarda tutdingizmi?</p><div class="actions">${result.suggestions.map(w=>`<button class="ghost" data-correction="${esc(w.lemma)}">${esc(w.lemma)}</button>`).join('')}</div>`);
    if (result.correction) $("#results").insertAdjacentHTML("afterbegin", `<p class="help">To‘g‘ri yozilishi: ${esc(result.correction)}</p>`);
    $("#more").hidden = !result.more;
    if (fill && query.trim() && !words.length && !reverse) await fillWord(query, generation);
    if (result.offline) toast("Oflayn lug‘atdan qidirildi.");
  } catch (e) {
    if (generation === runId && $("#results"))
      $("#results").innerHTML =
        `<p class="error">${esc(e.message)}</p><p class="help">Profil orqali oflayn lug‘atni oldindan yuklab olishingiz mumkin.</p>`;
  }
}
async function fillWord(text, generation = runId) {
  const b = $('[data-action="fill-word"]');
  if (b) {
    b.disabled = true;
    b.textContent = "Ma’nosi aniqlanmoqda…";
  }
  try {
    const p = await api("/dictionary/translate", {
      method: "POST",
      body: { text },
    });
    if (generation !== runId) return;
    words = [p.word];
    $("#results").innerHTML =
      rows(words) +
      `<p class="help">${esc(p.word.explanation || "Tarjima lug‘atga qo‘shildi.")}</p>`;
  } catch (e) {
    if (generation === runId) {
      if ($("#fill-error")) $("#fill-error").textContent = e.message;
      else toast(e.message);
      if (b) {
        b.disabled = false;
        b.textContent = "Qayta urinish";
      }
    }
  }
}
function savedPage(main) {
  const s = state(),
    all = Object.values(s.saved),
    list = folder === "Barchasi" ? all : all.filter((w) => w.folder === folder);
  words = list;
  main.innerHTML = `<div class="row between wrap-mobile"><div><h1>So‘zlarim</h1><p class="muted" style="margin-top:9px">${user ? "Akkauntingiz bilan sinxronlanadi." : "Ushbu qurilmada saqlanadi."}</p></div><button class="primary" data-nav="games">Mashq qilish </button></div><div class="row wrap"><select id="folder-filter" style="max-width:200px" aria-label="Papka">${["Barchasi", ...s.folders].map((f) => `<option ${f === folder ? "selected" : ""}>${esc(f)}</option>`).join("")}</select><button class="ghost" data-action="folder">+ Papka</button><button class="ghost" data-action="export">CSV eksport</button><button class="ghost" data-action="import">CSV import</button>${user ? '<button class="ghost" data-action="sync">Sinxronlash</button>' : ""}</div>${list.length ? `<div class="card">${rows(list)}</div>` : empty("Hali so‘z yo‘q", "Yoqtirgan so‘zingiz yonidagi yulduzni bosing. Keyingi mashqlar shu so‘zlardan tuziladi.")}`;
  $("#folder-filter").onchange = (e) => {
    folder = e.target.value;
    savedPage(main);
  };
}
const study = studyUI({modal, openModal, dialogVersion:()=>modalVersion, search, lookup, saved:()=>Object.values(state().saved), record, owner, main:()=>$("#main"), back:()=>go("games")});
function games(main) {
  const count = gameWords(Object.values(state().saved)).length;
  main.innerHTML = `<div><h1>Bir so‘z. Ikki mashq.</h1><p class="muted" style="margin-top:12px">So‘zlarni o‘zingiz tanlang. Ma’no va imloni birga mustahkamlang.</p></div><div class="grid"><button class="tool" data-study="synonyms"><span class="glyph">${icon("book")}</span><div><h3>Sinonimlar</h3><p>Yaqin yozilish, boshqa ma’no.</p></div></button><button class="tool" data-study="translate"><span class="glyph">${icon("translate")}</span><div><h3>Tarjima</h3><p>O‘zbekchadan inglizchaga · imlo va ma’no.</p></div></button></div><h2>Boshqa mashqlar</h2>${
    count < 4
      ? empty(
          "Avval so‘z saqlang",
          "Boshlash uchun kamida 4 ta ma’nosi turlicha so‘z saqlang.",
        )
      : `<span class="pill">${count} ta so‘z mashq uchun tayyor</span><div class="grid three">${[
          ["quiz", "spark", "Tarjimani toping"],
          ["spelling", "book", "So‘zni yozing"],
          ["listening", "sound", "Tinglab toping"],
          ["pairs", "game", "Juftini toping"],
          ["sprint", "clock", "60 soniyalik sprint"],
          ["pictures", "image", "Rasm bilan eslang"],
          ["flashcards", "folder", "Takrorlash kartalari"],
        ]
          .map(
            ([mode, i, title]) =>
              `<button class="tool" data-game="${mode}"><span class="glyph">${icon(i, 23)}</span><div><h3>${title}</h3><p>Shaxsiy lug‘atingiz bilan mashq.</p></div></button>`,
          )
          .join("")}</div>`
  }`;
  main.querySelectorAll("[data-study]").forEach(b => b.onclick = () => study.picker(b.dataset.study));
}
function record(w, correct) {
  const s = state();
  s.events.push({
    id: w.id,
    correct,
    at: Date.now(),
    day: new Date().toLocaleDateString("en-CA"),
  });
  s.events = s.events.slice(-10000);
  if (s.saved[w.id])
    Object.assign(s.saved[w.id], reviewAfterGame(s.saved[w.id], correct));
  save(s);
}
function startGame(mode) {
  clearInterval(game?.timer);
  const q = questions(
    Object.values(state().saved),
    mode === "sprint" ? 80 : 10,
  );
  if (!q.length) {
    toast("Avval kamida 4 ta turli ma’noli so‘z saqlang.");
    return;
  }
  game = {
    mode,
    q,
    index: 0,
    correct: 0,
    answered: false,
    missed: [],
    left: 60,
    owner: owner(),
  };
  if (mode === "pairs") {
    game.pairs = shuffle(gameWords(Object.values(state().saved))).slice(0, 4);
    game.cards = shuffle(
      game.pairs.flatMap((w, id) => [
        { id, text: w.lemma, side: 0 },
        { id, text: w.translation, side: 1 },
      ]),
    );
    game.matched = [];
    game.first = null;
  }
  if (mode === "sprint")
    game.timer = setInterval(() => {
      if (!game || owner() !== game.owner || route !== "games") {
        clearInterval(game?.timer);
        return;
      }
      game.left--;
      if (game.left <= 0) finish();
      else if ($("#game-time")) $("#game-time").textContent = game.left + " s";
    }, 1000);
  drawGame();
}
function drawGame() {
  if (!game) return;
  if (game.mode === "pairs") {
    drawPairs();
    return;
  }
  const q = game.q[game.index];
  if (!q) {
    finish();
    return;
  }
  const w = q.word,
    m = game.mode;
  $("#main").innerHTML =
    `<div class="row between"><button class="ghost" data-action="end-game">Mashqlarga qaytish</button><span class="pill" id="game-time">${m === "sprint" ? game.left + " s" : game.index + 1 + " / " + game.q.length}</span></div><section class="card question"><span class="eyebrow muted">Eslab qolish mashqi</span>${m === "pictures" && picture(w.lemma) ? `<img src="${esc(picture(w.lemma))}" alt="So‘z tasviri">` : ""}<h2>${esc(m === "listening" ? "Tinglang va ma’nosini toping" : m === "spelling" ? w.translation : w.lemma)}</h2><button class="ghost" data-speak="${esc(w.lemma)}">${icon("sound", 16)} Talaffuz</button>${m === "spelling" ? '<form class="form" id="answer-form"><label>Inglizcha javob<input id="spelling" autocomplete="off" autocapitalize="none" required></label><button class="primary">Tekshirish</button></form>' : m === "flashcards" ? '<div class="actions" style="justify-content:center"><button class="primary" data-action="reveal">Ma’nosini ko‘rish</button></div>' : `<div class="options">${q.options.map((o) => `<button data-answer="${o.id}">${esc(o.translation)}</button>`).join("")}</div>`}<div id="feedback" class="stack" style="margin-top:20px" aria-live="polite"></div></section>`;
  if (m === "spelling")
    $("#answer-form").onsubmit = (e) => {
      e.preventDefault();
      answer(normalize($("#spelling").value) === normalize(w.lemma));
    };
}
function answer(correct, selected) {
  if (!game || game.answered || game.owner !== owner()) return;
  game.answered = true;
  const w = game.q[game.index].word;
  if (correct) game.correct++;
  else game.missed.push(w);
  record(w, correct);
  document.querySelectorAll("[data-answer]").forEach((b) => {
    b.disabled = true;
    if (Number(b.dataset.answer) === w.id) b.classList.add("correct");
    else if (Number(b.dataset.answer) === selected) b.classList.add("wrong");
  });
  $("#feedback").innerHTML =
    `<p class="${correct ? "success" : "error"}">${correct ? "To‘g‘ri!" : "To‘g‘ri javob: " + esc(w.lemma) + " — " + esc(w.translation)}</p><button class="primary" data-action="next">Davom etish </button>`;
}
function finish() {
  if (!game) return;
  clearInterval(game.timer);
  const total = game.index + (game.answered ? 1 : 0);
  $("#main").innerHTML =
    `<section class="card question"><div class="eyebrow muted">Bugungi qadam bajarildi</div><h1 style="margin:25px 0">${game.correct} / ${total}</h1><p class="muted">Har bir urinish xotirangizni mustahkamlaydi.</p><div class="actions" style="justify-content:center"><button class="primary" data-game="${game.mode}">Yana bir tur</button><button class="ghost" data-action="end-game">Mashqlarga qaytish</button></div></section>${game.missed.length ? `<section class="card"><h2>Yana bir qarab chiqing</h2>${rows(game.missed)}</section>` : ""}`;
}
function drawPairs() {
  $("#main").innerHTML =
    `<div class="row between"><button class="ghost" data-action="end-game">Mashqlarga qaytish</button><span class="pill">${game.matched.length} / 4 juftlik</span></div><section class="card"><h2>Bir so‘z. Ikki til.</h2><p class="muted">Inglizcha so‘z va uning ma’nosini tanlang.</p><div class="options">${game.cards.map((c, i) => `<button data-pair="${i}" ${game.matched.includes(c.id) ? 'disabled class="correct"' : game.first === i ? 'style="outline:2px solid var(--accent)"' : ""}>${esc(c.text)}</button>`).join("")}</div></section>`;
}
async function pair(i) {
  const round = game;
  if (!round || round.owner !== owner() || !round.cards[i]) return;
  if (game.busy || game.matched.includes(game.cards[i].id)) return;
  if (game.first === null) {
    game.first = i;
    drawPairs();
    return;
  }
  const a = game.cards[game.first],
    b = game.cards[i];
  if (game.first === i) return;
  game.busy = true;
  const correct = a.id === b.id && a.side !== b.side;
  record(game.pairs[a.id], correct);
  if (correct) {
    game.matched.push(a.id);
    game.correct++;
  } else {
    toast("Mos kelmadi. Qayta urinib ko‘ring.");
    await new Promise((r) => setTimeout(r, 450));
  }
  if (game !== round || round.owner !== owner() || route !== "games") return;
  game.first = null;
  game.busy = false;
  if (game.matched.length === 4) {
    game.index = 4;
    finish();
  } else drawPairs();
}
let cameraSession = null;
let releasePhotoPreview = () => {};
function stopCamera() {
  const active = cameraSession;
  active?.stop();
  cameraSession = null;
  if (active && modal.open) modal.close();
  releasePhotoPreview();
  releasePhotoPreview = () => {};
}
function tool(main) {
  let selectedImage = null;
  const photoGeneration = runId;
  const currentPhotoView = () => route === "image" && photoGeneration === runId;
  const selectPhoto = (file) => {
    if (!file || !currentPhotoView()) return;
    if (!/^image\/(jpeg|png|webp|heic|heif)$/.test(file.type) || file.size > 10 * 1024 * 1024) {
      $("#tool-error").textContent = "10 MB gacha JPG, PNG yoki WebP rasm tanlang.";
      return;
    }
    releasePhotoPreview();
    selectedImage = file;
    const url = URL.createObjectURL(file), image = $("#image-preview");
    releasePhotoPreview = () => URL.revokeObjectURL(url);
    image.src = url;
    image.hidden = false;
    $("#remove-photo").hidden = false;
    $("#tool-error").textContent = "";
    $("#tool-result").innerHTML = "";
  };
  const t = tools.find((t) => t[0] === route),
    isImage = route === "image",
    grammar = route === "grammar";
  main.innerHTML = `<div><h1>${t[2]}</h1><p class="muted" style="margin-top:11px">${grammar ? "Fikringizni aniq va to‘g‘ri ifodalang." : "So‘zma-so‘z emas, ma’nosiga mos tarjima."}</p></div><section class="card"><form id="tool-form" class="stack">${!grammar ? '<div class="row"><select id="lang" aria-label="Tarjima yo‘nalishi"><option value="en" aria-label="Inglizchadan o‘zbekchaga">EN/UZ</option><option value="uz" aria-label="O‘zbekchadan inglizchaga">UZ/EN</option></select>' + (route === "ai" ? '<select id="style" aria-label="Uslub"><option value="neutral">Tabiiy</option><option value="formal">Rasmiy</option><option value="informal">Norasmiy</option></select>' : "") + "</div>" : ""}${isImage ? `<div class="actions image-actions"><button type="button" class="primary" id="take-photo">${icon("camera", 19)} Suratga olish</button><button type="button" class="ghost" id="pick-photo">${icon("image", 19)} Galereyadan</button><input type="file" id="image-file" accept="image/*" hidden aria-label="Galereyadan rasm tanlash"><input type="file" id="camera-file" accept="image/*" capture="environment" hidden aria-label="Kameradan surat olish"></div><p class="help">Matnni yorug‘ joyda, tekis va to‘liq kadrlang. Surat faqat «Tarjima qilish» bosilganda yuboriladi.</p><img id="image-preview" class="photo-preview" hidden alt="Tarjima uchun tanlangan rasm"><button type="button" class="ghost" id="remove-photo" hidden>Rasmni olib tashlash</button>` : `<label for="source-text" class="muted">${grammar ? "Inglizcha matn" : "Tarjima qilinadigan matn"}</label><textarea id="source-text" maxlength="4000" placeholder="Matnni shu yerga yozing…" required></textarea>`}<p class="help">Yuborilganda matn yoki rasm tarjima xizmatiga uzatiladi. ${route === "translate" ? "" : "Onlayn xizmat uchun akkaunt kerak."}</p><div class="row wrap"><button class="primary" id="tool-submit">${grammar ? "Tekshirish" : "Tarjima qilish"} </button>${grammar ? '<button type="button" class="ghost" data-action="offline-grammar">Oflayn tekshirish</button>' : ""}</div><p class="error" id="tool-error" role="alert"></p></form></section><div id="tool-result"></div>`;
  $("#tool-form").onsubmit = async (e) => {
    e.preventDefault();
    if (route !== "translate" && !user) {
      authDialog();
      return;
    }
    const generation = runId,
      selectedRoute = route,
      b = $("#tool-submit");
    b.disabled = true;
    b.textContent = "Tayyorlanmoqda…";
    b.classList.add("is-busy");
    e.target.setAttribute("aria-busy", "true");
    $("#tool-error").textContent = "";
    try {
      const lang = $("#lang")?.value || "en",
        body = {
          source_language: lang,
          target_language: lang === "en" ? "uz" : "en",
          style: $("#style")?.value || "neutral",
        };
      if (isImage) body.image = await compressImage(selectedImage);
      else body.text = $("#source-text").value;
      if (generation !== runId) return;
      const p = await api(
        {
          translate: "/translate",
          ai: "/ai/translate",
          image: "/image/translate",
          grammar: "/grammar",
        }[selectedRoute],
        { method: "POST", body },
      );
      if (generation === runId) showResult(p.result, grammar);
    } catch (e) {
      if (generation === runId) {
        if (grammar && (e.status === 0 || e.status >= 500))
          showResult(offlineGrammar($("#source-text").value), true);
        else $("#tool-error").textContent = e.message;
      }
    } finally {
      if (generation === runId) {
        b.disabled = false;
        b.classList.remove("is-busy");
        e.target.removeAttribute("aria-busy");
        b.textContent = grammar ? "Tekshirish" : "Tarjima qilish";
      }
    }
  };
  if (isImage) {
    $("#pick-photo").onclick = () => $("#image-file").click();
    for (const id of ["image-file", "camera-file"])
      $("#" + id).onchange = (event) => {
        selectPhoto(event.target.files[0]);
        event.target.value = "";
      };
    $("#remove-photo").onclick = () => {
      releasePhotoPreview();
      selectedImage = null;
      $("#image-preview").removeAttribute("src");
      $("#image-preview").hidden = true;
      $("#remove-photo").hidden = true;
      $("#tool-result").innerHTML = "";
    };
    $("#take-photo").onclick = async () => {
      if (!navigator.mediaDevices?.getUserMedia) {
        $("#camera-file").click();
        return;
      }
      openModal("Suratga olish", `<div class="camera-session stack"><p class="help">Rasmdagi matnni to‘liq kadrlang. Mikrofon ishlatilmaydi.</p><video id="camera-video" autoplay playsinline muted aria-label="Kamera tasviri"></video><p id="camera-error" class="help" role="status">Kamera ochilmoqda…</p><button class="primary" id="capture-photo" disabled>Suratga olish</button><button class="ghost" id="cancel-camera">Bekor qilish</button></div>`);
      const session = new CameraSession(navigator.mediaDevices), view = modalVersion;
      cameraSession = session;
      const cameraCurrent = () => currentPhotoView() && modal.open && view === modalVersion;
      $("#cancel-camera").onclick = () => modal.close();
      $("#capture-photo").onclick = async (event) => {
        event.target.disabled = true;
        try {
          const file = await session.capture();
          if (!cameraCurrent() || !file) return;
          selectPhoto(file);
          modal.close();
        } catch (error) {
          if (cameraCurrent()) {
            $("#camera-error").textContent = error.message;
            event.target.disabled = false;
          }
        }
      };
      try {
        if (await session.open($("#camera-video")) && cameraCurrent()) {
          $("#capture-photo").disabled = false;
          $("#camera-error").textContent = "Kamera tayyor.";
        }
      } catch (error) {
        if (cameraCurrent()) $("#camera-error").textContent = cameraError(error);
      }
    };
  }
}
async function compressImage(file) {
  if (!file || file.size > 10 * 1024 * 1024)
    throw Error("10 MB gacha rasm tanlang.");
  let bitmap;
  try { bitmap = await createImageBitmap(file); }
  catch { throw Error("Rasm o‘qilmadi. JPG, PNG yoki WebP formatini tanlang."); }
  if (bitmap.width * bitmap.height > 20000000) {
    bitmap.close();
    throw Error("Rasm juda katta.");
  }
  const scale = Math.min(1, 1600 / Math.max(bitmap.width, bitmap.height)),
    canvas = document.createElement("canvas");
  canvas.width = Math.round(bitmap.width * scale);
  canvas.height = Math.round(bitmap.height * scale);
  canvas.getContext("2d").drawImage(bitmap, 0, 0, canvas.width, canvas.height);
  bitmap.close();
  const blob = await new Promise((r) => canvas.toBlob(r, "image/jpeg", 0.78));
  if (!blob || blob.size > 3 * 1024 * 1024)
    throw Error("Kichikroq rasm tanlang.");
  return new Promise((resolve, reject) => {
    const r = new FileReader();
    r.onload = () => resolve(r.result.split(",")[1]);
    r.onerror = () => reject(Error("Rasm o‘qilmadi. Qayta urinib ko‘ring."));
    r.readAsDataURL(blob);
  });
}
function showResult(r, grammar = false) {
  $("#tool-result").innerHTML =
    `<section class="card stack"><span class="eyebrow muted">Natija</span>${r.extractedText ? `<div><h3>Rasmdagi matn</h3><p>${esc(r.extractedText)}</p></div>` : ""}<p class="result">${esc(grammar ? r.corrected : r.translation)}</p><p class="muted">${esc(r.explanation)}</p>${(r.issues || []).map((i) => `<div class="issue"><del>${esc(i.original)}</del> → <ins>${esc(i.replacement)}</ins><p class="help">${esc(i.explanation)}</p></div>`).join("")}${(r.alternatives || []).map((a) => `<div class="issue"><b>${esc(a.meaning)}</b><p class="help">${esc(a.usage)}</p></div>`).join("")}<button class="ghost" id="copy-result">Nusxa olish</button></section>`;
  $("#copy-result").onclick = () =>
    navigator.clipboard
      .writeText(grammar ? r.corrected : r.translation)
      .then(() => toast("Nusxa olindi."))
      .catch(() => toast("Matnni tanlab nusxa oling."));
}
function openModal(title, html) {
  cameraSession?.stop();
  cameraSession = null;
  modalVersion++;
  modal.innerHTML = `<div class="modal-head"><h2 id="modal-title">${esc(title)}</h2><button class="icon ghost" data-action="close-modal" aria-label="Yopish">${icon("close", 17)}</button></div>${html}`;
  if (!modal.open) modal.showModal();
}
function authDialog(mode = "login", pending = {}) {
  const labels = {
    login: "Kirish",
    register: "Lingoyga xush kelibsiz",
    verify: "Emailni tasdiqlang",
    forgot: "Parolni tiklash",
    reset: "Yangi parol belgilang",
    change: "Parolni almashtirish",
  };
  openModal(
    labels[mode],
    `${["login", "register"].includes(mode) ? '<div class="auth-welcome"><img class="auth-logo" src="/icons/lingoy-192.png" alt="Lingoy" width="64" height="64"><div><span class="eyebrow">LINGOY</span><h3>So‘zlaringiz<br>shu yerda.</h3></div><div class="word-art" aria-hidden="true"><div class="word-art-card"><b>hello</b><span>salom</span></div><span class="word-art-badge">EN · UZ</span></div></div>' : ""}<p class="help">${["verify", "reset"].includes(mode) ? "6 xonali kod 10 daqiqa amal qiladi." : "Shaxsiy lug‘atingiz va o‘rganish odatlaringiz bir joyda."}</p><form id="auth-form" class="form">${mode === "register" ? '<label>Ismingiz<input name="name" maxlength="64" autocomplete="name" required></label>' : ""}${mode !== "change" ? `<label>Email<input name="email" type="email" value="${esc(pending.email || user?.email || "")}" ${["verify", "reset"].includes(mode) ? "readonly" : ""} required autocomplete="email"></label>` : ""}${["verify", "reset"].includes(mode) ? '<label>Tasdiqlash kodi<input class="otp" name="code" inputmode="numeric" pattern="[0-9]{6}" maxlength="6" autocomplete="one-time-code" required></label>' : ""}${mode === "change" ? '<label>Joriy parol<input name="oldPassword" type="password" autocomplete="current-password" required></label>' : ""}${!["forgot", "verify"].includes(mode) ? `<label>${["reset", "change"].includes(mode) ? "Yangi parol" : "Parol"}<input name="password" type="password" minlength="10" maxlength="72" autocomplete="${mode === "login" ? "current-password" : "new-password"}" required></label>${mode === "login" ? '<div class="password-help"><button type="button" id="forgot-password" class="text-link">Parolni unutdingizmi?</button></div>' : '<p class="help">Kamida 10 belgi. Harflar va raqamlardan foydalaning.</p>'}` : ""}${["reset", "change", "register"].includes(mode) ? '<label>Parolni takrorlang<input name="confirm" type="password" minlength="10" maxlength="72" autocomplete="new-password" required></label>' : ""}<button class="primary" id="auth-submit">${mode === "login" ? "Kirish" : mode === "verify" ? "Tasdiqlash" : ["register", "forgot"].includes(mode) ? "Kod yuborish" : "Parolni yangilash"}</button><p class="error" id="auth-error" role="alert"></p></form>${mode === "login" ? '<div class="stack tight" style="margin-top:14px"><button class="ghost google-login" id="google-login"><img src="/assets/google.svg" alt="" width="20" height="20">Google bilan kirish</button><button id="register-account">Yangi akkaunt yaratish</button></div>' : ["verify", "reset"].includes(mode) ? '<button class="ghost" id="resend" disabled>Qayta yuborish · 60 s</button>' : '<button class="ghost" id="back-login" style="margin-top:14px">Kirishga qaytish</button>'}`,
  );
  const view = modalVersion;
  const current = () => modal.open && modalVersion === view;
  $("#auth-form").onsubmit = async (e) => {
    e.preventDefault();
    const data = Object.fromEntries(new FormData(e.target)),
      b = $("#auth-submit");
    if (b.disabled) return;
    if (data.confirm !== undefined && data.confirm !== data.password) {
      $("#auth-error").textContent = "Parollar mos kelmadi.";
      return;
    }
    const controls = [
      ...modal.querySelectorAll(
        "input, select, button:not([data-action=close-modal])",
      ),
    ].map((control) => [control, control.disabled]);
    for (const [control] of controls) control.disabled = true;
    const label = b.textContent;
    b.textContent = "Kutilmoqda…";
    b.classList.add("is-busy");
    e.target.setAttribute("aria-busy", "true");
    $("#auth-error").textContent = "";
    try {
      if (mode === "register") {
        await api("/auth/register", {
          method: "POST",
          body: { name: data.name, email: data.email, password: data.password },
        });
        if (!current()) return;
        authDialog("verify", {
          name: data.name,
          email: data.email,
          password: data.password,
        });
      } else if (mode === "verify") {
        accept(
          await api("/auth/verify", {
            method: "POST",
            body: { email: data.email, code: data.code },
          }),
        );
        if (current()) modal.close();
        sync().catch(() => {});
        render();
      } else if (mode === "forgot") {
        await api("/auth/password/request", {
          method: "POST",
          body: { email: data.email },
        });
        if (!current()) return;
        authDialog("reset", { email: data.email });
      } else if (mode === "reset") {
        await api("/auth/password/reset", {
          method: "POST",
          body: {
            email: data.email,
            code: data.code,
            newPassword: data.password,
          },
        });
        accept(null);
        if (!current()) return;
        authDialog("login", { email: data.email });
        $("#auth-error").textContent =
          "Parol yangilandi. Yangi parol bilan kiring.";
      } else if (mode === "change") {
        await api("/auth/password/change", {
          method: "POST",
          body: { oldPassword: data.oldPassword, newPassword: data.password },
        });
        accept(null);
        if (!current()) return;
        authDialog("login");
        $("#auth-error").textContent = "Parol yangilandi. Qayta kiring.";
      } else {
        accept(
          await api("/auth/login", {
            method: "POST",
            body: { email: data.email, password: data.password },
          }),
        );
        if (current()) modal.close();
        sync().catch(() => {});
        render();
      }
    } catch (error) {
      if (current() && $("#auth-error"))
        $("#auth-error").textContent = error.message;
    } finally {
      if (current()) {
        for (const [control, disabled] of controls) control.disabled = disabled;
        b.textContent = label;
        b.classList.remove("is-busy");
        e.target.removeAttribute("aria-busy");
      }
    }
  };
  if (mode === "login") {
    $("#google-login").onclick = () =>
      (location.href = "/api/v1/auth/google/start");
    $("#forgot-password").onclick = () => authDialog("forgot");
    $("#register-account").onclick = () => authDialog("register");
  } else if ($("#back-login")) $("#back-login").onclick = () => authDialog();
  if ($("#resend")) {
    const b = $("#resend");
    let left = 60;
    const timer = setInterval(() => {
      if (!modal.open || !b.isConnected) {
        clearInterval(timer);
        return;
      }
      left--;
      b.textContent =
        left > 0 ? "Qayta yuborish · " + left + " s" : "Kodni qayta yuborish";
      if (left <= 0) {
        b.disabled = false;
        clearInterval(timer);
      }
    }, 1000);
    b.onclick = async () => {
      b.disabled = true;
      try {
        if (mode === "verify")
          await api("/auth/register", { method: "POST", body: pending });
        else
          await api("/auth/password/request", {
            method: "POST",
            body: { email: pending.email },
          });
        authDialog(mode, pending);
      } catch (e) {
        $("#auth-error").textContent = e.message;
        b.disabled = false;
      }
    };
  }
}
function arr(v) {
  try {
    const p = JSON.parse(v);
    return Array.isArray(p) ? p : [];
  } catch {
    return [];
  }
}
function meaningView(lemma,v,index) {
  const p=sensePresentation(lemma,v),pos={n:'Ot',v:'Fe’l',a:'Sifat',r:'Ravish',function:'Yordamchi so‘z'}[v.pos]||'So‘z';
  return `<details class="word-sense" name="word-meaning" ${index===0?'open':''}><summary><span class="help">${index+1} · ${esc(pos)}</span><span>${esc(v.meaning_uz||v.definition)}</span></summary><div class="word-sense-body">${v.meaning_uz?`<p class="help">${esc(v.definition)}</p>`:''}${p.examples.length?`<h4>Misollar</h4>${p.examples.map(e=>`<div class="word-example"><p>${esc(e.en)}</p>${e.uz?`<p class="help">${esc(e.uz)}</p>`:''}</div>`).join('')}`:''}${p.synonyms.length?`<h4>Shu ma’nodagi sinonimlar</h4><div class="actions">${p.synonyms.map(w=>`<button class="ghost" data-synonym="${esc(w)}">${esc(w)}</button>`).join('')}</div>`:''}</div></details>`;
}
async function openWord(id) {
  const account = owner();
  const generation = runId;
  openModal("So‘z ma’nolari", '<p class="help">Yuklanmoqda…</p>');
  const dialog = modalVersion;
  const current = () =>
    modal.open && dialog === modalVersion && generation === runId;
  try {
    let d = await lookup(id);
    if (!current()) return;
    rememberViewed(d.word, account);
    if (!query.trim() && route === 'dictionary') { words = recentViewed(); $('#results').innerHTML = '<h2 class="recent-heading">Yaqinda ko‘rilgan</h2>' + rows(words); }
    if (!d.word.translation) {
      try {
        const t = await api("/dictionary/translate", {
          method: "POST",
          body: { text: d.word.lemma },
        });
        d = { ...d, word: t.word };
      } catch (e) {
        d.word.explanation = e.message;
      }
    }
    if (!current()) return;
    const w = d.word,
      s = state();
    words = [...words.filter((x) => x.id !== id), w];
    openModal(w.lemma, `<div class="stack word-entry" style="margin-top:18px"><div class="word-overview">${picture(w.lemma)?`<img class="word-illustration" src="${esc(picture(w.lemma))}" alt="${esc(w.lemma)}">`:''}<div><p class="result">${esc((w.translation||'Ma’nosini hozircha aniqlab bo‘lmadi.').split(';').slice(0,3).join('; '))}</p><p class="help">${esc(w.ipa)} ${esc(w.explanation||'')}</p></div></div>${(w.translation||'').split(';').length>3?`<details class="word-extra-glosses"><summary>Barcha tarjimalar</summary><p>${esc(w.translation)}</p></details>`:''}<div class="actions"><button class="primary" data-save="${id}">${s.saved[id]?'Saqlangan':'So‘zni saqlash'}</button><button class="ghost" data-speak="${esc(w.lemma)}">${icon('sound',16)} Tinglash</button></div>${s.saved[id]?`<label>Papka<select id="word-folder">${s.folders.map(f=>`<option ${f===s.saved[id].folder?'selected':''}>${esc(f)}</option>`).join('')}</select></label>`:''}<h3>Ma’nolar va misollar</h3><div id="word-meanings">${d.senses.slice(0,3).map((v,i)=>meaningView(w.lemma,v,i)).join('')}</div>${d.senses.length>3?'<button class="ghost" id="word-more-senses">Boshqa ma’nolarni ko‘rish</button>':''}</div>`);
    let shown=3;
    if($('#word-more-senses'))$('#word-more-senses').onclick=()=>{const end=shown+3;$('#word-meanings').insertAdjacentHTML('beforeend',d.senses.slice(shown,end).map((v,i)=>meaningView(w.lemma,v,shown+i)).join(''));shown=end;if(shown>=d.senses.length)$('#word-more-senses').hidden=true;};
    const entryDialog=modalVersion;
    $('#word-meanings').onclick=async e=>{const b=e.target.closest('[data-synonym]');if(!b)return;try{const q=b.dataset.synonym,result=await search(q);if(!modal.open||modalVersion!==entryDialog||runId!==generation)return;const word=result.words.find(x=>x.lemma.toLowerCase()===q.toLowerCase());if(word)openWord(word.id);else toast('So‘zni lug‘atdan qidirib ko‘ring.');}catch{if(modalVersion===entryDialog&&runId===generation)toast('So‘z ochilmadi. Qayta urinib ko‘ring.');}};
    if ($("#word-folder"))
      $("#word-folder").onchange = (e) => {
        const t = state();
        if (t.saved[id]) {
          t.saved[id].folder = e.target.value;
          save(t);
        }
      };
  } catch (e) {
    if (!current()) return;
    openModal("So‘z ochilmadi", `<p class="error">${esc(e.message)}</p>`);
  }
}
function profile(main) {
  const s = stats(),
    u = user;
  main.innerHTML = `<h1>Profil</h1><section class="card stack profile-account">${u ? `<div class="row">${u.picture ? `<img class="avatar" src="${esc(u.picture)}" alt="Google profil rasmi" referrerpolicy="no-referrer">` : `<div class="avatar">${esc(u.name[0].toUpperCase())}</div>`}<div class="avatar-label"><h2>${esc(u.name)}</h2><p class="muted">${esc(u.email)}</p></div></div><div class="profile-actions"><button class="ghost" data-action="name">Ismni o‘zgartirish</button><button class="ghost" data-action="change-password">${u.hasPassword ? "Parolni almashtirish" : "Parol belgilash"}</button><button class="ghost danger" data-action="logout">Chiqish</button></div><p class="help">So‘zlaringiz akkaunt orqali sinxronlanadi. Mashq natijalari va papkalar shu qurilmada saqlanadi.</p>` : `<h2>So‘zlaringiz doim yoningizda</h2><p class="muted">Kiring va lug‘atingizni boshqa qurilmada davom ettiring.</p><button class="primary" data-action="login">Kirish</button>`}</section><div class="stats">${[
    [s.saved, "saqlangan so‘z"],
    [s.total, "jami mashq"],
    [s.total ? Math.round((s.correct / s.total) * 100) + "%" : "—", "aniqlik"],
  ]
    .map(
      ([n, l]) =>
        `<div class="card stat"><div><strong>${n}</strong><small>${l}</small></div></div>`,
    )
    .join(
      "",
    )}</div><section class="card stack"><h2>Lingoy doim yoningizda</h2><p class="muted">Android ilovasida lug‘at internet bo‘lmasa ham ishlaydi.</p><a class="button primary" href="/downloads/Lingoy.apk" download>${icon("download", 19)} Android APK’ni yuklab olish</a><button class="ghost" data-action="install-pwa">Saytni ilova sifatida o‘rnatish</button><button class="ghost" id="offline-install">Oflayn lug‘atni yuklash</button><p id="offline-status" class="help" role="status"></p>${u ? '<button class="ghost" data-action="import-guest">Qurilmadagi mehmon so‘zlarini akkauntga ko‘chirish</button>' : ""}</section><section class="card stack"><h2>Yordam</h2><a href="https://t.me/davlatyoruz" target="_blank" rel="noopener">Telegram: @davlatyoruz</a><a href="tel:+998934920107">+998 93 492 01 07</a><button class="ghost" data-action="licenses">Manbalar va litsenziyalar</button><p class="help">Lingoy ${appVersion} · Har kuni yangi qadam.</p></section>`;
  const avatar = $(".avatar");
  if (avatar?.tagName === "IMG")
    avatar.addEventListener(
      "error",
      () => {
        const fallback = document.createElement("div");
        fallback.className = "avatar";
        fallback.textContent = u.name[0].toUpperCase();
        avatar.replaceWith(fallback);
      },
      { once: true },
    );
  Promise.all([installed(), dictionaryUpdateAvailable()]).then(([ok, update]) => {
    if ($("#offline-status"))
      $("#offline-status").textContent = update
        ? "Yangi tarjimalar tayyor. Oflayn lug‘atni yangilang; saqlangan so‘zlaringiz saqlanadi."
        : ok
        ? "Oflayn lug‘at o‘rnatilgan."
        : "So‘zlar, ma’nolar va misollar bir marta yuklanadi.";
    if (update && $("#offline-install")) $("#offline-install").textContent = "Oflayn lug‘atni yangilash";
  });
  $("#offline-install").onclick = async () => {
    const b = $("#offline-install");
    b.disabled = true;
    try {
      await installDictionary((t) => {
        if ($("#offline-status")) $("#offline-status").textContent = t;
      });
      toast("Oflayn lug‘at tayyor.");
    } catch (e) {
      toast(e.message);
    } finally {
      if (b.isConnected) b.disabled = false;
    }
  };
}
function collection(main) {
  const kind = route,
    data =
      kind === "pictures"
        ? Object.keys(photoMap).map((word) => ({ word, id: word }))
        : essentials.filter(
            (e) => e.kind === (kind === "daily" ? "daily" : "speaking"),
          ),
    title = {
      daily: "Kundalik so‘zlar",
      speaking: "Speaking iboralari",
      pictures: "Rasmli lug‘at",
    }[kind];
  main.innerHTML = `<h1>${title}</h1><input id="collection-query" aria-label="To‘plam ichidan izlash" placeholder="Izlash…"><div class="grid" id="collection-list"></div><button class="ghost" id="collection-more">Yana ko‘rsatish</button>`;
  let limit = 24;
  function draw() {
    const q = normalize($("#collection-query").value),
      list = data.filter((e) =>
        normalize(e.word + " " + (e.meaning || "")).includes(q),
      );
    $("#collection-list").innerHTML =
      list
        .slice(0, limit)
        .map(
          (e) =>
            `<article class="card stack">${kind === "pictures" && picture(e.word) ? `<img class="photo-preview" src="${esc(picture(e.word))}" alt="${esc(e.word)}" loading="lazy">` : ""}<h2>${esc(e.word)}</h2><p>${esc(e.meaning || "")}</p><p class="help">${esc(e.example || "")}<br>${esc(e.translation || "")}</p><div class="actions"><button class="ghost" data-speak="${esc(e.example || e.word)}">${icon("sound", 16)} Tinglash</button><button class="ghost" data-find="${esc(e.word)}">Lug‘atda ochish</button></div></article>`,
        )
        .join("") || '<p class="muted">Natija topilmadi.</p>';
    $("#collection-more").hidden = list.length <= limit;
  }
  $("#collection-query").oninput = () => {
    limit = 24;
    draw();
  };
  $("#collection-more").onclick = () => {
    limit += 24;
    draw();
  };
  draw();
}
function lessonsPage(main) {
  const done = state().lessons;
  main.innerHTML = `<h1>Grammatika darslari</h1><p class="muted">Qoida, misol va kichik sinov.</p><div class="grid">${lessons.map((l, i) => `<button class="tool" data-lesson="${i}"><span class="glyph">${icon(done.includes(l.id) ? "check" : "book")}</span><div><h3>${esc(l.title)}</h3><p>${esc(l.rule.split("\n")[0])}</p></div></button>`).join("")}</div>`;
}
function lesson(index) {
  const l = lessons[index];
  openModal(
    l.title,
    `<div class="lesson-rule">${esc(l.rule)}</div><p>${esc(l.explanation)}</p>${l.examples.map((e) => `<p class="help">${esc(e)}</p>`).join("")}<div class="issue">${esc(l.mistake)}</div><form class="form" id="lesson-form">${l.questions.map((q, i) => `<label>${esc(q.text)}<select name="q${i}" required><option value="">Javobni tanlang</option>${q.options.map((o, n) => `<option value="${n}">${esc(o)}</option>`).join("")}</select></label>`).join("")}<button class="primary">Tekshirish</button><p id="lesson-result" role="status"></p></form>`,
  );
  $("#lesson-form").onsubmit = (e) => {
    e.preventDefault();
    const f = new FormData(e.target),
      n = l.questions.filter(
        (q, i) => String(q.answer) === f.get("q" + i),
      ).length;
    $("#lesson-result").textContent =
      `${n} / ${l.questions.length} to‘g‘ri. ${n === l.questions.length ? "Dars yakunlandi!" : "Qoidani yana ko‘rib chiqing."}`;
    if (n === l.questions.length) {
      const s = state();
      if (!s.lessons.includes(l.id)) s.lessons.push(l.id);
      save(s);
    }
  };
}
function downloadCsv() {
  const q = csvCell,
    list = [
      ["lemma", "translation", "folder"],
      ...Object.values(state().saved).map((w) => [
        w.lemma,
        w.translation,
        w.folder,
      ]),
    ],
    url = URL.createObjectURL(
      new Blob(["\ufeff", list.map((r) => r.map(q).join(",")).join("\r\n")], {
        type: "text/csv;charset=utf-8",
      }),
    ),
    a = document.createElement("a");
  a.href = url;
  a.download = "Lingoy_Sozlarim.csv";
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
function parseCsv(t) {
  const rows = [];
  let row = [],
    cell = "",
    quoted = false;
  for (let i = 0; i < t.length; i++) {
    const c = t[i];
    if (c === '"') {
      if (quoted && t[i + 1] === '"') {
        cell += '"';
        i++;
      } else quoted = !quoted;
    } else if (!quoted && (c === "," || c === "\n")) {
      row.push(cell.replace(/\r$/, ""));
      cell = "";
      if (c === "\n") {
        rows.push(row);
        row = [];
      }
    } else cell += c;
  }
  if (cell || row.length) {
    row.push(cell);
    rows.push(row);
  }
  return rows;
}
function importCsv() {
  const input = document.createElement("input");
  input.type = "file";
  input.accept = ".csv,text/csv";
  input.onchange = async () => {
    const f = input.files[0];
    if (!f) return;
    if (f.size > 5 * 1024 * 1024) {
      toast("5 MB gacha CSV tanlang.");
      return;
    }
    const list = parseCsv((await f.text()).replace(/^\ufeff/, ""));
    if (list.length > 10001) {
      toast("10 000 satrgacha import qilish mumkin.");
      return;
    }
    let n = 0;
    for (const row of list) {
      const lemma = row[0]?.trim();
      if (!lemma || ["lemma", "word"].includes(lemma.toLowerCase())) continue;
      try {
        const r = await search(lemma),
          w = r.words.find((w) => normalize(w.lemma) === normalize(lemma));
        if (w && !state().saved[w.id]) {
          await toggleWord(w);
          n++;
        }
      } catch {
        toast(
          `${n} ta so‘z saqlandi. Internet tiklangach qayta urinib ko‘ring.`,
        );
        return;
      }
    }
    toast(`${n} ta yangi so‘z saqlandi.`);
    if (route === "saved") savedPage($("#main"));
  };
  input.click();
}
document.addEventListener("click", async (e) => {
  const b = e.target.closest("button");
  if (!b) return;
  try {
    if (b.dataset.nav) {
      go(b.dataset.nav);
      return;
    }
    if (b.dataset.word) {
      await openWord(Number(b.dataset.word));
      return;
    }
    if (b.dataset.save) {
      const id = Number(b.dataset.save),
        w =
          words.find((w) => w.id === id) ||
          state().saved[id] ||
          (await lookup(id)).word;
      const yes = await toggleWord(w);
      b.classList.toggle("selected", yes);
      b.setAttribute("aria-pressed", String(yes));
      toast(yes ? "So‘z saqlandi." : "So‘z olib tashlandi.");
      if (route === "saved") savedPage($("#main"));
      return;
    }
    if (b.dataset.speak) {
      if (!("speechSynthesis" in window)) {
        toast("Bu brauzer talaffuzni qo‘llamaydi.");
        return;
      }
      speechSynthesis.cancel();
      const u = new SpeechSynthesisUtterance(b.dataset.speak);
      u.lang = "en-US";
      u.rate = 0.9;
      speechSynthesis.speak(u);
      return;
    }
    if (b.dataset.find) {
      query = b.dataset.find;
      reverse = false;
      go("dictionary");
      return;
    }
    if (b.dataset.game) {
      startGame(b.dataset.game);
      return;
    }
    if (b.dataset.answer) {
      answer(
        Number(b.dataset.answer) === game.q[game.index].word.id,
        Number(b.dataset.answer),
      );
      return;
    }
    if (b.dataset.pair !== undefined) {
      await pair(Number(b.dataset.pair));
      return;
    }
    if (b.dataset.lesson !== undefined) {
      lesson(Number(b.dataset.lesson));
      return;
    }
    const a = b.dataset.action;
    if (a === "theme") {
      theme = theme === "dark" ? "light" : "dark";
      localStorage.setItem("lingoy-theme", theme);
      document.body.classList.toggle("dark", theme === "dark");
      b.innerHTML = icon(theme === "dark" ? "sun" : "moon", 20);
      b.setAttribute("aria-pressed", String(theme === "dark"));
    }
    if (a === "close-modal") modal.close();
    if (a === "login") authDialog();
    if (a === "logout") {
      await logout();
      render();
    }
    if (a === "change-password")
      authDialog(user?.hasPassword ? "change" : "forgot");
    if (b.dataset.correction) { $("#query").value = b.dataset.correction; loadSearch(); }
    if (a === "fill-word") await fillWord(query);
    if (a === "next") {
      game.index++;
      game.answered = false;
      drawGame();
    }
    if (a === "end-game") {
      clearInterval(game?.timer);
      game = null;
      games($("#main"));
    }
    if (a === "reveal")
      $("#feedback").innerHTML =
        `<p class="result">${esc(game.q[game.index].word.translation)}</p><div class="actions" style="justify-content:center"><button class="primary" data-action="known">Esladim</button><button class="ghost" data-action="forgot">Qayta ko‘raman</button></div>`;
    if (a === "known" || a === "forgot") answer(a === "known");
    if (a === "offline-grammar") {
      const text = $("#source-text").value;
      if (text.trim()) showResult(offlineGrammar(text), true);
      else toast("Avval matn kiriting.");
    }
    if (a === "sync") {
      await sync();
      toast("So‘zlar sinxronlandi.");
      savedPage($("#main"));
    }
    if (a === "folder") {
      openModal(
        "Yangi papka",
        '<form class="form" id="folder-form"><label>Papka nomi<input name="name" maxlength="50" required></label><button class="primary">Yaratish</button></form>',
      );
      $("#folder-form").onsubmit = (e) => {
        e.preventDefault();
        const name = new FormData(e.target).get("name").trim();
        if (!name) return;
        const s = state();
        if (!s.folders.includes(name)) {
          s.folders.push(name);
          save(s);
        }
        modal.close();
        savedPage($("#main"));
      };
    }
    if (a === "export") downloadCsv();
    if (a === "import") importCsv();
    if (a === "name") {
      openModal(
        "Ismni o‘zgartirish",
        `<form class="form" id="name-form"><label>Ismingiz<input name="name" maxlength="64" value="${esc(user.name)}" required></label><button class="primary">Saqlash</button><p class="error" id="name-error"></p></form>`,
      );
      $("#name-form").onsubmit = async (e) => {
        e.preventDefault();
        try {
          await api("/me", {
            method: "PATCH",
            body: { name: new FormData(e.target).get("name") },
          });
          await restore();
          modal.close();
          render();
        } catch (error) {
          $("#name-error").textContent = error.message;
        }
      };
    }
    if (a === "install-pwa") {
      if (deferredInstall) {
        await deferredInstall.prompt();
        deferredInstall = null;
      } else
        toast(
          "Brauzer menyusidan “Ilovani o‘rnatish” yoki “Bosh ekranga qo‘shish”ni tanlang.",
        );
    }
    if (a === "import-guest") {
      let guest;
      try {
        guest = JSON.parse(
          localStorage.getItem("lingoy-state-guest") || "null",
        );
      } catch {}
      const s = state();
      let n = 0;
      for (const w of Object.values(guest?.saved || {})) {
        if (!s.saved[w.id]) {
          s.saved[w.id] = { ...w };
          s.queue[w.id] = {
            id: crypto.randomUUID(),
            word_id: w.id,
            deleted: false,
          };
          n++;
        }
      }
      save(s);
      await sync();
      toast(`${n} ta mehmon so‘zi ko‘chirildi.`);
    }
    if (a === "licenses") {
      const text = await fetch("/assets/licenses.txt").then((r) => r.text());
      openModal(
        "Manbalar va litsenziyalar",
        `<pre style="white-space:pre-wrap;font-size:11px">${esc(text)}</pre><a href="/assets/photo_credits.txt" target="_blank" rel="noopener">Fotosurat manbalari</a>`,
      );
    }
  } catch (error) {
    toast(error.message || "Amal bajarilmadi.");
  }
});
window.addEventListener("pagehide", stopCamera);
document.addEventListener("visibilitychange", () => {
  if (document.hidden && cameraSession) modal.close();
});
window.addEventListener("hashchange", () => {
  if (modal.open) modal.close();
  route = location.hash.slice(1) || "home";
  render();
});
modal.addEventListener("close", () => {
  if (modal.open) return;
  cameraSession?.stop();
  cameraSession = null;
  modalVersion++;
});
document.querySelector("[data-skip]").addEventListener("click", (event) => {
  event.preventDefault();
  $("#main")?.focus();
});
window.addEventListener("accountchange", () => {
  if (modal.querySelector(".study-picker")) modal.close();
  render();
  sync().catch(() => {});
});
window.addEventListener("online", () => {
  sync().catch(() => {});
  toast("Internet tiklandi.");
});
window.addEventListener("beforeinstallprompt", (e) => {
  e.preventDefault();
  deferredInstall = e;
});
setInterval(() => sync().catch(() => {}), 45000);
async function boot() {
  trackViewport();
  render();
  const initialRun = runId;
  await Promise.allSettled([
    fetch("/data/photos.json")
      .then((r) => r.json())
      .then((p) => (photoMap = p)),
    fetch("/data/essentials.json")
      .then((r) => r.json())
      .then((p) => (essentials = p)),
    fetch("/data/lessons.json")
      .then((r) => r.json())
      .then((p) => (lessons = p)),
  ]);
  // Hydration must not replace a screen or a form that the user already opened.
  const editing = document.activeElement?.matches('input, textarea, select');
  if (runId === initialRun && !modal.open && !editing) render();
  await restore();
  sync().catch(() => {});
  if ("serviceWorker" in navigator)
    navigator.serviceWorker.register("/sw.js").catch(() => {});
  const authStatus = new URLSearchParams(location.search).get("auth");
  if (["success", "cancelled"].includes(authStatus)) {
    history.replaceState(null, "", "/" + location.hash);
    if (authStatus === "cancelled") toast("Google orqali kirish bekor qilindi.");
  }
}
boot();
