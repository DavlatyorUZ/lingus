import fs from "node:fs";
import path from "node:path";
import { preflight } from "./preflight.js";
import { liveChecks } from "./diagnostics.js";
import { version } from "./version.js";

export async function productionChecks(c, options = {}) {
  const configuration = (options.preflight || preflight)(c);
  const manual_pending = [
    "Email qutisiga kod kelishi va ilovada tasdiqlanishi",
    "Google orqali kirish va haqiqiy profil rasmi",
    "Fizik Android qurilmada o‘rnatish",
  ];
  if (!configuration.ready || !c.production || c.origin !== "https://lingoy.uz")
    return {
      automatic_ok: false,
      configuration,
      checks: [],
      manual_pending,
      message:
        "Konfiguratsiya tekshiruvdan o‘tmadi. Tashqi tekshiruv boshlanmadi.",
    };
  const fetcher = options.fetcher || fetch;
  const release =
    options.release ||
    JSON.parse(fs.readFileSync(path.join(c.downloads, "release.json"), "utf8"));
  const jobs = [
    [
      "public_pwa",
      c.origin + "/",
      {},
      async (response) => {
        const policy = response.headers.get("content-security-policy") || "";
        return (
          response.status === 200 &&
          response.headers.get("x-content-type-options") === "nosniff" &&
          /max-age=\d+/.test(
            response.headers.get("strict-transport-security") || "",
          ) &&
          policy.includes("script-src 'self'") &&
          policy.includes("object-src 'none'") &&
          (await response.text()).includes("Lingoy")
        );
      },
    ],
    [
      "public_api",
      c.origin + "/api/v1/health",
      {},
      async (response) => {
        if (response.status !== 200) return false;
        const data = await response.json();
        return (
          data.status === "ready" &&
          data.version === version &&
          !!data.release_id
        );
      },
    ],
    [
      "http_redirect",
      "http://lingoy.uz/",
      {},
      async (response) =>
        [301, 308].includes(response.status) &&
        new URL(response.headers.get("location") || "", "http://lingoy.uz/")
          .href ===
          c.origin + "/",
    ],
    [
      "www_redirect",
      "https://www.lingoy.uz/",
      {},
      async (response) =>
        [301, 308].includes(response.status) &&
        new URL(
          response.headers.get("location") || "",
          "https://www.lingoy.uz/",
        ).href ===
          c.origin + "/",
    ],
    [
      "public_apk",
      c.origin + "/downloads/Lingoy.apk",
      { method: "HEAD" },
      async (response) =>
        response.status === 200 &&
        response.headers.get("content-type")?.split(";")[0] ===
          "application/vnd.android.package-archive" &&
        Number(response.headers.get("content-length")) === release.bytes,
    ],
    [
      "pwa_manifest",
      c.origin + "/manifest.webmanifest",
      {},
      async (response) => {
        if (response.status !== 200) return false;
        const data = await response.json();
        return (
          data.short_name === "Lingoy" &&
          data.name?.startsWith("Lingoy") &&
          data.display === "standalone" &&
          data.icons?.some((icon) => icon.sizes === "512x512")
        );
      },
    ],
    [
      "robots",
      c.origin + "/robots.txt",
      {},
      async (response) =>
        response.status === 200 &&
        (await response.text()).includes(c.origin + "/sitemap.xml"),
    ],
    [
      "sitemap",
      c.origin + "/sitemap.xml",
      {},
      async (response) =>
        response.status === 200 && (await response.text()).includes(c.origin),
    ],
  ];
  async function probe([name, url, init, validate]) {
    try {
      const response = await fetcher(url, {
        ...init,
        redirect: "manual",
        signal: AbortSignal.timeout(12000),
      });
      try {
        const valid = await validate(response);
        return {
          name,
          status: valid ? "pass" : "fail",
          http_status: response.status,
          code: valid ? "verified" : "unexpected_response",
        };
      } finally {
        try {
          await response.body?.cancel();
        } catch {}
      }
    } catch {
      return {
        name,
        status: "fail",
        code: "network_or_tls",
        message: "Ushbu muhitdan tarmoq yoki HTTPS tekshiruvi yakunlanmadi.",
      };
    }
  }
  const [checks, services] = await Promise.all([
    Promise.all(jobs.map(probe)),
    (options.live || liveChecks)(c),
  ]);
  return {
    automatic_ok: checks.every((x) => x.status === "pass") && services.ok,
    configuration,
    checks,
    services,
    manual_pending,
  };
}
