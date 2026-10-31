export function channelFor(release) {
  const label = ((release.tag_name || "") + " " + (release.name || "")).toLowerCase();
  if (/(^|[^a-z])alpha([^a-z]|$)/.test(label)) return "alpha";
  if (/(^|[^a-z])beta([^a-z]|$)/.test(label)) return "beta";
  return release.prerelease ? "beta" : "stable";
}

export function isUnsignedRelease(release) {
  const body = (release.body || "").toLowerCase();
  return /\bunsigned\b/.test(body) || /sem\s+assinatura/.test(body);
}

export function matchesBuildBranch(run, channel) {
  if (!run || typeof run.head_branch !== "string") return false;
  if (channel === "Alpha") return run.head_branch.startsWith("codex/alpha-");
  if (channel === "Beta") return run.head_branch === "beta";
  if (channel === "Oficial") return run.head_branch === "main";
  return false;
}

export function latestRunForChannel(runs, channel) {
  return runs
    .filter(run => matchesBuildBranch(run, channel))
    .sort((a, b) => Date.parse(b.created_at) - Date.parse(a.created_at))[0] || null;
}
