#!/usr/bin/env node
// Lays the weekend phone kit out as a Finder folder: one folder per platform, then per day,
// then per post (numbered in posting order) holding its media and a caption.txt.
//
//     node marketing/3.5/src/export_kit_folder.mjs
//
// Reads the post list straight out of kit/index.html, so the folder always matches the kit.
// Media are copies of the files in marketing/drafts/, and the output folder is gitignored:
// re-run this after changing the kit instead of editing the folder by hand.

import { readFileSync, writeFileSync, mkdirSync, rmSync, copyFileSync, existsSync } from "node:fs";
import { join, dirname, basename, extname } from "node:path";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, "../../..");
const OUT = join(HERE, "../Hyperia City Weekend");
const KIT_URL = "https://claude.ai/artifact/1biB3LBBXDvneHaogKwG11";
const SOURCES = [
  "marketing/drafts/images/2026-10-16/promo",
  "marketing/drafts/images/2026-10-16",
  "marketing/drafts/images/2026-10-13",
  "marketing/drafts/reels/2026-10-16",
].map(dir => join(ROOT, dir));

// Run only the kit's data section (everything before the done-tick storage code).
const html = readFileSync(join(HERE, "../kit/index.html"), "utf8");
const script = html.split("<script>")[1].split("</script>")[0];
const data = script.slice(0, script.indexOf("const PLATFORM_KEY"));
const ctx = { localStorage: { getItem: () => null } };
vm.runInNewContext(`${data}\nthis.out = { DAYS, PLATFORMS, REDEEM };`, ctx);
const { DAYS, PLATFORMS, REDEEM } = ctx.out;

const FOLDER = { ig: "1 Instagram", tiktok: "2 TikTok", x: "3 X", reddit: "4 Reddit" };
const TIME = ["Tonight", "Morning", "Midday", "Afternoon", "Evening", "Any time"];
const rank = when => (TIME.indexOf(when) + 1) || TIME.length + 1;
const plain = html => html.replace(/<[^>]+>/g, "").replace(/&amp;/g, "&");
const safe = name => name.replace(/:/g, "").replace(/\//g, "-").replace(/[“”]/g, "").trim();

function source(path) {
  const name = basename(path);
  const dir = SOURCES.find(d => existsSync(join(d, name)));
  if (!dir) throw new Error(`No source for ${path}`);
  return join(dir, name);
}

function captionText(post) {
  const parts = [`${post.title}`, `${post.kind} · ${post.when}`, ""];
  if (post.postTitle) parts.push("TITLE", post.postTitle, "", "BODY");
  if (post.caption) parts.push(post.caption, "");
  if (post.thread) post.thread.forEach((line, i) => parts.push(`POST ${i + 1}`, line, ""));
  if (post.steps) post.steps.forEach((step, i) => parts.push(`${i + 1}. ${plain(step)}`));
  if (post.steps) parts.push("");
  if (post.tip) parts.push(`TIP: ${plain(post.tip)}`);
  return parts.join("\n").trim() + "\n";
}

rmSync(OUT, { recursive: true, force: true });
mkdirSync(OUT, { recursive: true });
let files = 0;

for (const platform of PLATFORMS) {
  for (const day of DAYS) {
    const posts = day.posts
      .filter(post => post.platform === platform.id)
      .map((post, i) => ({ post, i }))
      .sort((a, b) => rank(a.post.when) - rank(b.post.when) || a.i - b.i);
    posts.forEach(({ post }, n) => {
      const dir = join(OUT, FOLDER[platform.id], `${day.date} ${day.name}`,
        safe(`${n + 1} ${post.when} – ${post.kind} – ${post.title}${post.promo ? " (promo)" : ""}`));
      mkdirSync(dir, { recursive: true });
      writeFileSync(join(dir, platform.id === "reddit" ? "post.txt" : "caption.txt"), captionText(post));
      (post.media || []).forEach((path, k) => {
        const many = post.media.length > 1;
        const name = many ? `${k + 1} ${basename(path)}` : basename(path);
        copyFileSync(source(path), join(dir, name));
        files++;
      });
    });
  }
  writeFileSync(join(OUT, FOLDER[platform.id], "README.txt"), `${platform.name}\n\n${plain(platform.note)}\n`);
}

writeFileSync(join(OUT, "Open posting kit.webloc"), `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>URL</key><string>${KIT_URL}</string></dict></plist>
`);
writeFileSync(join(OUT, "README.txt"), `Hyperia City weekend (Thu Oct 15 – Mon Oct 19, 2026)

Posting kit (phone): ${KIT_URL}
Double-click "Open posting kit.webloc" to open it.

Folders: platform → day → post, numbered in posting order. Each post folder holds its media
(numbered when it's a carousel/slideshow, in slide order) and caption.txt with the caption,
thread posts or steps, plus a TIP line.

Half-price Pro promo: $9.99 for the first year (then $19.99/yr) with code HYPERIA, Fri Oct 16 – Mon Oct 19.
Redeem link (IG bio, X and Reddit replies): ${REDEEM}
TikTok has no bio link: people redeem in App Store → profile → Redeem Gift Card or Code.

This folder is generated from the kit by marketing/3.5/src/export_kit_folder.mjs and is not in git.
Re-run it after changing the kit; edits made here get overwritten.
`);
console.log(`wrote ${OUT} (${files} media files)`);
