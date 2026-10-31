import assert from "node:assert/strict";
import { channelFor, isUnsignedRelease, latestRunForChannel, matchesBuildBranch } from "../docs/catalog.mjs";

const runs = [
  { id: "main-newer", head_branch: "main", created_at: "2026-10-31T18:00:00Z" },
  { id: "alpha-latest", head_branch: "codex/alpha-ai-orchestrator-20261031", created_at: "2026-10-31T17:00:00Z" },
  { id: "alpha-older", head_branch: "codex/alpha-installer-hub-20261031", created_at: "2026-10-31T16:00:00Z" },
  { id: "beta", head_branch: "beta", created_at: "2026-10-31T15:00:00Z" }
];

assert.equal(latestRunForChannel(runs, "Alpha").id, "alpha-latest");
assert.equal(latestRunForChannel(runs, "Beta").id, "beta");
assert.equal(latestRunForChannel(runs, "Oficial").id, "main");
assert.equal(latestRunForChannel([], "Alpha"), null);
assert.equal(matchesBuildBranch(runs[0], "Alpha"), false);
assert.equal(channelFor({ tag_name: "alpha-2026.10.31", prerelease: true }), "alpha");
assert.equal(channelFor({ tag_name: "beta-v1", prerelease: true }), "beta");
assert.equal(channelFor({ tag_name: "v1.0.0", prerelease: false }), "stable");
assert.equal(isUnsignedRelease({ body: "IMPORTANTE: os dois IPAs são unsigned" }), true);
assert.equal(isUnsignedRelease({ body: "Assinatura não verificada" }), false);

console.log("Portal catalog regression tests passed.");
