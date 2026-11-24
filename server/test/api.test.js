import test from "node:test";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import { createApp } from "../src/app.js";
import { challenge, random } from "../src/security.js";
const cfg = {
  secret: "test-secret-at-least-thirty-two-characters",
  origin: "http://localhost",
  production: false,
  db: ":memory:",
  dictionary: fileURLToPath(
    new URL("../../mobile/assets/dictionary.db", import.meta.url),
  ),
  downloads: "/tmp/lingoy-test-downloads",
  web: "/tmp/none",
  googleId: "test-client",
  googleSecret: "test-secret",
  aiKey: "test-only-key",
  model: "test",
  daily: 3,
};
const output = {
  translation: "Rost gap; hazil emas.",
  corrected: "",
  explanation: "Norasmiy ibora.",
  extractedText: "",
  alternatives: [],
  issues: [],
};
async function fixture(t, extra = {}) {
  const { settings = {}, ...injected } = extra;
  let now = Date.now();
  const sent = [];
  const service = createApp(
    { ...cfg, ...settings },
    {
      now: () => now,
      quiet: true,
      static: false,
      mail: {
        send: async (email, code, purpose) =>
          sent.push({ email, code, purpose }),
      },
      generate: async () => output,
      ...injected,
    },
  );
  const server = service.app.listen(0, "127.0.0.1");
  await new Promise((r) => server.once("listening", r));
  t.after(() => {
    server.close();
    service.closeDictionary();
    service.db.close();
  });
  const cookies = new Map();
  let csrf = "",
    access = "";
  async function request(path, body, headers = {}, atRoot = false) {
    const r = await fetch(
      `http://127.0.0.1:${server.address().port}${atRoot ? "" : "/api/v1"}${path}`,
      {
        method: body ? "POST" : "GET",
        redirect: "manual",
        headers: {
          "Content-Type": "application/json",
          Cookie: [...cookies].map(([k, v]) => k + "=" + v).join("; "),
          "X-CSRF-Token": csrf,
          ...(access ? { Authorization: "Bearer " + access } : {}),
          ...headers,
        },
        ...(body ? { body: JSON.stringify(body) } : {}),
      },
    );
    for (const c of r.headers.getSetCookie()) {
      const p = c.split(";")[0],
        i = p.indexOf("=");
      cookies.set(p.slice(0, i), p.slice(i + 1));
    }
    const data = r.headers.get("content-type")?.includes("json")
      ? await r.json()
      : await r.text();
    if (data.csrfToken) csrf = data.csrfToken;
    if (data.accessToken) access = data.accessToken;
    return { status: r.status, data, r };
  }
  await request("/auth/csrf");
  return {
    ...service,
    sent,
    cookies,
    request,
    rootRequest: (path, body, headers) => request(path, body, headers, true),
    advance: (n) => (now += n),
  };
}
const reg = {
  email: "student@gmail.com",
  name: "O‘quvchi",
  password: "correct-password-123",
};
async function register(f, p = reg) {
  assert.equal((await f.request("/auth/register", p)).status, 202);
  return f.request("/auth/verify", {
    email: p.email,
    code: f.sent.at(-1).code,
  });
}
test("email code, cooldown, five attempts, expiry and one-time consumption", async (t) => {
  const f = await fixture(t);
  await f.request("/auth/register", reg);
  assert.notEqual(
    f.db.prepare("SELECT code FROM challenges").get().code,
    f.sent[0].code,
  );
  assert.equal((await f.request("/auth/register", reg)).status, 429);
  const wrong = f.sent[0].code === "000000" ? "111111" : "000000";
  for (let i = 0; i < 5; i++)
    assert.equal(
      (await f.request("/auth/verify", { email: reg.email, code: wrong }))
        .status,
      400,
    );
  assert.equal(
    (
      await f.request("/auth/verify", {
        email: reg.email,
        code: f.sent[0].code,
      })
    ).status,
    429,
  );
  f.advance(600001);
  await f.request("/auth/register", reg);
  assert.equal(
    (
      await f.request("/auth/verify", {
        email: reg.email,
        code: f.sent.at(-1).code,
      })
    ).status,
    200,
  );
  assert.equal(
    (
      await f.request("/auth/verify", {
        email: reg.email,
        code: f.sent.at(-1).code,
      })
    ).status,
    400,
  );
});
test("password reset revokes old access and refresh; new password works and code cannot replay", async (t) => {
  const f = await fixture(t);
  await register(f);
  assert.equal((await f.request("/me")).status, 200);
  await f.request("/auth/password/request", { email: reg.email });
  assert.equal(f.sent.at(-1).purpose, "reset");
  const code = f.sent.at(-1).code;
  assert.equal(
    (
      await f.request("/auth/password/reset", {
        email: reg.email,
        code,
        newPassword: "new-password-456",
      })
    ).status,
    200,
  );
  assert.equal((await f.request("/me")).status, 401);
  assert.equal((await f.request("/auth/login", reg)).status, 400);
  assert.equal(
    (
      await f.request("/auth/login", {
        email: reg.email,
        password: "new-password-456",
      })
    ).status,
    200,
  );
  assert.equal(
    (
      await f.request("/auth/password/reset", {
        email: reg.email,
        code,
        newPassword: "replay-password-456",
      })
    ).status,
    400,
  );
});
test("profile password change checks current password and invalidates all sessions", async (t) => {
  const f = await fixture(t);
  await register(f);
  assert.equal(
    (
      await f.request("/auth/password/change", {
        oldPassword: "wrong",
        newPassword: "new-password-123",
      })
    ).status,
    400,
  );
  assert.equal(
    (
      await f.request("/auth/password/change", {
        oldPassword: reg.password,
        newPassword: "new-password-123",
      })
    ).status,
    200,
  );
  assert.equal((await f.request("/me")).status, 401);
  assert.equal(
    (
      await f.request("/auth/login", {
        email: reg.email,
        password: "new-password-123",
      })
    ).status,
    200,
  );
});
test("CSRF, origin, login gates, refresh rotation and replay defense", async (t) => {
  const f = await fixture(t);
  assert.equal(
    (await f.request("/auth/login", reg, { "X-CSRF-Token": "" })).status,
    403,
  );
  assert.equal(
    (await f.request("/auth/login", reg, { Origin: "https://evil.example" }))
      .status,
    403,
  );
  assert.equal(
    (await f.request("/ai/translate", { text: "hello" })).status,
    401,
  );
  assert.equal(
    (await f.request("/image/translate", { image: "abcd" })).status,
    401,
  );
  await register(f);
  const old = f.cookies.get("lingoy_refresh");
  const r = await f.request("/auth/refresh", {});
  assert.equal(r.status, 200);
  assert.ok(r.r.headers.getSetCookie()[0].includes("HttpOnly"));
  f.cookies.set("lingoy_refresh", old);
  assert.equal((await f.request("/auth/refresh", {})).status, 401);
  assert.equal((await f.request("/me")).status, 401);
});
test("dictionary fallback persists translations; saved words are account scoped and idempotent", async (t) => {
  const f = await fixture(t);
  const r = await f.request("/dictionary?q=apple");
  assert.equal(r.status, 200);
  const id = r.data.words[0].id;
  const slang = await f.request("/dictionary/translate", { text: "no cap" });
  assert.equal(slang.status, 200);
  assert.ok(slang.data.word.translation.includes("rost"));
  const again = await f.request("/dictionary?q=no%20cap");
  assert.equal(again.data.words[0].translation, slang.data.word.translation);
  await register(f);
  const body = {
    changes: [{ id: "mutation-test-id-1234", word_id: id, deleted: false }],
  };
  const a = await f.request("/saved", body),
    b = await f.request("/saved", body);
  assert.equal(a.data.revision, b.data.revision);
  assert.equal((await f.request("/saved")).data.words.length, 1);
  await f.request("/auth/logout", {});
  await register(f, { ...reg, email: "other@gmail.com" });
  assert.equal((await f.request("/saved")).data.words.length, 0);
});
test("AI cache avoids repeated provider calls; daily limit and image validation", async (t) => {
  let calls = 0;
  const f = await fixture(t, {
    generate: async () => {
      calls++;
      return output;
    },
  });
  await register(f);
  await f.request("/ai/translate", { text: "one" });
  assert.equal(
    (await f.request("/ai/translate", { text: "one" })).data.cached,
    true,
  );
  assert.equal(calls, 1);
  await f.request("/ai/translate", { text: "two" });
  await f.request("/ai/translate", { text: "three" });
  assert.equal(
    (await f.request("/ai/translate", { text: "four" })).status,
    429,
  );
  assert.equal(
    (await f.request("/image/translate", { image: "bm90LWFuLWltYWdl" })).status,
    400,
  );
});
test("AI provider failure refunds quota", async (t) => {
  const f = await fixture(t, {
    generate: async () => {
      throw Error("test unavailable");
    },
  });
  await register(f);
  assert.equal(
    (await f.request("/grammar", { text: "I is here." })).status,
    500,
  );
  assert.equal((await f.request("/usage")).data.used, 0);
});
test("Google merges verified email and mobile ticket is verifier-bound and one-time", async (t) => {
  let params;
  const google = {
    generateAuthUrl: (p) => {
      params = p;
      return "https://accounts.google.com/o/oauth2/auth";
    },
    getToken: async () => ({ tokens: { id_token: "mock" } }),
    verifyIdToken: async () => ({
      getPayload: () => ({
        email: reg.email,
        email_verified: true,
        sub: "mock-google-sub",
        name: "Google Name",
        picture: "https://lh3.googleusercontent.com/a/test",
        nonce: params.nonce,
      }),
    }),
  };
  const f = await fixture(t, { google });
  const u = await register(f);
  await f.request("/auth/logout", {});
  const verifier = random(),
    start = await f.request("/auth/mobile/start", {
      challenge: challenge(verifier),
    });
  const ticket = start.data.ticket;
  assert.equal(
    (await f.request("/auth/mobile/poll", { ticket, verifier: random() }))
      .status,
    400,
  );
  assert.equal(
    (await f.request("/auth/google/start?ticket=" + ticket)).status,
    302,
  );
  assert.equal(
    (
      await f.request(
        "/auth/google/callback?state=" + params.state + "&code=mock",
      )
    ).status,
    200,
  );
  const poll = await f.request("/auth/mobile/poll", { ticket, verifier });
  assert.equal(poll.data.user.id, u.data.user.id);
  assert.equal(
    poll.data.user.picture,
    "https://lh3.googleusercontent.com/a/test",
  );
  assert.equal(
    (await f.request("/auth/mobile/poll", { ticket, verifier })).status,
    400,
  );
});

