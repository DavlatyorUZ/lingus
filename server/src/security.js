import crypto from "node:crypto";
import jwt from "jsonwebtoken";
export class Failure extends Error {
  constructor(status, code, message) {
    super(message);
    Object.assign(this, { status, code });
  }
}
export const random = () => crypto.randomBytes(32).toString("base64url");
export const hash = (s) => crypto.createHash("sha256").update(s).digest("hex");
export const challenge = (s) =>
  crypto.createHash("sha256").update(s).digest("base64url");
export function equal(a, b) {
  if (typeof a !== "string" || typeof b !== "string") return false;
  const x = Buffer.from(a),
    y = Buffer.from(b);
  return x.length === y.length && crypto.timingSafeEqual(x, y);
}
export function security(c, db, now) {
  const cookie = {
    httpOnly: true,
    secure: c.production,
    sameSite: "strict",
    path: "/api/v1/auth",
    maxAge: 30 * 86400000,
  };
  const hmac = (s) =>
    crypto.createHmac("sha256", c.secret).update(s).digest("hex");
  const publicUser = (u) => ({
    id: u.id,
    email: u.email,
    name: u.name,
    picture: u.picture || null,
    hasPassword: !!u.password,
  });
  function session(u, res, family = random()) {
    const token = random(),
      sid = random();
    db.prepare("INSERT INTO sessions VALUES(?,?,?,?,?,0)").run(
      sid,
      u.id,
      family,
      hash(token),
      now() + 30 * 86400000,
    );
    res.cookie("lingoy_refresh", token, cookie);
    return {
      user: publicUser(u),
      accessToken: jwt.sign({ sub: u.id, sid }, c.secret, {
        expiresIn: "15m",
        issuer: "lingoy",
        audience: "lingoy-client",
      }),
      expiresIn: 900,
    };
  }
  function auth(req, res, next) {
    try {
      const p = jwt.verify(
        req.get("authorization")?.replace(/^Bearer /, "") || "",
        c.secret,
        { algorithms: ["HS256"], issuer: "lingoy", audience: "lingoy-client" },
      );
      const s = db
        .prepare(
          "SELECT * FROM sessions WHERE id=? AND user_id=? AND revoked=0 AND expires>?",
        )
        .get(p.sid, p.sub, now());
      if (!s) throw Error();
      req.user = db.prepare("SELECT * FROM users WHERE id=?").get(p.sub);
      if (!req.user) throw Error();
      req.session = s;
      next();
    } catch {
      next(new Failure(401, "login_required", "Davom etish uchun kiring."));
    }
  }
  function csrfToken(req, res) {
    const token = random();
    res.cookie("lingoy_csrf", token + "." + hmac(token), {
      ...cookie,
      path: "/api",
      maxAge: 86400000,
    });
    res.json({ csrfToken: token });
  }
  function csrf(req, res, next) {
    if (["GET", "HEAD", "OPTIONS"].includes(req.method)) return next();
    if (req.get("origin") && req.get("origin") !== c.origin)
      return next(new Failure(403, "origin", "Bu manbaga ruxsat berilmagan."));
    const [t, s] = (req.cookies.lingoy_csrf || "").split(".");
    if (!t || !equal(s, hmac(t)) || !equal(t, req.get("x-csrf-token")))
      return next(
        new Failure(403, "csrf", "Sahifani yangilang va qayta urinib ko‘ring."),
      );
    next();
  }
  return { cookie, hmac, publicUser, session, auth, csrfToken, csrf };
}
