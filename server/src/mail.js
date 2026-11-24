import nodemailer from "nodemailer";
import {readFileSync} from 'node:fs';
const logo = readFileSync(new URL('../assets/lingoy-logo.png',import.meta.url));
const branding = {filename:'lingoy.png',content:logo,cid:'lingoy-logo'};
export function mailer(c, {createTransport = nodemailer.createTransport} = {}) {
  const transport = createTransport({
    host: "smtp.gmail.com",
    port: c.smtpPort || 465,
    secure: (c.smtpPort || 465) === 465,
    requireTLS: true,
    disableFileAccess: true,
    disableUrlAccess: true,
    tls: { minVersion: "TLSv1.2", rejectUnauthorized: true },
    auth: { user: c.gmail, pass: c.gmailPassword },
    connectionTimeout: 10000,
    socketTimeout: 15000,
  });
  return {
    verify: () => transport.verify(),
    close: () => transport.close(),
    sendDiagnostic: (email) =>
      transport.sendMail({
        from: `Lingoy <${c.gmail}>`,
        to: email,
        subject: "Lingoy — pochta ulanishi sinovi",
        attachments: [branding],
        text: "Lingoy serveri ushbu sinov xatini yubordi. Bu kirish yoki parolni tiklash kodi emas. Xat yetib kelgan bo‘lsa, SMTP yuborish yo‘li ishlamoqda. Ilovadagi tasdiqlash kodini alohida ro‘yxatdan o‘tish orqali tekshiring.",
        html: '<div style="background:#f5f1eb;padding:32px;font-family:Arial,sans-serif;color:#251d2f"><div style="max-width:480px;margin:auto;background:white;border-radius:24px;padding:32px"><img src="cid:lingoy-logo" alt="Lingoy" width="56" height="56" style="border-radius:16px"><h1>Lingoy</h1><h2>Pochta ulanishi sinovi</h2><p>Lingoy serveri ushbu sinov xatini yubordi.</p><p>Bu kirish yoki parolni tiklash kodi emas. Xat yetib kelgan bo‘lsa, SMTP yuborish yo‘li ishlamoqda.</p><p>Ilovadagi tasdiqlash kodini alohida ro‘yxatdan o‘tish orqali tekshiring.</p></div></div>',
      }),
    send: async (email, code, purpose) => {
      const reset = purpose === "reset";
      const result = await transport.sendMail({
        from: `Lingoy <${c.gmail}>`,
        to: email,
        subject: reset
          ? "Lingoy — parolni tiklash"
          : "Lingoy — emailni tasdiqlash",
        attachments: [branding],
        text: `${reset ? "Parolni tiklash" : "Emailni tasdiqlash"} kodi: ${code}. Kod 10 daqiqa amal qiladi. Kodni hech kimga bermang.`,
        html: `<div style="background:#f5f1eb;padding:36px;font-family:Arial,sans-serif;color:#251d2f"><div style="max-width:480px;margin:auto;background:#fff;padding:36px;border-radius:24px"><img src="cid:lingoy-logo" alt="Lingoy" width="56" height="56" style="border-radius:16px"><h1>Lingoy</h1><h2>${reset ? "Parolni tiklash" : "Xush kelibsiz!"}</h2><p>${reset ? "Yangi parol belgilash" : "Emailingizni tasdiqlash"} uchun ushbu kodni kiriting:</p><p style="letter-spacing:9px;font-size:36px;font-weight:bold;padding:20px;background:#f3edf5;border-radius:14px;text-align:center">${code}</p><p>Kod <b>10 daqiqa</b> amal qiladi. Uni hech kimga bermang.</p><p style="font-size:12px;color:#817987">So‘rovni siz yubormagan bo‘lsangiz, ushbu xatni e’tiborsiz qoldiring.</p></div></div>`,
      });
      if (!(result.accepted || []).some(address =>
        (typeof address === 'string' ? address : address.address)?.toLowerCase() === email.toLowerCase())) {
        throw Object.assign(Error('SMTP did not accept recipient'), {code:'EENVELOPE'});
      }
      return result;
    },
  };
}