test("Google-only account sets a password with a one-time email code and revokes sessions", async (t) => {
  let params;
  const google = {
    generateAuthUrl: (p) => {
      params = p;
      return "https://accounts.google.com/o/oauth2/auth";
    },
    getToken: async () => ({ tokens: { id_token: "mock" } }),
    verifyIdToken: async () => ({
      getPayload: () => ({
        email: reg.email,
        email_verified: true,
        sub: "new-google-user",
        name: "Ali",
        nonce: params.nonce,
      }),
    }),
  };
  const f = await fixture(t, { google });
  await f.request("/auth/google/start");
  await f.request("/auth/google/callback?state=" + params.state + "&code=mock");
  const session = await f.request("/auth/refresh", {});
  assert.equal(session.data.user.hasPassword, false);
  await f.request("/auth/password/request", { email: reg.email });
  const code = f.sent.at(-1).code;
  assert.equal(
    (
      await f.request("/auth/password/reset", {
        email: reg.email,
        code,
        newPassword: "first-password-123",
      })
    ).status,
    200,
  );
  assert.equal((await f.request("/me")).status, 401);
  const login = await f.request("/auth/login", {
    email: reg.email,
    password: "first-password-123",
  });
  assert.equal(login.status, 200);
  assert.equal(login.data.user.hasPassword, true);
});

