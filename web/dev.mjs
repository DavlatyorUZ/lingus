import { readFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { config } from "../server/src/config.js";
import { createApp } from "../server/src/app.js";
const root = path.dirname(fileURLToPath(import.meta.url)),
  port = Number(
    process.env.PORT ||
      (process.argv.includes("--port")
        ? process.argv[process.argv.indexOf("--port") + 1]
        : 4173),
  ),
  c = config({
    ...process.env,
    NODE_ENV: "development",
    PUBLIC_ORIGIN: process.env.PUBLIC_ORIGIN || "http://127.0.0.1:" + port,
    JWT_SECRET: "local-preview-only-secret-at-least-32-characters",
    DB_PATH: root + "/.preview/lingoy.sqlite",
    DICTIONARY_PATH: root + "/../mobile/assets/dictionary.db",
    WEB_PATH: root + "/dist",
    DOWNLOADS_PATH: root + "/../downloads",
  });
const { app } = createApp(c, {
  mail: {
    send: async () => {
      throw Error("Preview mail disabled");
    },
  },
});
setInterval(() => {
  const f = root + "/.preview-origin";
  if (existsSync(f)) c.origin = readFileSync(f, "utf8").trim();
}, 1000).unref();
app.listen(port, "0.0.0.0", () => console.log("Lingoy preview ready:", port));
