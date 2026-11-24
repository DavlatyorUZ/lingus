import test from "node:test";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import { preflight } from "../src/preflight.js";
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
const root = fileURLToPath(new URL("../../", import.meta.url));
const good = {
  production: true,
  origin: "https://lingoy.uz",
  host: "127.0.0.1",
  port: 8080,
  daily: 30,
  db: "./data/lingoy.sqlite",
  secret: "test-private-secret-with-at-least-thirty-two-characters",
  gmail: "fixture@gmail.com",
  gmailPassword: "abcdefghijklmnop",
  googleId: "test.apps.googleusercontent.com",
  googleSecret: "test-google-secret",
  redirect: "https://lingoy.uz/api/v1/auth/google/callback",
  aiKey: "test-gemini-key",
  aiBase: "https://generativelanguage.googleapis.com/v1beta",
  dictionary: root + "mobile/assets/dictionary.db",
  web: root + "web/dist",
  downloads: root + "downloads",
};
test("release preflight checks actual database, PWA and APK integrity without exposing credentials", () => {
  const r = preflight(good);
  assert.equal(r.ready, true);
  const text = JSON.stringify(r);
  for (const key of ["secret", "gmailPassword", "googleSecret", "aiKey"])
    assert.ok(!text.includes(good[key]));
});
test("unsafe production bindings and inconsistent OAuth redirect stop deployment", () => {
  const r = preflight({
    ...good,
    host: "0.0.0.0",
    port: 3000,
    redirect: "http://example.com/callback",
    daily: NaN,
    db: "/tmp/unmanaged.sqlite",
  });
  assert.equal(r.ready, false);
  for (const name of [
    "private_backend_binding",
    "google_redirect",
    "daily_limit",
    "managed_database_path",
  ])
    assert.equal(r.checks.find((x) => x.name === name).status, "fail");
});
test('A normal Gmail password cannot pass production email configuration checks',()=>{
 const result=preflight({...good,gmailPassword:'normal-account-password'});
 assert.equal(result.ready,false);
 assert.equal(result.checks.find(c=>c.name==='gmail_app_password_format').status,'fail');
 assert.ok(!JSON.stringify(result).includes('normal-account-password'));
});
test('A valid APK checksum cannot hide an older app in a newer server release', t => {
  const downloads = fs.mkdtempSync(path.join(os.tmpdir(), 'lingoy-stale-apk-'));
  t.after(() => fs.rmSync(downloads, {recursive:true, force:true}));
  fs.copyFileSync(path.join(good.downloads, 'Lingoy.apk'), path.join(downloads, 'Lingoy.apk'));
  const release = JSON.parse(fs.readFileSync(path.join(good.downloads, 'release.json'), 'utf8'));
  release.version = '0.0.1';
  fs.writeFileSync(path.join(downloads, 'release.json'), JSON.stringify(release));
  const r = preflight({...good, downloads});
  assert.equal(r.checks.find(c => c.name === 'apk_checksum').status, 'pass');
  assert.equal(r.checks.find(c => c.name === 'release_version').status, 'fail');
  assert.equal(r.ready, false);
});
