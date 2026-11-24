import { build } from "esbuild";
import { mkdir, rm, copyFile, cp, readFile, writeFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
await rm("dist", { recursive: true, force: true });
await mkdir("dist/assets", { recursive: true });
const quizBytes = await readFile('../mobile/assets/quiz_bank.json');
const quizFile = 'data-quiz-bank-' + createHash('sha256').update(quizBytes).digest('hex').slice(0, 12) + '.json';
const {version} = JSON.parse(await readFile('../server/package.json', 'utf8'));
const bundle = await build({
  entryPoints: ["src/app.js"],
  bundle: true,
  minify: true,
  format: "esm",
  target: "es2022",
  outdir: "dist",
  entryNames: "app-[hash]",
  metafile: true,
  define: {
    __LINGOY_QUIZ_BANK_URL__: JSON.stringify('/' + quizFile),
    __LINGOY_VERSION__: JSON.stringify(version),
  },
});
const js = Object.keys(bundle.metafile.outputs)
  .find((p) => p.endsWith(".js"))
  .replace("dist/", "");
const css = "style-" + createHash("sha256").update(await readFile("style.css")).digest("hex").slice(0, 12) + ".css";
await copyFile("style.css", "dist/" + css);
for (const f of ["manifest.webmanifest"])
  await copyFile(f, "dist/" + f);
await cp("icons", "dist/icons", { recursive: true });
await writeFile(
  "dist/index.html",
  (await readFile("index.html", "utf8")).replace("/app.js", "/" + js).replace("/style.css", "/" + css).replace('__LINGOY_VERSION__', version),
);
await writeFile('dist/' + quizFile, quizBytes);
await writeFile('dist/release.json', JSON.stringify({version, quizBank:'/' + quizFile}));
await copyFile("../mobile/assets/icons/google.svg", "dist/assets/google.svg");
for (const f of ["lingoy_icon.png", "licenses.txt", "photo_credits.txt"])
  await copyFile("../mobile/assets/" + f, "dist/assets/" + f);
await copyFile("../mobile/assets/fonts/Manrope.ttf", "dist/assets/Manrope.ttf");
await cp("../mobile/assets/pictures/photos", "dist/assets/pictures/photos", {
  recursive: true,
});
await cp("../data/picture_art_sources", "dist/assets/vectors", {
  recursive: true,
});
const r = spawnSync(
  process.env.PYTHON_BIN ||
    (process.platform === "win32" ? "python" : "python3"),
  ["../tools/export_web.py"],
  { encoding: "utf8" },
);
if (r.status !== 0) throw Error(r.stderr);
console.log(r.stdout.trim());
const shell = [
    "/",
    "/index.html",
    "/" + js,
    "/" + css,
    "/icons/lingoy-maskable-512.png",
    "/assets/google.svg",
    "/manifest.webmanifest",
    "/icons/lingoy-192.png",
    "/icons/lingoy-512.png",
    "/assets/Manrope.ttf",
    '/' + quizFile,
    "/data/photos.json",
    "/data/essentials.json",
    "/data/lessons.json",
  ],
  digest = createHash("sha256");
for (const item of shell)
  digest.update(
    await readFile(item === "/" ? "dist/index.html" : "dist" + item),
  );
const hash = digest.digest("hex").slice(0, 12);

await writeFile(
  "dist/sw.js",
  (await readFile("sw-template.js", "utf8"))
    .replace("__VERSION__", hash)
    .replace("__SHELL__", JSON.stringify(shell)),
);
await writeFile(
  "dist/robots.txt",
  "User-agent: *\nAllow: /\nDisallow: /api/\nSitemap: https://lingoy.uz/sitemap.xml\n",
);
await writeFile(
  "dist/sitemap.xml",
  '<?xml version="1.0"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"><url><loc>https://lingoy.uz/</loc></url></urlset>',
);
console.log("PWA build:", js, hash);
