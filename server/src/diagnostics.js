import { z } from "zod";
import { mailer } from "./mail.js";
import { gemini } from "./gemini.js";

const address = z.string().trim().toLowerCase().email().max(254);
export function parseLiveArgs(args) {
  const result = { json: false, skipAi: false };
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === "--json") result.json = true;
    else if (arg === "--skip-ai") result.skipAi = true;
    else if (arg === "--email" && !result.email) {
      const parsed = address.safeParse(args[++i]);
      if (!parsed.success)
        throw Error("Sinov xati uchun to‘g‘ri email manzilini kiriting.");
      result.email = parsed.data;
    } else throw Error("Parametrlar: --json, --skip-ai, --email MANZIL.");
  }
  return result;
}

export { mailFailure } from './mail-errors.js';
import { mailFailure } from './mail-errors.js';

export async function liveChecks(c, options = {}) {
  const email =
    options.email === undefined ? undefined : address.parse(options.email);
  const generate = options.generate || gemini;
  const now = options.now || Date.now;
  const timed = (started, result) => ({
    ...result,
    duration_ms: Math.max(0, now() - started),
  });
  async function smtp() {
    const started = now();
    let transport;
    const checks = [];
    try {
      if (!c.gmail || !c.gmailPassword)
        return [
          {
            name: "smtp_auth",
            status: "fail",
            code: "smtp_config",
            message: "Gmail sozlamalari to‘ldirilmagan.",
            action: "Server .env faylini to‘ldiring.",
          },
        ];
      transport = options.mail || mailer(c);
      await transport.verify();
      checks.push(
        timed(started, {
          name: "smtp_auth",
          status: "pass",
          code: "smtp_auth_ok",
          message: "SMTP ulanishi va autentifikatsiya tasdiqlandi.",
        }),
      );
      if (email) {
        const submission = now();
        try {
          const result = await transport.sendDiagnostic(email);
          const accepted = (result?.accepted || []).some(
            (v) =>
              (typeof v === "string" ? v : v?.address)?.toLowerCase() === email,
          );
          if (!accepted) throw Error("submission rejected");
          checks.push(
            timed(submission, {
              name: "email_submission",
              status: "pass",
              code: "smtp_accepted",
              message:
                "Pochta serveri sinov xatini qabul qildi. Qutiga yetib kelganini alohida tekshiring.",
            }),
          );
        } catch (error) {
          checks.push(
            timed(submission, {
              name: "email_submission",
              status: "fail",
              ...mailFailure(error),
            }),
          );
        }
      }
    } catch (error) {
      checks.push(
        timed(started, {
          name: "smtp_auth",
          status: "fail",
          ...mailFailure(error),
        }),
      );
    } finally {
      try {
        transport?.close?.();
      } catch {}
    }
    return checks;
  }
  async function ai() {
    const started = now();
    if (options.skipAi)
      return {
        name: "gemini",
        status: "skip",
        code: "ai_skipped",
        message: "AI tekshiruvi so‘ralmadi.",
      };
    try {
      if (!c.aiKey) throw Object.assign(Error(), { code: "ai_credentials" });
      const result = await generate(c, "translation", {
        text: "No cap, this is a piece of cake.",
        source_language: "en",
        target_language: "uz",
        style: "informal",
      });
      if (!result?.translation?.trim())
        throw Object.assign(Error(), { code: "ai_response" });
      return timed(started, {
        name: "gemini",
        status: "pass",
        code: "ai_ok",
        message: "Haqiqiy AI tarjima javobi olindi.",
      });
    } catch (error) {
      const credentials = error?.code === "ai_credentials";
      return timed(started, {
        name: "gemini",
        status: "fail",
        code: credentials
          ? "ai_credentials"
          : error?.code === "ai_response"
            ? "ai_response"
            : "ai_unavailable",
        message: credentials
          ? "AI hisob sozlamalari tekshiruvdan o‘tmadi."
          : "AI xizmati tekshiruvi bajarilmadi.",
        action: credentials
          ? "Server .env faylidagi API kaliti, model va provider ruxsatlarini tekshiring."
          : "Tarmoq, provider limiti va xizmat holatini tekshirib qayta urining.",
      });
    }
  }
  const [mailChecks, aiCheck] = await Promise.all([smtp(), ai()]);
  const checks = [...mailChecks, aiCheck];
  return {
    ok: !checks.some((x) => x.status === "fail"),
    checks,
    email_delivery_verified: false,
    external_pending: [
      ...(email
        ? ["Sinov xatining Inbox yoki Spam qutisiga yetib kelishi"]
        : ["Haqiqiy sinov xati yuborilishi va yetib kelishi"]),
      "Ilovada ro‘yxatdan o‘tish va parolni tiklash kodining to‘liq oqimi",
      "Google orqali haqiqiy kirish va avatar",
      "VPS DNS va ommaviy HTTPS",
    ],
  };
}
