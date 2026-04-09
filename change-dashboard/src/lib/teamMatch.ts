/** Normalize for matching DB team_key to feature display names. */
export function normalizeTeamKey(s: string): string {
  return s
    .trim()
    .toLowerCase()
    .replace(/\s+/g, '_')
    .replace(/[()]/g, '');
}

export function findReviewForTeam<T extends { team_key: string }>(
  reviews: T[],
  teamLabel: string
): T | undefined {
  const n = normalizeTeamKey(teamLabel);
  return reviews.find((r) => normalizeTeamKey(r.team_key) === n || r.team_key === teamLabel);
}

/** Ordered unique team labels: primary, feature_names, then any review-only keys. */
export function buildTeamOrder(primary: string | null, featureNames: string[], reviews: { team_key: string }[]): string[] {
  const out: string[] = [];
  const seen = new Set<string>();
  const push = (label: string) => {
    const t = label.trim();
    if (!t || seen.has(normalizeTeamKey(t))) return;
    seen.add(normalizeTeamKey(t));
    out.push(t);
  };
  if (primary) push(primary);
  for (const f of featureNames) push(f);
  for (const r of reviews) {
    if (!seen.has(normalizeTeamKey(r.team_key))) {
      seen.add(normalizeTeamKey(r.team_key));
      out.push(r.team_key);
    }
  }
  return out;
}
