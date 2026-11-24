import { config } from "./config.js";
import { productionChecks } from "./production-checks.js";
try {
  const report = await productionChecks(config());
  console.log(JSON.stringify(report, null, 2));
  if (!report.automatic_ok) process.exitCode = 1;
} catch {
  console.error(
    "Server sozlamalari yoki release fayllari tekshiruvdan o‘tmadi. .env va paket yaxlitligini tekshiring.",
  );
  process.exitCode = 1;
}
