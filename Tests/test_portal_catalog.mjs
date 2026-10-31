import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { channelFor, isUnsignedRelease, latestRunForChannel, matchesBuildBranch } from "../docs/catalog.mjs";

const runs = [
  { id: "main-newer", head_branch: "main", created_at: "2026-10-31T18:00:00Z" },
  { id: "alpha-latest", head_branch: "codex/alpha-ai-orchestrator-20261031", created_at: "2026-10-31T17:00:00Z" },
  { id: "alpha-older", head_branch: "codex/alpha-installer-hub-20261031", created_at: "2026-10-31T16:00:00Z" },
  { id: "beta", head_branch: "beta", created_at: "2026-10-31T15:00:00Z" }
];

assert.equal(latestRunForChannel(runs, "Alpha").id, "alpha-latest");
assert.equal(latestRunForChannel(runs, "Beta").id, "beta");
assert.equal(latestRunForChannel(runs, "Oficial").id, "main-newer");
assert.equal(latestRunForChannel([], "Alpha"), null);
assert.equal(matchesBuildBranch(runs[0], "Alpha"), false);
assert.equal(channelFor({ tag_name: "alpha-2026.10.31", prerelease: true }), "alpha");
assert.equal(channelFor({ tag_name: "beta-v1", prerelease: true }), "beta");
assert.equal(channelFor({ tag_name: "v1.0.0", prerelease: false }), "stable");
assert.equal(isUnsignedRelease({ body: "IMPORTANTE: os dois IPAs são unsigned" }), true);
assert.equal(isUnsignedRelease({ body: "Assinatura não verificada" }), false);

const html = readFileSync(new URL("../docs/index.html", import.meta.url), "utf8");
assert.match(html, /<script type="module">/);
assert.match(html, /latestRunForChannel\(j\.workflow_runs/);
assert.match(html, /runs\?per_page=100/);
assert.match(html, /aria-live="polite"/);
assert.match(html, /não assina nem instala por conta própria/);
assert.match(html, /IPA UNSIGNED/);
assert.doesNotMatch(html, /fluxo oficial do instalador/);
console.log("Portal catalog and page regression tests passed.");
