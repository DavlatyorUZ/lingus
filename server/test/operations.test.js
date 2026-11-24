import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { DatabaseSync } from "node:sqlite";
import { openDb } from "../src/db.js";
const root = fileURLToPath(new URL("../../", import.meta.url));
function fixture(t) {
  const base = fs.mkdtempSync(path.join(os.tmpdir(), "lingoy-ops-"));
  t.after(() => fs.rmSync(base, { recursive: true, force: true }));
  for (const name of ["shared/data", "shared/backups", "current", "bin"])
    fs.mkdirSync(path.join(base, name), { recursive: true });
  fs.symlinkSync(
    path.join(root, "deploy"),
    path.join(base, "current/deploy"),
    "dir",
  );
  const executable = (name, text) =>
    fs.writeFileSync(
      path.join(base, "bin", name),
      "#!/usr/bin/env bash\nset -eu\n" + text,
      { mode: 0o755 },
    );
  executable("pm2", 'printf "%s\\n" "$*" >> "$LINGOY_HOME/pm2-calls"\n');
  executable("df", "exit 0\n");
  executable(
    "curl",
    'n=0\n[[ ! -f "$LINGOY_HOME/curl-count" ]] || read -r n < "$LINGOY_HOME/curl-count"\nn=$((n+1))\nprintf "%s\\n" "$n" > "$LINGOY_HOME/curl-count"\n[[ "$n" -gt "${FAKE_CURL_FAILURES:-0}" ]] || exit 7\nprintf \'{"status":"ready"}\\n\'\n',
  );
  const file = path.join(base, "shared/data/lingoy.sqlite");
  const db = openDb(file);
  db.prepare("INSERT INTO users(id,email,name) VALUES(?,?,?)").run(
    "fixture",
    "qa@example.com",
    "Avvalgi ism",
  );
  db.close();
  return {
    base,
    file,
    run(script, arg, extra = {}) {
      return spawnSync(
        "bash",
        [path.join(root, "deploy", script), ...(arg ? [arg] : [])],
        {
          encoding: "utf8",
          timeout: 45000,
          env: {
            ...process.env,
            PATH: path.join(base, "bin") + path.delimiter + process.env.PATH,
            LINGOY_HOME: base,
            LINGOY_HEALTH_ATTEMPTS: "3",
            ...extra,
          },
        },
      );
    },
    backups() {
      return fs
        .readdirSync(path.join(base, "shared/backups"))
        .filter((x) => x.endsWith(".sqlite"))
        .map((x) => path.join(base, "shared/backups", x));
    },
  };
}
function name(file) {
  const db = new DatabaseSync(file, { readOnly: true });
  try {
    return db.prepare("SELECT name FROM users").get().name;
  } finally {
    db.close();
  }
}
test("restore rejects a partial users-only database before stopping the application", (t) => {
  const f = fixture(t),
    bad = path.join(f.base, "shared/backups/partial.sqlite");
  const db = new DatabaseSync(bad);
  db.exec("CREATE TABLE users(id TEXT PRIMARY KEY,email TEXT)");
  db.close();
  const result = f.run("restore.sh", bad);
  assert.notEqual(result.status, 0, "An incomplete backup must be rejected");
  assert.equal(
    fs.existsSync(path.join(f.base, "pm2-calls")),
    false,
    "Validation must precede service interruption",
  );
  assert.equal(name(f.file), "Avvalgi ism");
});
test("healthcheck waits for a restarting backend instead of reporting a false restore failure", (t) => {
  const f = fixture(t),
    result = f.run("healthcheck.sh", null, { FAKE_CURL_FAILURES: "2" });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(
    fs.readFileSync(path.join(f.base, "curl-count"), "utf8").trim(),
    "3",
  );
});
test("backup rejects foreign-key damage and publishes no usable backup file", (t) => {
  const f = fixture(t),
    db = new DatabaseSync(f.file);
  db.exec(
    "PRAGMA foreign_keys=OFF;INSERT INTO saved VALUES('missing-user',1,0,1)",
  );
  db.close();
  const result = f.run("backup.sh");
  assert.notEqual(
    result.status,
    0,
    "Integrity alone cannot establish relational consistency",
  );
  assert.deepEqual(f.backups(), []);
});
test("backup and restore recover the original account while retaining the previous database", (t) => {
  const f = fixture(t);
  assert.equal(f.run("backup.sh").status, 0);
  const backup = f.backups()[0];
  const db = new DatabaseSync(f.file);
  db.prepare("UPDATE users SET name=?").run("Yangi ism");
  db.close();
  const result = f.run("restore.sh", backup);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(name(f.file), "Avvalgi ism");
  const previous = fs
    .readdirSync(path.join(f.base, "shared/backups"))
    .find((x) => x.startsWith("before-restore-"));
  assert.equal(
    name(path.join(f.base, "shared/backups", previous, "data/lingoy.sqlite")),
    "Yangi ism",
  );
});
test("failed post-restore health recovers the database that was active before restore", (t) => {
  const f = fixture(t);
  assert.equal(f.run("backup.sh").status, 0);
  const backup = f.backups()[0];
  const db = new DatabaseSync(f.file);
  db.prepare("UPDATE users SET name=?").run("Tiklashdan oldingi ism");
  db.close();
  const result = f.run("restore.sh", backup, {
    FAKE_CURL_FAILURES: "100",
    LINGOY_HEALTH_ATTEMPTS: "2",
  });
  assert.notEqual(result.status, 0);
  assert.equal(name(f.file), "Tiklashdan oldingi ism");
});
test("restore rejects a symlink escaping the private backup directory", (t) => {
  const f = fixture(t),
    outside = path.join(f.base, "outside.sqlite");
  fs.copyFileSync(f.file, outside);
  const link = path.join(f.base, "shared/backups/link.sqlite");
  fs.symlinkSync(outside, link);
  assert.notEqual(f.run("restore.sh", link).status, 0);
  assert.equal(fs.existsSync(path.join(f.base, "pm2-calls")), false);
});
test("online SQLite backup includes committed WAL data while the writer stays open", (t) => {
  const f = fixture(t),
    db = openDb(f.file);
  try {
    db.prepare("UPDATE users SET name=?").run("WAL ichidagi ism");
    assert.equal(f.run("backup.sh").status, 0);
    assert.equal(name(f.backups()[0]), "WAL ichidagi ism");
  } finally {
    db.close();
  }
});
