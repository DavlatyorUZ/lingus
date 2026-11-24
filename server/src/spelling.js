export function distance(a, b) {
  let row = Array.from({ length: b.length + 1 }, (_, i) => i);
  for (let i = 1; i <= a.length; i++) {
    const next = [i];
    for (let j = 1; j <= b.length; j++)
      next[j] = Math.min(
        row[j] + 1,
        next[j - 1] + 1,
        row[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1),
      );
    row = next;
  }
  return row[b.length];
}
export function suggestions(db, query) {
  if (!/^[a-z]{3,30}$/.test(query)) return [];
  const candidates = db
    .prepare(
      "SELECT * FROM entries WHERE length(normalized) BETWEEN ? AND ? AND (normalized LIKE ? OR normalized LIKE ?) ORDER BY CASE WHEN level<>'' THEN 0 ELSE 1 END,abs(length(normalized)-?),id LIMIT 1800",
    )
    .all(
      query.length - 2,
      query.length + 2,
      query[0] + "%",
      query[1] + "%",
      query.length,
    );
  return candidates
    .map((w) => ({ w, d: distance(query, w.normalized) }))
    .filter((x) => x.d > 0 && x.d <= 2)
    .sort((a, b) => a.d - b.d || a.w.normalized.localeCompare(b.w.normalized))
    .slice(0, 4)
    .map((x) => x.w);
}