function deferred() {
  let resolve;
  const promise = new Promise((r) => (resolve = r));
  return { promise, resolve };
}

test("login started before password reset cannot create a session with the old password", async (t) => {
  const entered = deferred(),
    release = deferred();
  let pause = true;
  const f = await fixture(t, {
    passwords: {
      hash: bcrypt.hash,
      compare: async (plain, encoded) => {
        const valid = await bcrypt.compare(plain, encoded);
        if (pause && plain === reg.password) {
          pause = false;
          entered.resolve();
          await release.promise;
        }
        return valid;
      },
    },
  });
  await register(f);
  const login = f.request("/auth/login", reg);
  await entered.promise;
  const next = await bcrypt.hash("reset-password-456", 4);
  f.db
    .prepare("UPDATE users SET password=? WHERE email=?")
    .run(next, reg.email);
  f.db.prepare("UPDATE sessions SET revoked=1").run();
  release.resolve();
  assert.equal((await login).status, 400);
  assert.equal(
    f.db.prepare("SELECT count(*) n FROM sessions WHERE revoked=0").get().n,
    0,
  );
  assert.equal(
    (
      await f.request("/auth/login", {
        email: reg.email,
        password: "reset-password-456",
      })
    ).status,
    200,
  );
});

test("password change in flight cannot overwrite a newer password reset", async (t) => {
  const entered = deferred(),
    release = deferred();
  const f = await fixture(t, {
    passwords: {
      compare: bcrypt.compare,
      hash: async (plain, cost) => {
        const encoded = await bcrypt.hash(plain, cost);
        if (plain === "losing-password-123") {
          entered.resolve();
          await release.promise;
        }
        return encoded;
      },
    },
  });
  await register(f);
  const changing = f.request("/auth/password/change", {
    oldPassword: reg.password,
    newPassword: "losing-password-123",
  });
  await entered.promise;
  await f.request("/auth/password/request", { email: reg.email });
  assert.equal(
    (
      await f.request("/auth/password/reset", {
        email: reg.email,
        code: f.sent.at(-1).code,
        newPassword: "winner-password-456",
      })
    ).status,
    200,
  );
  release.resolve();
  assert.equal((await changing).status, 401);
  assert.equal(
    (
      await f.request("/auth/login", {
        email: reg.email,
        password: "winner-password-456",
      })
    ).status,
    200,
  );
  assert.equal(
    (
      await f.request("/auth/login", {
        email: reg.email,
        password: "losing-password-123",
      })
    ).status,
    400,
  );
});

