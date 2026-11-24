export function mailFailure(error) {
  const code = error?.code;
  if (["EDNS", "ENOTFOUND", "EAI_AGAIN"].includes(code))
    return {
      code: "smtp_dns",
      message: "Gmail SMTP manzili DNS orqali topilmadi.",
      action:
        "VPS DNS sozlamalarini va smtp.gmail.com nomining yechilishini tekshiring. Bu parol noto‘g‘riligini bildirmaydi.",
    };
  if (code === "EAUTH")
    return {
      code: "smtp_auth",
      message: "Gmail SMTP autentifikatsiyani rad etdi.",
      action:
        "Server .env faylidagi GMAIL_USER va GMAIL_APP_PASSWORD ni tekshiring. Gmail App Password uchun Google akkauntida 2 bosqichli tasdiqlash yoqilgan bo‘lishi kerak.",
    };
  if (
    [
      "ETLS",
      "CERT_HAS_EXPIRED",
      "DEPTH_ZERO_SELF_SIGNED_CERT",
      "UNABLE_TO_VERIFY_LEAF_SIGNATURE",
    ].includes(code)
  )
    return {
      code: "smtp_tls",
      message: "SMTP TLS sertifikati tekshiruvdan o‘tmadi.",
      action:
        "VPS vaqti va ca-certificates paketini tekshiring. TLS tekshiruvini o‘chirmang.",
    };
  if (
    [
      "ETIMEDOUT",
      "ESOCKET",
      "ECONNECTION",
      "ECONNREFUSED",
      "EHOSTUNREACH",
      "ENETUNREACH",
    ].includes(code)
  )
    return {
      code: "smtp_connection",
      message: "Gmail SMTP bilan ulanish o‘rnatilmadi yoki uzildi.",
      action:
        "VPS provayderi va firewall chiqishdagi SMTP portiga ruxsat berishini tekshiring. GMAIL_SMTP_PORT=465 yoki STARTTLS uchun 587 ishlating.",
    };
  return {
    code: "smtp_error",
    message: "SMTP tekshiruvi bajarilmadi.",
    action:
      "Server konfiguratsiyasi va pochta xizmatining holatini tekshiring.",
  };
}

