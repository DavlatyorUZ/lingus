import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { DatabaseSync } from "node:sqlite";
import { pathToFileURL } from "node:url";
import { config } from "./config.js";
import { version } from './version.js';

export function preflight(c) {
  const checks = [];
  const check = (name, run) => {
    try {
      run();
      checks.push({ name, status: "pass" });
    } catch {
      checks.push({ name, status: "fail" });
    }
  };
  const requireValue = (value) => {
    if (!value) throw Error();
  };
  check("node_24_or_newer", () =>
    requireValue(Number(process.versions.node.split(".")[0]) >= 24),
  );
  check("production_https_origin", () =>
    requireValue(c.production && c.origin === "https://lingoy.uz"),
  );
  check("private_backend_binding", () =>
    requireValue(c.host === "127.0.0.1" && c.port === 8080),
  );
  check("daily_limit", () =>
    requireValue(Number.isInteger(c.daily) && c.daily > 0 && c.daily <= 1000),
  );
  check("managed_database_path", () =>
    requireValue(
      [
        "./data/lingoy.sqlite",
        "data/lingoy.sqlite",
        "/srv/lingoy/shared/data/lingoy.sqlite",
      ].includes(c.db),
    ),
  );
  check("jwt_secret", () =>
    requireValue(typeof c.secret === "string" && c.secret.length >= 32),
  );
  check("gmail_configured", () =>
    requireValue(
      /^[^\s@]+@gmail\.com$/i.test(c.gmail || "") &&
        c.gmailPassword?.length >= 10,
    ),
  );
  check("google_redirect", () =>
    requireValue(
      c.googleId?.endsWith(".apps.googleusercontent.com") &&
        c.googleSecret &&
        [
          c.origin,
          c.origin + "/",
          c.origin + "/api/v1/auth/google/callback",
        ].includes(c.redirect),
    ),
  );
  check("gmail_app_password_format", () =>
    requireValue(/^[a-z]{16}$/i.test((c.gmailPassword || '').replace(/\s+/g,''))),
  );
  check("ai_configured", () =>
    requireValue(
      c.aiKey?.length >= 10 && new URL(c.aiBase).protocol === "https:",
    ),
  );
  check("dictionary_integrity", () => {
    const db = new DatabaseSync(c.dictionary, { readOnly: true });
    try {
      requireValue(
        db.prepare("PRAGMA integrity_check").get().integrity_check === "ok" &&
          db.prepare("SELECT count(*) n FROM entries").get().n > 140000,
      );
    } finally {
      db.close();
    }
  });
  check("pwa_build", () =>
    requireValue(
      fs.existsSync(path.join(c.web, "index.html")) &&
        fs.existsSync(path.join(c.web, "sw.js")) &&
        fs.existsSync(path.join(c.web, "manifest.webmanifest")),
    ),
  );
  check("apk_checksum", () => {
    const apk = fs.readFileSync(path.join(c.downloads, "Lingoy.apk"));
    const release = JSON.parse(
      fs.readFileSync(path.join(c.downloads, "release.json"), "utf8"),
    );
    requireValue(
      apk.length === release.bytes &&
        crypto.createHash("sha256").update(apk).digest("hex") ===
          release.sha256,
    );
  });
  check('release_version', () => {
    const android = JSON.parse(fs.readFileSync(path.join(c.downloads, 'release.json'), 'utf8'));
    const web = JSON.parse(fs.readFileSync(path.join(c.web, 'release.json'), 'utf8'));
    requireValue(android.version === version && web.version === version);
    requireValue(typeof web.quizBank === 'string' && /^\/data-quiz-bank-[a-f0-9]{12}\.json$/.test(web.quizBank));
    requireValue(fs.existsSync(path.join(c.web, web.quizBank.slice(1))));
  });
  return {
    ready: checks.every((c) => c.status === "pass"),
    checks,
    external_pending: [
      "Gmail delivery",
      "Google consent and actual sign-in",
      "VPS DNS and HTTPS",
    ],
  };
}
if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href
) {
  try {
    const result = preflight(config());
    console.log(JSON.stringify(result, null, 2));
    if (!result.ready) process.exitCode = 1;
  } catch {
    console.error("Konfiguratsiyani server .env faylida tekshiring.");
    process.exitCode = 1;
  }
}
