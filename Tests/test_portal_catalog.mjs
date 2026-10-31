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
assert.equal(isUnsignedRelease({ assets: [{ name: "AutoRenew-unsigned.ipa" }] }), true);

const workflow = (name) => readFileSync(new URL("../.github/workflows/" + name, import.meta.url), "utf8");
for (const name of ["beta-ci.yml", "beta-ipa.yml", "build.yml", "official-ci.yml", "official-ipa.yml", "deploy-pages.yml"]) {
  assert.match(workflow(name), /actions\/checkout@v7\.0\.1/, name + " must use the current Node 24 checkout action");
}
for (const name of ["beta-ipa.yml", "build.yml", "official-ipa.yml"]) {
  assert.match(workflow(name), /actions\/upload-artifact@v7\.0\.2/, name + " must use the current Node 24 artifact action");
}
const pagesWorkflow = workflow("deploy-pages.yml");
assert.match(pagesWorkflow, /actions\/configure-pages@v6\.0\.0/);
assert.match(pagesWorkflow, /actions\/upload-pages-artifact@v5\.0\.0/);
assert.match(pagesWorkflow, /actions\/deploy-pages@v5\.0\.1/);

const html = readFileSync(new URL("../docs/index.html", import.meta.url), "utf8");
assert.match(html, /latestRunForChannel\(j\.workflow_runs/);
assert.match(html, /runs\?per_page=100/);
assert.match(html, /aria-live="polite" role="status"/);
assert.match(html, /IPA UNSIGNED/);
assert.doesNotMatch(html, /browser_download_url/);
assert.doesNotMatch(html, /Baixar IPA unsigned/);
assert.doesNotMatch(html, /Baixe o IPA publicado ou um artefato/);
assert.match(html, /Download bloqueado no portal/);
assert.match(html, /Não baixe nem instale a Release Alpha unsigned/);
assert.match(html, /Ver logs no GitHub \\(não instalar artefatos\\)/);
assert.match(html, /não assina nem instala por conta própria/);
assert.match(html, /não confirma assinatura, instalação ou primeiro lançamento/);
assert.match(html, /skip-link/);
assert.match(html, /focus-visible/);
assert.doesNotMatch(html, /innerHTML/);
assert.doesNotMatch(html, /sideinstaller\.com/);
assert.match(html, /https:\/\/sidestore\.io/);
assert.match(html, /https:\/\/altstore\.io/);

console.log("Portal catalog, branch filtering, unsigned labeling and accessibility tests passed.");
