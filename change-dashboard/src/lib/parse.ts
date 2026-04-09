import type { DiscussionLogEntry, StatusHistoryEntry } from './types';

export function parseFeatureNames(raw: unknown): string[] {
  if (Array.isArray(raw)) return raw.map(String);
  return [];
}

export function parseStatusHistory(raw: unknown): StatusHistoryEntry[] {
  if (!Array.isArray(raw)) return [];
  return raw.filter(
    (x): x is StatusHistoryEntry =>
      x !== null &&
      typeof x === 'object' &&
      'to' in x &&
      typeof (x as StatusHistoryEntry).to === 'string'
  );
}

export function parseDiscussionLog(raw: unknown): DiscussionLogEntry[] {
  if (!Array.isArray(raw)) return [];
  return raw.filter(
    (x): x is DiscussionLogEntry =>
      x !== null &&
      typeof x === 'object' &&
      'body' in x &&
      typeof (x as DiscussionLogEntry).body === 'string' &&
      'at' in x &&
      typeof (x as DiscussionLogEntry).at === 'string'
  );
}

/** Short preview for CTASK `task` column in tables (full text on hover via title). */
export function previewTaskText(s: string | null | undefined, max = 56): string {
  const v = s?.trim();
  if (!v) return '—';
  return v.length <= max ? v : `${v.slice(0, max)}…`;
}
