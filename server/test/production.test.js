import test from "node:test";
import assert from "node:assert/strict";
import { productionChecks } from "../src/production-checks.js";
import { version } from "../src/version.js";
const c = { production: true, origin: "https://lingoy.uz" };
const preflight = () => ({ ready: true, checks: [] });
const live = async () => ({
  ok: true,
  checks: [],
  email_delivery_verified: false,
});
const release = { bytes: 12345 };
function fixture(changes = {}) {
  const responses = {
    "https://lingoy.uz/": () =>
      new Response("<html>Lingoy</html>", {
        headers: {
          "content-security-policy":
            "default-src 'self'; script-src 'self'; object-src 'none'",
          "x-content-type-options": "nosniff",
          "strict-transport-security": "max-age=31536000",
        },
      }),
    "https://lingoy.uz/api/v1/health": () =>
      Response.json({ status: "ready", version, release_id: "qa-release" }),
    "http://lingoy.uz/": () =>
      new Response(null, {
        status: 301,
        headers: { location: "https://lingoy.uz/" },
      }),
    "https://www.lingoy.uz/": () =>
      new Response(null, {
        status: 301,
        headers: { location: "https://lingoy.uz/" },
      }),
    "https://lingoy.uz/downloads/Lingoy.apk": () =>
      new Response(null, {
        headers: {
          "content-type": "application/vnd.android.package-archive",
          "content-length": "12345",
        },
      }),
    "https://lingoy.uz/manifest.webmanifest": () =>
      Response.json({
        name: "Lingoy — lug‘at va tarjima",
        short_name: "Lingoy",
        display: "standalone",
        icons: [{ sizes: "512x512" }],
      }),
    "https://lingoy.uz/robots.txt": () =>
      new Response("Sitemap: https://lingoy.uz/sitemap.xml"),
    "https://lingoy.uz/sitemap.xml": () =>
      new Response("<urlset><url><loc>https://lingoy.uz/</loc></url></urlset>"),
    ...changes,
  };
  return async (url, options) => {
    assert.equal(options.redirect, "manual");
    assert.ok(options.signal);
    assert.ok(responses[url], url);
    return responses[url]();
  };
}
test("production check validates all public endpoints but retains manual Google and inbox checks", async () => {
  const report = await productionChecks(c, {
    preflight,
    live,
    release,
    fetcher: fixture(),
  });
  assert.equal(report.automatic_ok, true);
  assert.equal(report.checks.length, 8);
  assert.ok(report.checks.every((x) => x.status === "pass"));
  assert.equal(report.services.email_delivery_verified, false);
  assert.ok(report.manual_pending.some((x) => x.includes("Google")));
});
test("an older running backend cannot pass a new release production check", async () => {
  const report = await productionChecks(c, {
    preflight,
    live,
    release,
    fetcher: fixture({
      "https://lingoy.uz/api/v1/health": () =>
        Response.json({
          status: "ready",
          version: "older-release",
          release_id: "old",
        }),
    }),
  });
  assert.equal(report.automatic_ok, false);
  assert.equal(
    report.checks.find((x) => x.name === "public_api").status,
    "fail",
  );
});
test("foreign redirects and an incorrect APK size fail without following another site", async () => {
  const report = await productionChecks(c, {
    preflight,
    live,
    release,
    fetcher: fixture({
      "http://lingoy.uz/": () =>
        new Response(null, {
          status: 301,
          headers: { location: "https://unrelated.example/" },
        }),
      "https://lingoy.uz/downloads/Lingoy.apk": () =>
        new Response(null, {
          headers: { "content-type": "text/html", "content-length": "12345" },
        }),
    }),
  });
  assert.equal(report.automatic_ok, false);
  for (const name of ["http_redirect", "public_apk"])
    assert.equal(report.checks.find((x) => x.name === name).status, "fail");
});
test("invalid production configuration stops checks before any outbound request", async () => {
  let requested = 0;
  const never = async () => {
    requested++;
    throw Error("network must not run");
  };
  const report = await productionChecks(c, {
    preflight: () => ({ ready: false, checks: [] }),
    live: never,
    fetcher: never,
  });
  assert.equal(report.automatic_ok, false);
  assert.equal(requested, 0);
  const unsafe = await productionChecks(
    { ...c, origin: "https://unrelated.example" },
    { preflight, live: never, fetcher: never },
  );
  assert.equal(unsafe.automatic_ok, false);
  assert.equal(requested, 0);
});
test("network or TLS failure never exposes raw exception data or masquerades as a verified endpoint", async () => {
  const secret = "private-network-fixture";
  const report = await productionChecks(c, {
    preflight,
    live,
    release,
    fetcher: async () => {
      throw Error(secret);
    },
  });
  assert.equal(report.automatic_ok, false);
  assert.ok(report.checks.every((x) => x.code === "network_or_tls"));
  assert.ok(!JSON.stringify(report).includes(secret));
});