test("SMTP failure permits retry without clearing wrong-code attempts", async (t) => {
  let fail = false;
  const sent = [];
  const f = await fixture(t, {
    mail: {
      send: async (email, code) => {
        if (fail) throw Error("offline");
        sent.push(code);
      },
    },
  });
  await f.request("/auth/register", reg);
  const wrong = sent[0] === "000000" ? "111111" : "000000";
  for (let n = 0; n < 2; n++)
    await f.request("/auth/verify", { email: reg.email, code: wrong });
  f.advance(60001);
  fail = true;
  assert.equal((await f.request("/auth/register", reg)).status, 503);
  fail = false;
  assert.equal((await f.request("/auth/register", reg)).status, 202);
  assert.equal(
    f.db.prepare("SELECT attempts FROM challenges").get().attempts,
    2,
  );
  assert.equal(
    (await f.request("/auth/verify", { email: reg.email, code: sent.at(-1) }))
      .status,
    200,
  );
});

test("a delayed SMTP failure cannot change the cooldown of a newer email code", async (t) => {
  const entered = deferred(),
    release = deferred();
  const sent = [];
  let first = true;
  const f = await fixture(t, {
    mail: {
      send: async (email, code) => {
        if (first) {
          first = false;
          entered.resolve();
          await release.promise;
          throw Error("late failure");
        }
        sent.push(code);
      },
    },
  });
  const registering = f.request("/auth/register", reg);
  await entered.promise;
  f.advance(60001);
  assert.equal((await f.request("/auth/register", reg)).status, 202);
  release.resolve();
  assert.equal((await registering).status, 503);
  assert.equal((await f.request("/auth/register", reg)).status, 429);
  assert.equal(
    (await f.request("/auth/verify", { email: reg.email, code: sent.at(-1) }))
      .status,
    200,
  );
});

