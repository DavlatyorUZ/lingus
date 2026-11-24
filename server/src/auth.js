import crypto from "node:crypto";
import bcrypt from "bcryptjs";
import { z } from "zod";
import { OAuth2Client } from "google-auth-library";
import { Failure, random, hash, challenge, equal } from "./security.js";
import { tx } from "./db.js";
import { mailFailure } from "./mail-errors.js";
const email = z.string().trim().toLowerCase().email().max(254),
  password = z
    .string()
    .min(10)
    .max(72)
    .refine((s) => Buffer.byteLength(s) <= 72),
  credentials = z.object({ email, password });
export function authRoutes(
  app,
  { c, db, sec, mail, now, google, passwords = bcrypt },
) {
  const base = "/api/v1/auth",
    redirectUri = c.redirect || c.origin + base + "/google/callback",
    rootCallback = redirectUri === c.origin || redirectUri === c.origin + "/",
    oauthCookiePath = rootCallback ? "/" : base + "/google",
    oauth = google || new OAuth2Client(c.googleId, c.googleSecret, redirectUri);
  async function sendCode(address, purpose, details = {}) {
    const code = String(crypto.randomInt(0, 1000000)).padStart(6, "0");
    tx(db, () => {
      const p = db
        .prepare("SELECT * FROM challenges WHERE email=? AND purpose=?")
        .get(address, purpose);
      if (p?.locked > now())
        throw new Failure(
          429,
          "locked",
          "5 ta xato urinish. 10 daqiqa kuting.",
        );
      if (p && p.sent + 60000 > now())
        throw new Failure(429, "cooldown", "Yangi kod uchun 60 soniya kuting.");
      db.prepare(
        `INSERT INTO challenges VALUES(?,?,?,?,?,?,?,0,0) ON CONFLICT(email,purpose) DO UPDATE SET code=excluded.code,name=excluded.name,password=excluded.password,expires=excluded.expires,sent=excluded.sent,attempts=CASE WHEN challenges.expires>? THEN challenges.attempts ELSE 0 END,locked=0`,
      ).run(
        address,
        purpose,
        sec.hmac(`${purpose}:${address}:${code}`),
        details.name || null,
        details.password || null,
        now() + 600000,
        now(),
        now(),
      );
    });
    try {
      await mail.send(address, code, purpose);
    } catch (error) {
      // Operational cause only: never log addresses, OTPs, SMTP responses or secrets.
      console.error(JSON.stringify({event: 'email_delivery_failed', purpose,
        cause: mailFailure(error).code}));
      // Only release this delivery's cooldown; retain attempts and any newer code.
      db.prepare(
        "UPDATE challenges SET sent=? WHERE email=? AND purpose=? AND code=?",
      ).run(
        now() - 60001,
        address,
        purpose,
        sec.hmac(`${purpose}:${address}:${code}`),
      );
      throw new Failure(
        503,
        "mail_unavailable",
        "Tasdiqlash xizmati hozir xat yubora olmayapti. Birozdan so‘ng qayta urinib ko‘ring yoki Google orqali kiring.",
      );
    }
  }
  function verifyCode(address, purpose, code) {
    const p = db
      .prepare("SELECT * FROM challenges WHERE email=? AND purpose=?")
      .get(address, purpose);
    if (!p || p.expires <= now())
      throw new Failure(
        400,
        "expired",
        "Kod muddati tugagan. Yangi kod so‘rang.",
      );
    if (p.locked > now() || p.attempts >= 5)
      throw new Failure(429, "locked", "5 ta xato urinish. 10 daqiqa kuting.");
    if (!equal(p.code, sec.hmac(`${purpose}:${address}:${code}`))) {
      db.prepare(
        "UPDATE challenges SET attempts=attempts+1,locked=CASE WHEN attempts>=4 THEN ? ELSE 0 END WHERE email=? AND purpose=?",
      ).run(now() + 600000, address, purpose);
      throw new Failure(400, "invalid_code", "Tasdiqlash kodi noto‘g‘ri.");
    }
    return p;
  }
  app.get(base + "/csrf", sec.csrfToken);
  app.post(base + "/register", async (req, res) => {
    const p = credentials
      .extend({ name: z.string().trim().min(1).max(64) })
      .parse(req.body);
    if (db.prepare("SELECT id FROM users WHERE email=?").get(p.email))
      throw new Failure(
        409,
        "exists",
        "Bu email ro‘yxatdan o‘tgan. Kirish tugmasidan foydalaning.",
      );
    const encoded = await passwords.hash(p.password, 12);
    await sendCode(p.email, "register", { name: p.name, password: encoded });
    res.status(202).json({
      message: "6 xonali kod emailingizga yuborildi.",
      expiresIn: 600,
      resendAfter: 60,
    });
  });
  app.post(base + "/verify", (req, res) => {
    const p = z
        .object({ email, code: z.string().regex(/^\d{6}$/) })
        .parse(req.body),
      pending = verifyCode(p.email, "register", p.code);
    const u = tx(db, () => {
      let u = db.prepare("SELECT * FROM users WHERE email=?").get(p.email);
      if (!u) {
        const id = random();
        db.prepare(
          "INSERT INTO users(id,email,name,password) VALUES(?,?,?,?)",
        ).run(id, p.email, pending.name, pending.password);
        u = db.prepare("SELECT * FROM users WHERE id=?").get(id);
      }
      db.prepare("DELETE FROM challenges WHERE email=? AND purpose=?").run(
        p.email,
        "register",
      );
      return u;
    });
    res.json(sec.session(u, res));
  });
  app.post(base + "/login", async (req, res) => {
    const p = credentials.parse(req.body),
      u = db.prepare("SELECT * FROM users WHERE email=?").get(p.email);
    const valid = await passwords.compare(
      p.password,
      u?.password ||
        "$2b$12$C6UzMDM.H6dfI/f/IKcEe.7rXv/L6rqO9Ae6GslcC10g4O6hwZMOK",
    );
    const current = u && db.prepare("SELECT * FROM users WHERE id=?").get(u.id);
    // bcrypt yields to other requests, including password reset and revocation.
    if (!u?.password || !valid || current?.password !== u.password)
      throw new Failure(400, "credentials", "Email yoki parol noto‘g‘ri.");
    res.json(sec.session(current, res));
  });
  app.post(base + "/password/request", async (req, res) => {
    const p = z.object({ email }).parse(req.body),
      u = db.prepare("SELECT id FROM users WHERE email=?").get(p.email);
    if (u) await sendCode(p.email, "reset");
    res.status(202).json({
      message: "Hisob mavjud bo‘lsa, tasdiqlash kodi yuborildi.",
      resendAfter: 60,
    });
  });
  app.post(base + "/password/reset", async (req, res) => {
    const p = z
      .object({
        email,
        code: z.string().regex(/^\d{6}$/),
        newPassword: password,
      })
      .parse(req.body);
    verifyCode(p.email, "reset", p.code);
    const encoded = await passwords.hash(p.newPassword, 12);
    tx(db, () => {
      verifyCode(p.email, "reset", p.code);
      const u = db.prepare("SELECT id FROM users WHERE email=?").get(p.email);
      if (!u) throw new Failure(400, "expired", "Kodni qayta so‘rang.");
      db.prepare("UPDATE users SET password=? WHERE id=?").run(encoded, u.id);
      db.prepare("UPDATE sessions SET revoked=1 WHERE user_id=?").run(u.id);
      db.prepare("DELETE FROM challenges WHERE email=? AND purpose=?").run(
        p.email,
        "reset",
      );
    });
    res.clearCookie("lingoy_refresh", sec.cookie).json({
      ok: true,
      message: "Parol yangilandi. Yangi parol bilan kiring.",
    });
  });
  app.post(base + "/password/change", sec.auth, async (req, res) => {
    const p = z
      .object({ oldPassword: z.string().max(72), newPassword: password })
      .parse(req.body);
    if (
      !req.user.password ||
      !(await passwords.compare(p.oldPassword, req.user.password))
    )
      throw new Failure(
        400,
        "password",
        "Joriy parol noto‘g‘ri. Google orqali kirgan bo‘lsangiz, email orqali parolni tiklang.",
      );
    const encoded = await passwords.hash(p.newPassword, 12);
    tx(db, () => {
      const current = db
        .prepare("SELECT password FROM users WHERE id=?")
        .get(req.user.id);
      const session = db
        .prepare(
          "SELECT id FROM sessions WHERE id=? AND user_id=? AND revoked=0 AND expires>?",
        )
        .get(req.session.id, req.user.id, now());
      if (!session || current?.password !== req.user.password) {
        throw new Failure(401, "expired", "Sessiya yangilangan. Qayta kiring.");
      }
      db.prepare("UPDATE users SET password=? WHERE id=?").run(
        encoded,
        req.user.id,
      );
      db.prepare("UPDATE sessions SET revoked=1 WHERE user_id=?").run(
        req.user.id,
      );
    });
    res
      .clearCookie("lingoy_refresh", sec.cookie)
      .json({ ok: true, message: "Parol yangilandi. Qayta kiring." });
  });
  app.post(base + "/refresh", (req, res) => {
    const s =
      req.cookies.lingoy_refresh &&
      db
        .prepare("SELECT * FROM sessions WHERE hash=?")
        .get(hash(req.cookies.lingoy_refresh));
    if (!s || s.expires <= now())
      throw new Failure(401, "expired", "Sessiya tugadi. Qayta kiring.");
    if (s.revoked) {
      db.prepare("UPDATE sessions SET revoked=1 WHERE family=?").run(s.family);
      throw new Failure(401, "replay", "Sessiya yangilangan. Qayta kiring.");
    }
    res.json(
      tx(db, () => {
        db.prepare("UPDATE sessions SET revoked=1 WHERE id=?").run(s.id);
        return sec.session(
          db.prepare("SELECT * FROM users WHERE id=?").get(s.user_id),
          res,
          s.family,
        );
      }),
    );
  });
  app.post(base + "/logout", (req, res) => {
    const token = req.cookies.lingoy_refresh;
    if (token) {
      const s = db
        .prepare("SELECT family FROM sessions WHERE hash=?")
        .get(hash(token));
      if (s)
        db.prepare("UPDATE sessions SET revoked=1 WHERE family=?").run(
          s.family,
        );
    }
    res.clearCookie("lingoy_refresh", sec.cookie).json({ ok: true });
  });
  app.get("/api/v1/me", sec.auth, (req, res) =>
    res.json({ user: sec.publicUser(req.user) }),
  );
  app.patch("/api/v1/me", sec.auth, (req, res) => {
    const p = z
      .object({ name: z.string().trim().min(1).max(64) })
      .parse(req.body);
    db.prepare("UPDATE users SET name=? WHERE id=?").run(p.name, req.user.id);
    res.json({ user: sec.publicUser({ ...req.user, ...p }) });
  });
  app.post(base + "/mobile/start", (req, res) => {
    const p = z
        .object({ challenge: z.string().regex(/^[\w-]{43}$/) })
        .parse(req.body),
      ticket = random();
    db.prepare("INSERT INTO tickets VALUES(?,?,NULL,?)").run(
      ticket,
      p.challenge,
      now() + 600000,
    );
    res.json({
      ticket,
      url: c.origin + base + "/google/start?ticket=" + ticket,
    });
  });
  app.post(base + "/mobile/poll", (req, res) => {
    const p = z
        .object({
          ticket: z.string().min(40).max(64),
          verifier: z.string().min(43).max(128),
        })
        .parse(req.body),
      t = db.prepare("SELECT * FROM tickets WHERE id=?").get(p.ticket);
    if (!t || t.expires < now() || !equal(t.challenge, challenge(p.verifier)))
      throw new Failure(400, "ticket", "Kirishni qayta boshlang.");
    if (!t.user_id) return res.status(202).json({ pending: true });
    db.prepare("DELETE FROM tickets WHERE id=?").run(t.id);
    res.json(
      sec.session(
        db.prepare("SELECT * FROM users WHERE id=?").get(t.user_id),
        res,
      ),
    );
  });
  app.get(base + "/google/start", (req, res) => {
    if (!c.googleId || !c.googleSecret)
      throw new Failure(503, "google_config", "Google kirishi sozlanmagan.");
    const ticket =
      typeof req.query.ticket === "string" ? req.query.ticket : null;
    if (
      ticket &&
      !db
        .prepare("SELECT id FROM tickets WHERE id=? AND expires>?")
        .get(ticket, now())
    )
      throw new Failure(400, "ticket", "Kirish muddati tugadi.");
    const state = random(),
      binding = random(),
      nonce = random(),
      verifier = random();
    db.prepare("INSERT INTO oauth VALUES(?,?,?,?,?,?)").run(
      hash(state),
      hash(binding),
      nonce,
      verifier,
      ticket,
      now() + 600000,
    );
    res.cookie("lingoy_oauth", binding, {
      httpOnly: true,
      secure: c.production,
      sameSite: "lax",
      path: oauthCookiePath,
      maxAge: 600000,
    });
    res.redirect(
      oauth.generateAuthUrl({
        redirect_uri: redirectUri,
        scope: ["openid", "profile", "email"],
        state,
        nonce,
        code_challenge: challenge(verifier),
        code_challenge_method: "S256",
        prompt: "select_account",
      }),
    );
  });
  const googleCallback = async (req, res) => {
    if (
      typeof req.query.state !== "string" ||
      (typeof req.query.code !== "string" &&
        typeof req.query.error !== "string")
    )
      throw new Failure(400, "oauth", "Google kirishi bekor qilindi.");
    const s = db
      .prepare("SELECT * FROM oauth WHERE state=?")
      .get(hash(req.query.state));
    if (
      !s ||
      s.expires < now() ||
      !equal(s.binding, hash(req.cookies.lingoy_oauth || ""))
    )
      throw new Failure(400, "oauth_state", "Google kirishini qayta boshlang.");
    db.prepare("DELETE FROM oauth WHERE state=?").run(s.state);
    res.clearCookie("lingoy_oauth", { path: oauthCookiePath });
    if (typeof req.query.error === "string") {
      if (s.ticket) {
        db.prepare("DELETE FROM tickets WHERE id=?").run(s.ticket);
        return res
          .type("html")
          .send(
            '<!doctype html><html lang="uz"><meta name="viewport" content="width=device-width"><title>Lingoy</title><body style="font-family:sans-serif;padding:40px"><h1>Kirish bekor qilindi</h1><p>Lingoy ilovasiga qayting va qayta urinib ko‘ring. Bu oynani yopishingiz mumkin.</p></body></html>',
          );
      }
      return res.redirect(c.origin + "/?auth=cancelled");
    }
    const { tokens } = await oauth.getToken({
      code: req.query.code,
      codeVerifier: s.verifier,
      redirect_uri: redirectUri,
    });
    const ticket = await oauth.verifyIdToken({
      idToken: tokens.id_token,
      audience: c.googleId,
    });
    const p = ticket.getPayload();
    if (!p?.email_verified || p.nonce !== s.nonce)
      throw new Failure(
        403,
        "google_profile",
        "Google emailingiz tasdiqlanmagan.",
      );
    const address = email.parse(p.email);
    const u = tx(db, () => {
      const bySub = db
          .prepare("SELECT * FROM users WHERE google_sub=?")
          .get(p.sub),
        old =
          bySub || db.prepare("SELECT * FROM users WHERE email=?").get(address);
      if (old && !bySub && !address.endsWith("@gmail.com") && !p.hd)
        throw new Failure(403, "email_link", "Email va parol orqali kiring.");
      const id = old?.id || random(),
        picture = /^https:\/\/[^/]*googleusercontent\.com\//.test(
          p.picture || "",
        )
          ? p.picture
          : null;
      if (old)
        db.prepare(
          "UPDATE users SET google_sub=?,name=?,picture=? WHERE id=?",
        ).run(p.sub, (p.name || old.name).slice(0, 64), picture, id);
      else
        db.prepare(
          "INSERT INTO users(id,email,name,google_sub,picture) VALUES(?,?,?,?,?)",
        ).run(
          id,
          address,
          (p.name || address.split("@")[0]).slice(0, 64),
          p.sub,
          picture,
        );
      return db.prepare("SELECT * FROM users WHERE id=?").get(id);
    });
    if (s.ticket) {
      db.prepare("UPDATE tickets SET user_id=? WHERE id=? AND expires>?").run(
        u.id,
        s.ticket,
        now(),
      );
      return res
        .type("html")
        .send(
          '<!doctype html><html lang="uz"><meta name="viewport" content="width=device-width"><title>Lingoy</title><body style="font-family:sans-serif;padding:40px"><h1>Kirish muvaffaqiyatli</h1><p>Lingoy ilovasiga qayting. Bu oynani yopishingiz mumkin.</p></body></html>',
        );
    }
    sec.session(u, res);
    res.redirect(c.origin + "/?auth=success");
  };
  app.get(base + "/google/callback", googleCallback);
  if (rootCallback)
    app.get("/", (req, res, next) => {
      if (
        req.query.state !== undefined ||
        req.query.code !== undefined ||
        req.query.error !== undefined
      )
        return googleCallback(req, res);
      next();
    });
}
