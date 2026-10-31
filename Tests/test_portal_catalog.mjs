import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  channelFor,
  isUnsignedRelease,
  latestRunForChannel,
  matchesBuildBranch
} from "../docs/catalog.mjs";

const runs = [
  { id: "main-newer", head_branch: "main", created_at: "2026-10-31T21:05:00Z" },
  { id: "beta-pr", head_branch: "codex/ipa-packaging-validation", created_at: "2026-10-31T20:00:00Z" },
  { id: "alpha-newer", head_branch: "codex/alpha-installer-download-hardening-20261031", created_at: "2026-10-31T20:08:00Z" },
  { id: "alpha-older", head_branch: "codex/alpha-ai-central-20261031", created_at: "2026-10-31T20:07:00Z" },
  { id: "beta-real", head_branch: "beta", created_at: "2026-10-31T19:00:00Z" }
];

assert.equal(latestRunForChannel(runs, "Alpha").id, "alpha-newer");
assert.equal(latestRunForChannel(runs, "Beta").id, "beta-real");
assert.equal(latestRunForChannel(runs, "Oficial").id, "main-newer");
assert.equal(latestRunForChannel([], "Alpha"), null);
assert.equal(matchesBuildBranch(runs[1], "Beta"), false);
assert.equal(channelFor({ tag_name: "alpha-2026.10.31", prerelease: true }), "alpha");
assert.equal(channelFor({ tag_name: "beta-v1", prerelease: true }), "beta");
assert.equal(channelFor({ tag_name: "v1.0.0", prerelease: false }), "stable");
assert.equal(isUnsignedRelease({ body: "Os dois IPAs são unsigned" }), true);
assert.equal(isUnsignedRelease({ body: "Sem assinatura Apple" }), true);
assert.equal(isUnsignedRelease({ body: "Assinatura ainda não verificada" }), false);

const html = readFileSync(new URL("../docs/index.html", import.meta.url), "utf8");
assert.match(html, /latestRunForChannel\(j\.workflow_runs/);
assert.match(html, /runs\?per_page=100/);
assert.match(html, /aria-live="polite" role="status"/);
assert.match(html, /IPA UNSIGNED/);
assert.match(html, /Baixar IPA unsigned \(não instalável diretamente\)/);
assert.match(html, /não assina nem instala por conta própria/);
assert.match(html, /não confirma assinatura, instalação ou primeiro lançamento/);
assert.match(html, /skip-link/);
assert.match(html, /focus-visible/);
assert.doesNotMatch(html, /innerHTML/);
assert.doesNotMatch(html, /sideinstaller\.com/);
assert.match(html, /https:\/\/sidestore\.io/);
assert.match(html, /https:\/\/altstore\.io/);

console.log("Portal catalog, branch filtering, unsigned labeling and accessibility tests passed.");