test("production cookies and headers enforce secure browser boundaries", async (t) => {
  const f = await fixture(t, { settings: { production: true } });
  const result = await register(f);
  const cookie = result.r.headers.getSetCookie().join(";");
  assert.match(cookie, /HttpOnly/i);
  assert.match(cookie, /Secure/i);
  assert.match(cookie, /SameSite=Strict/i);
  assert.equal(result.r.headers.get("x-content-type-options"), "nosniff");
  const csp = result.r.headers.get("content-security-policy");
  assert.ok(csp.includes("default-src 'self'"));
  assert.ok(!csp.includes("'unsafe-eval'"));
  const invalid = await f.request(
    "/saved",
    { changes: [] },
    { Cookie: "lingoy_csrf=forged.signature" },
  );
  assert.equal(invalid.status, 403);
});
test("SQL-shaped and invalid input cannot bypass accounts or damage the dictionary", async (t) => {
  const f = await fixture(t);
  assert.equal(
    (
      await f.request("/auth/login", {
        email: "' OR 1=1 --",
        password: reg.password,
      })
    ).status,
    400,
  );
  assert.equal(
    (
      await f.request(
        "/dictionary?q=" + encodeURIComponent("'; DROP TABLE users;--"),
      )
    ).status,
    200,
  );
  assert.equal(
    (await f.request("/dictionary?q=" + encodeURIComponent("x".repeat(161))))
      .status,
    400,
  );
  assert.equal(f.db.prepare("SELECT count(*) n FROM users").get().n, 0);
  await register(f);
  assert.equal(
    (
      await f.request("/saved", {
        changes: [
          { id: "bad-id-injection", word_id: "1 OR 1=1", deleted: false },
        ],
      })
    ).status,
    400,
  );
  assert.equal((await f.request("/saved")).data.words.length, 0);
});
test("valid images are resized to JPEG while unsupported SVG is rejected before AI", async (t) => {
  let captured;
  const f = await fixture(t, {
    generate: async (c, task, data) => {
      captured = data.image;
      return output;
    },
  });
  await register(f);
  const { default: sharp } = await import("sharp");
  const png = await sharp({
    create: { width: 1800, height: 1000, channels: 3, background: "#ffffff" },
  })
    .png()
    .toBuffer();
  assert.equal(
    (await f.request("/image/translate", { image: png.toString("base64") }))
      .status,
    200,
  );
  const metadata = await sharp(Buffer.from(captured, "base64")).metadata();
  assert.equal(metadata.format, "jpeg");
  assert.equal(metadata.width, 1600);
  const svg = Buffer.from(
    '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"></svg>',
  ).toString("base64");
  assert.equal(
    (await f.request("/image/translate", { image: svg })).status,
    400,
  );
  assert.equal((await f.request("/usage")).data.used, 1);
});
test("Google callback rejects another browser binding and invalid nonce", async (t) => {
  let params;
  const google = {
    generateAuthUrl: (p) => {
      params = p;
      return "https://accounts.google.com/o/oauth2/auth";
    },
    getToken: async () => ({ tokens: { id_token: "mock" } }),
    verifyIdToken: async () => ({
      getPayload: () => ({
        email: reg.email,
        email_verified: true,
        sub: "evil",
        nonce: "wrong",
      }),
    }),
  };
  const f = await fixture(t, { google });
  await f.request("/auth/google/start");
  const url = "/auth/google/callback?state=" + params.state + "&code=mock";
  assert.equal((await f.request(url, undefined, { Cookie: "" })).status, 400);
  assert.equal((await f.request(url)).status, 403);
  assert.equal((await f.request(url)).status, 400);
  assert.equal(f.db.prepare("SELECT count(*) n FROM users").get().n, 0);
});

test("expired, foreign-issuer and foreign-audience tokens cannot access an account", async (t) => {
  const f = await fixture(t);
  const registered = await register(f);
  const session = f.db.prepare("SELECT id FROM sessions WHERE revoked=0").get();
  for (const options of [
    { issuer: "evil", audience: "lingoy-client", expiresIn: 900 },
    { issuer: "lingoy", audience: "other-app", expiresIn: 900 },
    { issuer: "lingoy", audience: "lingoy-client", expiresIn: -1 },
  ]) {
    const token = jwt.sign(
      { sub: registered.data.user.id, sid: session.id },
      cfg.secret,
      options,
    );
    assert.equal(
      (await f.request("/me", undefined, { Authorization: "Bearer " + token }))
        .status,
      401,
    );
  }
  assert.equal((await f.request("/me")).status, 200);
});
test("download routes expose only APK, checksum and release metadata, with no server paths", async (t) => {
  const folder = mkdtempSync(path.join(os.tmpdir(), "lingoy-download-"));
  t.after(() => rmSync(folder, { recursive: true, force: true }));
  writeFileSync(path.join(folder, "Lingoy.apk"), "test-apk");
  writeFileSync(path.join(folder, "Lingoy.apk.sha256"), "test-hash");
  writeFileSync(path.join(folder, "private.zip"), "private");
  const service = createApp({ ...cfg, downloads: folder }, { quiet: true });
  const server = service.app.listen(0, "127.0.0.1");
  await new Promise((r) => server.once("listening", r));
  t.after(() => {
    server.close();
    service.closeDictionary();
    service.db.close();
  });
  const origin = "http://127.0.0.1:" + server.address().port;
  const apk = await fetch(origin + "/downloads/Lingoy.apk");
  assert.equal(apk.status, 200);
  assert.match(apk.headers.get("content-type"), /android.package-archive/);
  assert.equal(await apk.text(), "test-apk");
  const checksum = await fetch(origin + "/downloads/Lingoy.apk.sha256");
  assert.match(checksum.headers.get("content-type"), /text\/plain/);
  for (const file of ["private.zip", "missing.apk", "release.json"]) {
    const r = await fetch(origin + "/downloads/" + file);
    assert.equal(r.status, 404);
    assert.ok(!(await r.text()).includes(folder));
  }
});

