import { config } from "./config.js";
import { openDb } from "./db.js";
process.umask(0o077);
const db = openDb(config().db);
console.log("Baza migratsiyasi tayyor.");
db.close();
