import express from "express";
import helmet from "helmet";
import cors from "cors";
import cookieParser from "cookie-parser";
import { rateLimit } from "express-rate-limit";
import { ZodError } from "zod";
import { openDb } from "./db.js";
import { security, Failure } from "./security.js";
import { mailer } from "./mail.js";
import { authRoutes } from "./auth.js";
import { serviceRoutes } from "./services.js";
import { version } from "./version.js";
export function createApp(c, injected = {}) {
  const db = injected.db || openDb(c.db),
    now = injected.now || Date.now,
    sec = security(c, db, now),
    app = express();
  app.disable("x-powered-by");
  app.use((req, res, next) => {
    res.set("Permissions-Policy", "camera=(self), microphone=(), geolocation=()");
    next();
  });
  app.set("trust proxy", "loopback");
  app.use(
    helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          scriptSrc: ["'self'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          imgSrc: [
            "'self'",
            "data:",
            "blob:",
            "https://*.googleusercontent.com",
          ],
          connectSrc: ["'self'"],
          mediaSrc: ["'self'", "blob:"],
          fontSrc: ["'self'"],
          objectSrc: ["'none'"],
          upgradeInsecureRequests: c.production ? [] : null,
        },
      },
    }),
    cors({
      origin: c.origin,
      credentials: true,
      allowedHeaders: ["Content-Type", "Authorization", "X-CSRF-Token"],
    }),
  );
  app.use(
    "/api",
    (req, res, next) => {
      res.set("Cache-Control", "no-store");
      next();
    },
    rateLimit({
      windowMs: 60000,
      limit: 180,
      standardHeaders: "draft-8",
      legacyHeaders: false,
      message: {
        error: "rate_limit",
        message: "So‘rovlar ko‘p. Biroz kuting.",
      },
    }),
  );
  app.use(
    "/api/v1/auth",
    rateLimit({
      windowMs: 15 * 60000,
      limit: 60,
      skip: (req) => req.path === "/mobile/poll",
      standardHeaders: "draft-8",
      legacyHeaders: false,
      message: {
        error: "auth_limit",
        message: "Kirish urinishlari ko‘p. 15 daqiqa kuting.",
      },
    }),
  );
  app.use(express.json({ limit: "5mb" }), cookieParser());
  app.use("/api", sec.csrf);
  app.get("/api/v1/health", (req, res) => {
    db.prepare("SELECT 1").get();
    res.json({
      status: "ready",
      api_version: "1",
      version,
      release_id: process.env.RELEASE_ID || null,
      capabilities: {
        translation: !!c.aiKey,
        grammar: !!c.aiKey,
        image_translation: !!c.aiKey,
      },
    });
  });
  authRoutes(app, {
    c,
    db,
    sec,
    mail: injected.mail || mailer(c),
    now,
    google: injected.google,
    passwords: injected.passwords,
  });
  const closeDictionary = serviceRoutes(app, {
    c,
    db,
    sec,
    now,
    generate: injected.generate,
  });
  app.use("/api", (req, res) =>
    res
      .status(404)
      .json({ error: "not_found", message: "Bunday manzil topilmadi." }),
  );
  app.use(
    "/downloads",
    (req, res, next) =>
      ["/Lingoy.apk", "/Lingoy.apk.sha256", "/release.json"].includes(req.path)
        ? next()
        : next(new Failure(404, "not_found", "Bunday fayl topilmadi.")),
    express.static(c.downloads, {
      fallthrough: false,
      setHeaders: (res, file) => {
        if (file.endsWith(".apk")) {
          res.set("Content-Disposition", 'attachment; filename="Lingoy.apk"');
          res.set("Content-Type", "application/vnd.android.package-archive");
        } else if (file.endsWith(".sha256"))
          res.set("Content-Type", "text/plain; charset=utf-8");
      },
    }),
  );
  if (injected.static !== false) app.use(express.static(c.web));
  app.use((e, req, res, next) => {
    const status = e instanceof ZodError ? 400 : e.status || 500;
    if (status >= 500 && !injected.quiet)
      console.error(JSON.stringify({ status, code: e.code || "internal" }));
    res.status(status).json({
      error: e instanceof ZodError ? "validation" : e.code || "internal",
      message:
        e instanceof ZodError
          ? "Maydonlarni to‘g‘ri to‘ldiring. Parol 10–72 belgidan iborat bo‘lsin."
          : e instanceof Failure
            ? e.message
            : status === 413
              ? "So‘rov hajmi juda katta."
              : status === 404
                ? "Bunday manzil topilmadi."
                : status === 400
                  ? "So‘rov formati noto‘g‘ri."
                  : "Xizmatda xato. Keyinroq urinib ko‘ring.",
    });
  });
  return { app, db, sec, closeDictionary };
}
