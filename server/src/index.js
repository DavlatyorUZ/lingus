import { config } from "./config.js";
import { createApp } from "./app.js";
process.umask(0o077);
const c = config(),
  { app, db, closeDictionary } = createApp(c);
const server = app.listen(c.port, c.host, () =>
  console.log(JSON.stringify({ event: "started", port: c.port })),
);
const clean = setInterval(() => {
  try {
    for (const table of ["cache", "sessions", "oauth", "tickets"])
      db.prepare(`DELETE FROM ${table} WHERE expires<?`).run(Date.now());
    db.prepare("DELETE FROM challenges WHERE expires<?").run(
      Date.now() - 86400000,
    );
  } catch {
    console.error('{"event":"maintenance_failed"}');
  }
}, 3600000);
clean.unref();
let closing = false;
function stop() {
  if (closing) return;
  closing = true;
  clearInterval(clean);
  server.close(() => {
    closeDictionary();
    db.close();
    process.exit(0);
  });
  setTimeout(() => process.exit(1), 15000).unref();
}
process.on("SIGTERM", stop);
process.on("SIGINT", stop);