test("editorial phrase meanings take priority over incorrect inherited translations", async (t) => {
  const f = await fixture(t);
  for (const [phrase, meaning] of [
    ["good book", "Bibliya"],
    ["reference book", "ma’lumotnoma"],
    ["book value", "balans"],
  ]) {
    const r = await f.request("/dictionary?q=" + encodeURIComponent(phrase));
    assert.equal(r.status, 200);
    assert.ok(
      r.data.words
        .find((w) => w.lemma === phrase)
        .translation.includes(meaning),
    );
  }
});

test("Google root redirect uses a root-scoped binding cookie and preserves the configured token redirect", async (t) => {
  let params, exchange;
  const google = {
    generateAuthUrl: (p) => {
      params = p;
      return "https://accounts.google.com/o/oauth2/auth";
    },
    getToken: async (p) => {
      exchange = p;
      return { tokens: { id_token: "fixture" } };
    },
    verifyIdToken: async () => ({
      getPayload: () => ({
        sub: "root-user",
        email: "root@gmail.com",
        email_verified: true,
        name: "Root User",
        picture: "https://lh3.googleusercontent.com/a/root",
        nonce: params.nonce,
      }),
    }),
  };
  const f = await fixture(t, {
    settings: {
      origin: "https://lingoy.uz",
      production: true,
      redirect: "https://lingoy.uz",
    },
    google,
  });
  const start = await f.request("/auth/google/start");
  assert.equal(start.status, 302);
  const cookie = start.r.headers
    .getSetCookie()
    .find((x) => x.startsWith("lingoy_oauth="));
  assert.match(cookie, /Path=\/(?:;|$)/);
  assert.match(cookie, /HttpOnly/);
  assert.match(cookie, /Secure/);
  assert.match(cookie, /SameSite=Lax/);
  assert.equal(params.redirect_uri, "https://lingoy.uz");
  const callback = await f.rootRequest(
    "/?" + new URLSearchParams({ state: params.state, code: "root-code" }),
  );
  assert.equal(callback.status, 302);
  assert.equal(
    callback.r.headers.get("location"),
    "https://lingoy.uz/?auth=success",
  );
  assert.equal(exchange.redirect_uri, "https://lingoy.uz");
  const refresh = await f.request("/auth/refresh", {});
  assert.equal(refresh.status, 200);
  assert.equal(
    refresh.data.user.picture,
    "https://lh3.googleusercontent.com/a/root",
  );
  assert.equal(
    (
      await f.rootRequest(
        "/?" + new URLSearchParams({ state: params.state, code: "root-code" }),
      )
    ).status,
    400,
  );
});

test("Google root cancellation consumes state, clears the matching cookie and does not exchange tokens", async (t) => {
  let params,
    exchanges = 0;
  const google = {
    generateAuthUrl: (p) => {
      params = p;
      return "https://accounts.google.com/o/oauth2/auth";
    },
    getToken: async () => {
      exchanges++;
      throw Error("must not exchange");
    },
  };
  const f = await fixture(t, {
    settings: {
      origin: "https://lingoy.uz",
      production: true,
      redirect: "https://lingoy.uz",
    },
    google,
  });
  await f.request("/auth/google/start");
  const r = await f.rootRequest(
    "/?" + new URLSearchParams({ state: params.state, error: "access_denied" }),
  );
  assert.equal(r.status, 302);
  assert.equal(
    r.r.headers.get("location"),
    "https://lingoy.uz/?auth=cancelled",
  );
  assert.equal(exchanges, 0);
  assert.equal(f.db.prepare("SELECT count(*) n FROM oauth").get().n, 0);
  assert.match(
    r.r.headers.getSetCookie().find((x) => x.startsWith("lingoy_oauth=")),
    /Path=\/(?:;|$)/,
  );
  assert.equal(
    (
      await f.rootRequest(
        "/?" +
          new URLSearchParams({ state: params.state, error: "access_denied" }),
      )
    ).status,
    400,
  );
});

