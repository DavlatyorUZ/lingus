import { config } from "./config.js";
import { liveChecks, parseLiveArgs } from "./diagnostics.js";
try {
  const options = parseLiveArgs(process.argv.slice(2));
  const report = await liveChecks(config(), options);
  if (options.json) console.log(JSON.stringify(report, null, 2));
  else {
    for (const check of report.checks) {
      console.log(
        `${check.status === "pass" ? "OK" : check.status === "skip" ? "O‘TKAZILDI" : "XATO"} [${check.code}]: ${check.message}`,
      );
      if (check.action) console.log("  " + check.action);
    }
    console.log(
      "Bu tekshiruv email qutisiga yetkazilishni yoki Google orqali kirishni tasdiqlamaydi.",
    );
  }
  if (!report.ok) process.exitCode = 1;
} catch {
  console.error(
    "Konfiguratsiya yoki parametr noto‘g‘ri. server/.env ni tekshiring. Parametrlar: --json, --skip-ai, --email MANZIL.",
  );
  process.exitCode = 1;
}
