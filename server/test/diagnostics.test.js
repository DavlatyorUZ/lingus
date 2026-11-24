import test from "node:test";
import assert from "node:assert/strict";
import { liveChecks, mailFailure, parseLiveArgs } from "../src/diagnostics.js";
const c = {
  gmail: "fixture@gmail.com",
  gmailPassword: "private-mail-fixture",
  aiKey: "private-ai-fixture",
  secret: "private-jwt-fixture",
  googleSecret: "private-google-fixture",
};
const generate = async () => ({ translation: "Rostini aytsam, bu juda oson." });
test("SMTP diagnostics distinguish DNS, credentials, TLS and blocked connections without leaking errors", () => {
  for (const [code, expected] of [
    ["EDNS", "smtp_dns"],
    ["ENOTFOUND", "smtp_dns"],
    ["EAUTH", "smtp_auth"],
    ["ETLS", "smtp_tls"],
    ["ETIMEDOUT", "smtp_connection"],
    ["ECONNREFUSED", "smtp_connection"],
    ["unknown", "smtp_error"],
  ]) {
    const result = mailFailure({
      code,
      message: c.gmailPassword,
      response: c.aiKey,
    });
    assert.equal(result.code, expected);
    assert.ok(!JSON.stringify(result).includes(c.gmailPassword));
    assert.ok(!JSON.stringify(result).includes(c.aiKey));
  }
});
test("default live check verifies SMTP without sending an unsolicited message", async () => {
  let sent = 0,
    closed = 0;
  const report = await liveChecks(c, {
    mail: {
      verify: async () => true,
      sendDiagnostic: async () => {
        sent++;
      },
      close: () => closed++,
    },
    generate,
  });
  assert.equal(report.ok, true);
  assert.equal(sent, 0);
  assert.equal(closed, 1);
  assert.equal(report.email_delivery_verified, false);
  assert.equal(report.checks.filter((x) => x.status === "pass").length, 2);
  assert.ok(report.external_pending.length > 0);
});
test("an explicitly requested accepted message is not reported as inbox delivery", async () => {
  let target;
  const report = await liveChecks(c, {
    email: " QA@example.com ",
    mail: {
      verify: async () => true,
      sendDiagnostic: async (email) => {
        target = email;
        return { accepted: ["qa@example.com"] };
      },
    },
    generate,
  });
  assert.equal(target, "qa@example.com");
  assert.equal(report.ok, true);
  assert.equal(
    report.checks.find((x) => x.name === "email_submission").code,
    "smtp_accepted",
  );
  assert.equal(report.email_delivery_verified, false);
});
test("failed SMTP authentication blocks mail submission while AI is still independently checked", async () => {
  let sent = 0,
    ai = 0;
  const report = await liveChecks(c, {
    email: "qa@example.com",
    mail: {
      verify: async () => {
        throw Object.assign(Error(c.gmailPassword), { code: "EAUTH" });
      },
      sendDiagnostic: async () => sent++,
    },
    generate: async () => {
      ai++;
      return generate();
    },
  });
  assert.equal(report.ok, false);
  assert.equal(sent, 0);
  assert.equal(ai, 1);
  assert.equal(report.checks[0].code, "smtp_auth");
  for (const value of Object.values(c))
    assert.ok(!JSON.stringify(report).includes(value));
});
test("a recipient rejected after authentication cannot appear as successful submission", async () => {
  const report = await liveChecks(c, {
    email: "qa@example.com",
    mail: {
      verify: async () => true,
      sendDiagnostic: async () => ({
        accepted: [],
        rejected: ["qa@example.com"],
      }),
    },
    generate,
  });
  assert.equal(report.ok, false);
  assert.equal(
    report.checks.find((x) => x.name === "email_submission").status,
    "fail",
  );
  assert.equal(
    report.checks.find((x) => x.name === "smtp_auth").status,
    "pass",
  );
});
test("SMTP-only diagnostics never invoke the AI provider and show it as skipped", async () => {
  const report = await liveChecks(c, {
    skipAi: true,
    mail: { verify: async () => true },
    generate: async () => {
      throw Error("must not call provider");
    },
  });
  assert.equal(report.ok, true);
  assert.equal(report.checks.find((x) => x.name === "gemini").status, "skip");
});
test("AI failures and empty model responses produce safe failure reports", async () => {
  for (const [code, expected] of [
    ["ai_credentials", "ai_credentials"],
    ["ai_network", "ai_unavailable"],
  ]) {
    const report = await liveChecks(c, {
      mail: { verify: async () => true },
      generate: async () => {
        throw Object.assign(Error(c.aiKey), { code, providerReason: c.aiKey });
      },
    });
    assert.equal(report.ok, false);
    assert.equal(report.checks.find((x) => x.name === "gemini").code, expected);
    assert.ok(!JSON.stringify(report).includes(c.aiKey));
  }
  const empty = await liveChecks(c, {
    mail: { verify: async () => true },
    generate: async () => ({ translation: "  " }),
  });
  assert.equal(
    empty.checks.find((x) => x.name === "gemini").code,
    "ai_response",
  );
});
test("invalid or duplicate CLI recipients are rejected before any network request", async () => {
  assert.deepEqual(
    parseLiveArgs(["--json", "--skip-ai", "--email", "QA@example.com"]),
    { json: true, skipAi: true, email: "qa@example.com" },
  );
  for (const args of [
    ["--email"],
    ["--email", "not-an-email"],
    ["--email", "qa@example.com", "--email", "other@example.com"],
    ["--unknown"],
  ])
    assert.throws(() => parseLiveArgs(args));
  let network = 0;
  await assert.rejects(
    liveChecks(c, {
      email: "invalid",
      mail: { verify: async () => network++ },
      generate,
    }),
  );
  assert.equal(network, 0);
});