test("Google root callback retains mobile one-time ticket verification and cancels pending tickets promptly", async (t) => {
  let params;
  const google = {
    generateAuthUrl: (p) => {
      params = p;
      return "https://accounts.google.com/o/oauth2/auth";
    },
    getToken: async () => ({ tokens: { id_token: "fixture" } }),
    verifyIdToken: async () => ({
      getPayload: () => ({
        sub: "mobile-root",
        email: "mobileroot@gmail.com",
        email_verified: true,
        name: "Mobile Root",
        nonce: params.nonce,
      }),
    }),
  };
  const f = await fixture(t, {
    settings: {
      origin: "https://lingoy.uz",
      production: true,
      redirect: "https://lingoy.uz",
    },
    google,
  });
  const verifier = random();
  const mobile = await f.request("/auth/mobile/start", {
    challenge: challenge(verifier),
  });
  await f.request("/auth/google/start?ticket=" + mobile.data.ticket);
  const done = await f.rootRequest(
    "/?" + new URLSearchParams({ state: params.state, code: "mobile-code" }),
  );
  assert.equal(done.status, 200);
  assert.match(done.data, /Kirish muvaffaqiyatli/);
  assert.equal(
    (
      await f.request("/auth/mobile/poll", {
        ticket: mobile.data.ticket,
        verifier,
      })
    ).status,
    200,
  );
  assert.equal(
    (
      await f.request("/auth/mobile/poll", {
        ticket: mobile.data.ticket,
        verifier,
      })
    ).status,
    400,
  );
  const nextVerifier = random();
  const cancel = await f.request("/auth/mobile/start", {
    challenge: challenge(nextVerifier),
  });
  await f.request("/auth/google/start?ticket=" + cancel.data.ticket);
  const denied = await f.rootRequest(
    "/?" + new URLSearchParams({ state: params.state, error: "access_denied" }),
  );
  assert.equal(denied.status, 200);
  assert.match(denied.data, /Kirish bekor qilindi/);
  assert.equal(
    (
      await f.request("/auth/mobile/poll", {
        ticket: cancel.data.ticket,
        verifier: nextVerifier,
      })
    ).status,
    400,
  );
});

test('Dictionary aliases, primary synonym sense and new canonical slang survive API sync', async t => {
  const f = await fixture(t);
  const corrected = await f.request('/dictionary?q=lalluby');
  assert.equal(corrected.status, 200);
  assert.equal(corrected.data.words[0].lemma, 'lullaby');
  assert.match(corrected.data.words[0].translation, /alla/);
  const big = (await f.request('/dictionary?q=big')).data.words[0];
  const detail = (await f.request('/dictionary/' + big.id)).data;
  assert.ok(JSON.parse(detail.senses[0].words).includes('large'));
  const slang = (await f.request('/dictionary?q=no%20cap')).data.words[0];
  assert.ok(slang.id >= 2000000000);
  assert.match((await f.request('/dictionary/' + slang.id)).data.word.translation, /rost/);
  await register(f);
  const result = await f.request('/saved', {changes:[{id:'canonical-slang-sync-330',word_id:slang.id,deleted:false}]});
  assert.equal(result.status, 200);
  assert.equal((await f.request('/saved')).data.words[0].word_id, slang.id);
});

test("Uzbek reverse search ranks complete glosses before longer prefix words", async t=>{
 const f=await fixture(t);const r=await f.request('/dictionary?q=olma&reverse=1');
 assert.equal(r.status,200);assert.ok(r.data.words.slice(0,5).some(w=>w.lemma==='apple'));
 const en=await f.request('/dictionary?q=book');assert.equal(en.data.words[0].lemma,'book');
});
