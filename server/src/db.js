import { DatabaseSync } from "node:sqlite";
import { mkdirSync } from "node:fs";
import path from "node:path";
export function openDb(file) {
  if (file !== ":memory:")
    mkdirSync(path.dirname(file), { recursive: true, mode: 0o700 });
  const db = new DatabaseSync(file, { timeout: 5000 });
  db.exec(`PRAGMA journal_mode=WAL;PRAGMA foreign_keys=ON;
 CREATE TABLE IF NOT EXISTS migrations(version INTEGER PRIMARY KEY,applied INTEGER NOT NULL);
 CREATE TABLE IF NOT EXISTS users(id TEXT PRIMARY KEY,email TEXT UNIQUE NOT NULL,name TEXT NOT NULL,password TEXT,google_sub TEXT UNIQUE,picture TEXT,revision INTEGER NOT NULL DEFAULT 0);
 CREATE TABLE IF NOT EXISTS challenges(email TEXT NOT NULL,purpose TEXT NOT NULL,code TEXT NOT NULL,name TEXT,password TEXT,expires INTEGER NOT NULL,sent INTEGER NOT NULL,attempts INTEGER NOT NULL DEFAULT 0,locked INTEGER NOT NULL DEFAULT 0,PRIMARY KEY(email,purpose));
 CREATE TABLE IF NOT EXISTS sessions(id TEXT PRIMARY KEY,user_id TEXT REFERENCES users(id),family TEXT NOT NULL,hash TEXT UNIQUE NOT NULL,expires INTEGER NOT NULL,revoked INTEGER NOT NULL DEFAULT 0);
 CREATE TABLE IF NOT EXISTS oauth(state TEXT PRIMARY KEY,binding TEXT NOT NULL,nonce TEXT NOT NULL,verifier TEXT NOT NULL,ticket TEXT,expires INTEGER NOT NULL);
 CREATE TABLE IF NOT EXISTS tickets(id TEXT PRIMARY KEY,challenge TEXT NOT NULL,user_id TEXT,expires INTEGER NOT NULL);
 CREATE TABLE IF NOT EXISTS saved(user_id TEXT REFERENCES users(id),word_id INTEGER NOT NULL,deleted INTEGER NOT NULL,revision INTEGER NOT NULL,PRIMARY KEY(user_id,word_id));
 CREATE TABLE IF NOT EXISTS mutations(user_id TEXT NOT NULL,id TEXT NOT NULL,created INTEGER NOT NULL,PRIMARY KEY(user_id,id));
 CREATE TABLE IF NOT EXISTS usage(user_id TEXT NOT NULL,day TEXT NOT NULL,n INTEGER NOT NULL DEFAULT 0,PRIMARY KEY(user_id,day));
 CREATE TABLE IF NOT EXISTS cache(key TEXT PRIMARY KEY,value TEXT NOT NULL,expires INTEGER NOT NULL);
 CREATE TABLE IF NOT EXISTS supplements(id INTEGER PRIMARY KEY AUTOINCREMENT,normalized TEXT UNIQUE NOT NULL,lemma TEXT NOT NULL,translation TEXT NOT NULL,explanation TEXT NOT NULL DEFAULT '',source TEXT NOT NULL DEFAULT 'AI',updated INTEGER NOT NULL);
 INSERT OR IGNORE INTO migrations VALUES(1,unixepoch());`);
  const max = db.prepare("SELECT max(id) n FROM supplements").get().n;
  if (
    max === null &&
    !db
      .prepare("SELECT name FROM sqlite_sequence WHERE name='supplements'")
      .get()
  )
    db.prepare(
      "INSERT INTO sqlite_sequence(name,seq) VALUES('supplements',1000000000)",
    ).run();
  return db;
}
export function tx(db, fn) {
  db.exec("BEGIN IMMEDIATE");
  try {
    const v = fn();
    db.exec("COMMIT");
    return v;
  } catch (e) {
    db.exec("ROLLBACK");
    throw e;
  }
}
