import path from "node:path";
export function config(env = process.env) {
  const smtpPort = Number(env.GMAIL_SMTP_PORT || 465);
  if (![465, 587].includes(smtpPort)) throw Error('GMAIL_SMTP_PORT 465 yoki 587 bo‘lsin.');
  if ((env.JWT_SECRET || "").length < 32)
    throw Error("JWT_SECRET kamida 32 belgi bo‘lsin.");
  const origin = new URL(env.PUBLIC_ORIGIN || "https://lingoy.uz").origin,
    production = env.NODE_ENV === "production";
  if (production && !origin.startsWith("https://"))
    throw Error("Production uchun HTTPS kerak.");
  return {
    origin,
    production,
    secret: env.JWT_SECRET,
    host: env.HOST || "127.0.0.1",
    port: Number(env.PORT || 8080),
    db: env.DB_PATH || "./data/lingoy.sqlite",
    dictionary: path.resolve(
      env.DICTIONARY_PATH || "../mobile/assets/dictionary.db",
    ),
    downloads: path.resolve(env.DOWNLOADS_PATH || "../downloads"),
    web: path.resolve(env.WEB_PATH || "../web/dist"),
    gmail: env.GMAIL_USER,
    gmailPassword: env.GMAIL_APP_PASSWORD?.replace(/\s+/g, ''),
    smtpPort,
    googleId: env.GOOGLE_CLIENT_ID,
    googleSecret: env.GOOGLE_CLIENT_SECRET,
    redirect: env.GOOGLE_REDIRECT_URI || origin,
    aiKey: env.GEMINI_API_KEY || env.AI_API_KEY,
    model: env.GEMINI_MODEL || "gemini-3.1-flash-lite",
    aiBase:
      env.GEMINI_API_BASE || "https://generativelanguage.googleapis.com/v1beta",
    daily: Number(env.AI_DAILY_LIMIT || 30),
  };
}
