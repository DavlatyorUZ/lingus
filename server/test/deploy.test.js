import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
const root = fileURLToPath(new URL("../../", import.meta.url));
function fixture(t) {
  const work = fs.mkdtempSync(path.join(os.tmpdir(), "lingoy-deploy-"));
  t.after(() => fs.rmSync(work, { recursive: true, force: true }));
  const base = path.join(work, "home"),
    source = path.join(work, "source"),
    bin = path.join(work, "bin");
  for (const dir of [
    bin,
    base + "/shared",
    base + "/releases/previous/deploy",
    source + "/server",
    source + "/web/dist",
    source + "/downloads",
    source + "/deploy",
  ])
    fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(base + "/shared/.env", "NODE_ENV=production\n");
  fs.writeFileSync(source + "/web/dist/index.html", "Lingoy");
  fs.writeFileSync(source + "/downloads/Lingoy.apk", "fixture");
  fs.writeFileSync(
    source + "/deploy/ecosystem.config.cjs",
    "module.exports={}",
  );
  fs.writeFileSync(
    base + "/releases/previous/deploy/ecosystem.config.cjs",
    "module.exports={}",
  );
  fs.symlinkSync(base + "/releases/previous", base + "/current", "dir");
  const executable = (file, body) =>
    fs.writeFileSync(file, "#!/usr/bin/env bash\nset -eu\n" + body, {
      mode: 0o755,
    });
  executable(
    source + "/deploy/backup.sh",
    'echo backup >> "$LINGOY_HOME/events"\n',
  );
  executable(
    source + "/deploy/verify.sh",
    'echo public-check >> "$LINGOY_HOME/events"\nexit "${FAIL_PUBLIC:-0}"\n',
  );
  executable(bin + "/npm", 'echo "npm $*" >> "$LINGOY_HOME/events"\n');
  executable(bin + "/pm2", 'echo "pm2 $*" >> "$LINGOY_HOME/events"\n');
  executable(
    bin + "/curl",
    'release="$(basename "$(readlink -f "$LINGOY_HOME/current")")"\nprintf \'{"status":"ready","release_id":"%s"}\\n\' "$release"\n',
  );
  fs.writeFileSync(
    bin + "/rsync",
    `#!/usr/bin/env python3
import shutil,sys
shutil.copytree(sys.argv[-2],sys.argv[-1],dirs_exist_ok=True,ignore=shutil.ignore_patterns('.env','node_modules','.dart_tool','build','.preview'))
`,
    { mode: 0o755 },
  );
  return {
    base,
    source,
    run(extra = {}) {
      return spawnSync("bash", [path.join(root, "deploy/deploy.sh"), source], {
        encoding: "utf8",
        timeout: 20000,
        env: {
          ...process.env,
          PATH: bin + path.delimiter + process.env.PATH,
          LINGOY_HOME: base,
          ...extra,
        },
      });
    },
    events() {
      return fs
        .readFileSync(base + "/events", "utf8")
        .trim()
        .split("\n");
    },
  };
}
test("release deployment verifies the public site before saving the PM2 state", (t) => {
  const f = fixture(t),
    r = f.run();
  assert.equal(r.status, 0, r.stderr);
  const events = f.events();
  assert.ok(events.includes("npm run preflight"));
  assert.ok(events.includes("public-check"));
  assert.ok(events.includes("pm2 save"));
  assert.ok(events.indexOf("public-check") < events.indexOf("pm2 save"));
  assert.notEqual(
    fs.realpathSync(f.base + "/current"),
    f.base + "/releases/previous",
  );
  assert.equal(
    fs.realpathSync(f.base + "/current/server/.env"),
    f.base + "/shared/.env",
  );
});
test("a failed public check rolls the release pointer back and does not save the failed process state", (t) => {
  const f = fixture(t),
    r = f.run({ FAIL_PUBLIC: "1" });
  assert.notEqual(r.status, 0);
  assert.equal(
    fs.realpathSync(f.base + "/current"),
    f.base + "/releases/previous",
  );
  const events = f.events();
  assert.ok(!events.includes("pm2 save"));
  assert.equal(
    events.filter((x) => x.startsWith("pm2 startOrReload")).length,
    2,
  );
});
test("the initial installer can defer public checks until its HTTPS certificate exists", (t) => {
  const f = fixture(t),
    r = f.run({ FAIL_PUBLIC: "1", LINGOY_SKIP_PUBLIC_CHECK: "1" });
  assert.equal(r.status, 0, r.stderr);
  assert.ok(!f.events().includes("public-check"));
  assert.ok(f.events().includes("pm2 save"));
});
