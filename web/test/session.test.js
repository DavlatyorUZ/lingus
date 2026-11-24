import test from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
const a = {
  id: "account-a",
  name: "Ali",
  email: "a@example.com",
  hasPassword: true,
};
const b = {
  id: "account-b",
  name: "Vali",
  email: "b@example.com",
  hasPassword: true,
};
async function fixture(t, handler, initial = null) {
  const saved = {
    fetch: globalThis.fetch,
    window: globalThis.window,
    localStorage: globalThis.localStorage,
    navigator: Object.getOwnPropertyDescriptor(globalThis, "navigator"),
  };
  const data = new Map();
  if (initial !== null) data.set("lingoy-user", initial);
  globalThis.window = new EventTarget();
  globalThis.localStorage = {
    getItem: (k) => data.get(k) || null,
    setItem: (k, v) => data.set(k, v),
  };
  Object.defineProperty(globalThis, "navigator", {
    configurable: true,
    value: { locks: { request: async (_, fn) => fn() } },
  });
  globalThis.fetch = async (url, options) => {
    const r = await handler(url, options);
    return new Response(JSON.stringify(r.body), {
      status: r.status || 200,
      headers: { "Content-Type": "application/json" },
    });
  };
  t.after(() => {
    globalThis.fetch = saved.fetch;
    globalThis.window = saved.window;
    globalThis.localStorage = saved.localStorage;
    if (saved.navigator)
      Object.defineProperty(globalThis, "navigator", saved.navigator);
  });
  const api = await import("../src/api.js?test=" + randomUUID());
  return { ...api, live: api, data };
}
test("same-account token refresh preserves the current screen and unsent input", async (t) => {
  const f = await fixture(t, async (url) =>
    url.endsWith("/csrf")
      ? { body: { csrfToken: "csrf" } }
      : { body: { user: a, accessToken: "rotated" } },
  );
  let changes = 0;
  window.addEventListener("accountchange", () => changes++);
  f.accept({ user: a, accessToken: "first" });
  await f.refresh();
  assert.equal(changes, 1);
  assert.equal(f.live.user.id, a.id);
});
test("saved-word changes cannot be replayed into a different account after refresh", async (t) => {
  let posts = 0;
  const f = await fixture(t, async (url) => {
    if (url.endsWith("/csrf")) return { body: { csrfToken: "csrf" } };
    if (url.endsWith("/refresh"))
      return { body: { user: b, accessToken: "b-token" } };
    posts++;
    return { status: 401, body: { message: "expired" } };
  });
  f.accept({ user: a, accessToken: "old-a-token" });
  await assert.rejects(
    f.api("/saved", { method: "POST", body: { changes: [{ word_id: 1 }] } }),
    (e) => e.status === 401 && e.message.includes("Akkaunt"),
  );
  assert.equal(posts, 1);
  assert.equal(f.live.user.id, b.id);
});
test("another tab logging out immediately clears this tab account view", async (t) => {
  const f = await fixture(t, async () => ({ body: {} }));
  f.accept({ user: a, accessToken: "a-token" });
  const event = new Event("storage");
  Object.assign(event, { key: "lingoy-user", newValue: "null" });
  window.dispatchEvent(event);
  assert.equal(f.live.user, null);
});
test("corrupt cached profiles do not break application startup", async (t) => {
  const f = await fixture(
    t,
    async () => ({ body: {} }),
    JSON.stringify({ id: "invalid", name: null, email: 5 }),
  );
  assert.equal(f.live.user, null);
});
test("account changes during CSRF loading cannot send a queued mutation", async (t) => {
  let posts = 0,
    f;
  f = await fixture(t, async (url) => {
    if (url.endsWith("/csrf")) {
      f.accept({ user: b, accessToken: "b-token" });
      return { body: { csrfToken: "new" } };
    }
    posts++;
    return { body: {} };
  });
  f.accept({ user: a, accessToken: "a-token" });
  await assert.rejects(
    f.api("/saved", { method: "POST", body: { changes: [] } }),
    (e) => e.status === 401,
  );
  assert.equal(posts, 0);
});
