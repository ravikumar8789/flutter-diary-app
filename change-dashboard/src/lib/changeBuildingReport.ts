import { historyLinePrefix } from './changeHistory';
import { parseDiscussionLog, parseStatusHistory } from './parse';
import type { ChangeReviewRow, ChangeRow, ChangeTaskRow, DiscussionLogEntry, StatusHistoryEntry } from './types';

/** Reviews + CTASKs for a full open-change export (optional). */
export type ChangeBuildingReportBundle = {
  reviews: ChangeReviewRow[];
  tasks: { task: ChangeTaskRow; teamKey: string }[];
};

/** Permanent folder at diaryapp repo root (dev server writes here; see `vite.config.ts`). */
export const CHANGE_BUILDING_DIR_REPO = 'CHANGE-ACTIONS/change-building';

/**
 * Download filename — always `{change_id}-change-building.md`
 * Example: `CHG0000001-change-building.md`
 */
export function changeBuildingFilename(changeId: string): string {
  const safe = changeId.trim().replace(/[/\\?%*:|"<>]/g, '_');
  return `${safe}-change-building.md`;
}

/** Full path relative to repo root (for instructions inside the file). */
export function changeBuildingRepoPath(changeId: string): string {
  return `${CHANGE_BUILDING_DIR_REPO}/${changeBuildingFilename(changeId)}`;
}

function esc(s: string | null | undefined): string {
  if (s == null || String(s).trim() === '') return '*(empty / unknown)*';
  return String(s)
    .replace(/\|/g, '\\|')
    .replace(/\r\n/g, '\n')
    .split('\n')
    .map((line) => line || ' ')
    .join('<br>');
}

function block(label: string, body: string | null | undefined): string {
  const b = body?.trim() ? body.trim() : '*(empty / unknown)*';
  return `### ${label}\n\n\`\`\`text\n${b.replace(/```/g, '\\`\\`\\`')}\n\`\`\`\n\n`;
}

function jsonPretty(raw: unknown): string {
  try {
    return JSON.stringify(raw, null, 2);
  } catch {
    return String(raw);
  }
}

function atMs(iso: string): number {
  const t = Date.parse(iso);
  return Number.isFinite(t) ? t : 0;
}

function formatStatusForTimeline(h: StatusHistoryEntry): string {
  const prefix = historyLinePrefix(h);
  return `${prefix} ${h.from ?? '?'} → **${h.to}**: ${h.remark}`;
}

function discussionOldestFirst(log: DiscussionLogEntry[]): DiscussionLogEntry[] {
  return [...log].sort((a, b) => atMs(a.at) - atMs(b.at) || a.body.localeCompare(b.body));
}

/**
 * **Discussion only** — `discussion_log` sorted **oldest → newest** (time order) for reading context.
 * `discussed_details` is a separate single field (often filled on **Edit change**); it does not populate `discussion_log`.
 */
export function buildDiscussionJournalMarkdown(
  discussion: DiscussionLogEntry[],
  discussedDetails: string | null | undefined,
): string {
  const sorted = discussionOldestFirst(discussion);
  if (sorted.length === 0) {
    const hint =
      discussedDetails?.trim() ?
        `\n> **Why 0 entries?** You have text in \`discussed_details\` (see **Current row** below), but **\`discussion_log\`** is still empty. They are different columns: threaded notes come only from the change **detail** page → **Discussion** → **Append note**. **Edit change** updates \`discussed_details\`, not \`discussion_log\`.\n`
        : '';
    return [
      `## Discussion journal (\`discussion_log\`)`,
      ``,
      `*No \`discussion_log\` entries yet. Add them from the change **detail** page → **Discussion** → **Append note** (newest at top in the UI; this export lists **oldest first**).*`,
      hint,
      ``,
    ].join('\n');
  }
  const body = sorted
    .map((d, i) => {
      const who = d.author ? ` · ${d.author}` : '';
      return [
        `### ${i + 1}. ${d.at}${who}`,
        ``,
        d.body.trim() || '*(empty body)*',
        ``,
      ].join('\n');
    })
    .join('---\n\n');
  return [
    `## Discussion journal (\`discussion_log\`)`,
    ``,
    `Thread of free-form notes, **chronological (oldest → newest)**. Use this for intent and decisions; **status history** is separate (audit of status transitions).`,
    ``,
    `---`,
    ``,
    body,
    ``,
  ].join('\n');
}

/**
 * Status / audit only: change + approver + CTASK **status_history** lines, **oldest first**.  
 * Discussion text lives in **Discussion journal** above — not duplicated here.
 */
export function buildWorkNotesTimelineMarkdown(
  change: ChangeRow,
  reviews: ChangeReviewRow[],
  tasks: { task: ChangeTaskRow; teamKey: string }[],
): string {
  type Line = { t: number; seq: number; md: string };
  const lines: Line[] = [];
  let seq = 0;

  lines.push({
    t: atMs(change.created_at),
    seq: seq++,
    md: `**[Record]** Change row created (\`change_id\` = \`${change.change_id}\`).\n\n_\`${change.created_at}\`_`,
  });

  for (const h of parseStatusHistory(change.status_history)) {
    lines.push({ t: atMs(h.at), seq: seq++, md: formatStatusForTimeline(h) });
  }

  for (const r of reviews) {
    for (const h of parseStatusHistory(r.status_history)) {
      lines.push({ t: atMs(h.at), seq: seq++, md: formatStatusForTimeline(h) });
    }
  }

  for (const { task } of tasks) {
    for (const h of parseStatusHistory(task.status_history)) {
      lines.push({ t: atMs(h.at), seq: seq++, md: formatStatusForTimeline(h) });
    }
  }

  lines.sort((a, b) => a.t - b.t || a.seq - b.seq);

  const body = lines
    .map((row, i) => `### ${i + 1}. ${new Date(row.t).toISOString()}\n\n${row.md}`)
    .join('\n\n---\n\n');

  return `## Status & audit timeline (oldest → newest)\n\n**Status transitions** from \`status_history\` on the change, approvers, and CTASKs — merged by \`at\`. Does **not** repeat \`discussion_log\` (see **Discussion journal**).\n\n---\n\n${body}\n\n`;
}

function markdownReviewBlock(r: ChangeReviewRow, index: number): string {
  const hist = parseStatusHistory(r.status_history);
  return [
    `### Approver ${index + 1}: \`${r.team_key}\``,
    ``,
    `| Field | Value |`,
    `| --- | --- |`,
    `| \`id\` | \`${r.id}\` |`,
    `| \`status\` | ${esc(r.status)} |`,
    `| \`status_remark\` | ${esc(r.status_remark)} |`,
    `| \`rejection_remark\` | ${esc(r.rejection_remark)} |`,
    `| \`reviewed_at\` | ${esc(r.reviewed_at)} |`,
    `| \`created_at\` | ${esc(r.created_at)} |`,
    `| \`updated_at\` | ${esc(r.updated_at)} |`,
    `| \`conflict\` | ${r.conflict} |`,
    ``,
    block('`impact_summary`', r.impact_summary),
    block('`justification`', r.justification),
    block('`full_discussion`', r.full_discussion),
    block('`doc_updates_suggested`', r.doc_updates_suggested),
    `**\`status_history\` (JSON)**`,
    ``,
    '```json',
    jsonPretty(hist),
    '```',
    ``,
  ].join('\n');
}

function markdownTaskBlock(row: { task: ChangeTaskRow; teamKey: string }, index: number): string {
  const { task, teamKey } = row;
  const hist = parseStatusHistory(task.status_history);
  return [
    `### CTASK ${index + 1}: \`${task.ctask_number}\` — team \`${teamKey}\``,
    ``,
    `| Field | Value |`,
    `| --- | --- |`,
    `| \`id\` | \`${task.id}\` |`,
    `| \`status\` | ${esc(task.status)} |`,
    `| \`status_remark\` | ${esc(task.status_remark)} |`,
    `| \`motive\` | ${esc(task.motive)} |`,
    `| \`created_at\` | ${esc(task.created_at)} |`,
    `| \`updated_at\` | ${esc(task.updated_at)} |`,
    ``,
    block('`task` (instructions)', task.task),
    `**\`status_history\` (JSON)**`,
    ``,
    '```json',
    jsonPretty(hist),
    '```',
    ``,
  ].join('\n');
}

/**
 * Full export for an **open** change (\`new\` / \`started\`): \`changes\` row + approvers + CTASKs + chronological work notes.
 */
export function buildChangePlanningReportMarkdown(change: ChangeRow, bundle?: ChangeBuildingReportBundle): string {
  const generatedAt = new Date().toISOString();
  const repoPath = changeBuildingRepoPath(change.change_id);
  const filename = changeBuildingFilename(change.change_id);

  const featureCatalog = 'FEATURES CONTROL/feature-list.md';
  const featureDocsDir = 'bc/CHANGE-SYSTEM/features-docs';

  const chHist = parseStatusHistory(change.status_history);
  const disc = parseDiscussionLog(change.discussion_log);
  const discChrono = discussionOldestFirst(disc);
  const reviews = bundle?.reviews ?? [];
  const tasksSorted = [...(bundle?.tasks ?? [])].sort((a, b) =>
    a.task.ctask_number.localeCompare(b.task.ctask_number),
  );
  const discussionJournal = buildDiscussionJournalMarkdown(disc, change.discussed_details);
  const timeline = buildWorkNotesTimelineMarkdown(change, reviews, tasksSorted);

  const approverBody =
    reviews.length > 0
      ? reviews.map((r, i) => markdownReviewBlock(r, i)).join('\n---\n\n')
      : '*No approver rows loaded (empty in dashboard / not created yet).*';

  const taskBody =
    tasksSorted.length > 0
      ? tasksSorted.map((row, i) => markdownTaskBlock(row, i)).join('\n---\n\n')
      : '*No CTASK rows loaded.*';

  return [
    `# Change building — open change export (\`${change.status}\`)`,
    ``,
    `> **Save in repo:** \`${repoPath}\``,
    `> **Download filename:** \`${filename}\``,
    ``,
    `| Meta | Value |`,
    `| --- | --- |`,
    `| Generated at (UTC) | ${generatedAt} |`,
    `| \`changes.id\` (UUID) | \`${change.id}\` |`,
    `| \`change_id\` | \`${change.change_id}\` |`,
    `| **Status** | **${change.status}** — export includes **full \`changes\` row**, **discussion journal** (time order), **status audit timeline**, **approvers**, **CTASKs**. |`,
    `| **Discussion notes** | ${disc.length} entr${disc.length === 1 ? 'y' : 'ies'} in \`discussion_log\` |`,
    ``,
    `---`,
    ``,
    discussionJournal,
    ``,
    `---`,
    ``,
    timeline,
    `---`,
    ``,
    `## Supabase table: \`public.changes\` (schema reference)`,
    ``,
    `All columns on the change row. Check constraints in migrations \`008\`+.`,
    ``,
    '| Column | Type / notes |',
    '| --- | --- |',
    '| `id` | UUID PK |',
    '| `change_id` | text, unique human id (e.g. CHG…) |',
    '| `status` | Allowed: `new`, `started`, `closed`, `cancelled`, `rollbacked`, `rejected` |',
    '| `type` | Allowed: `fix`, `add`, `remove`, `refactor`, `other` |',
    '| `primary_feature` | text, nullable |',
    '| `feature_names` | jsonb array of strings |',
    '| `short_description` | text |',
    '| `description` | text |',
    '| `rollback_plan` | text, nullable |',
    '| `discussed_details` | text, nullable |',
    '| `discussion_log` | jsonb — thread `{ at, body, author? }` (dashboard stores **newest first**) |',
    '| `status_remark` | text, nullable |',
    '| `status_history` | jsonb audit array |',
    '| `final_state_note` | text — required when status is terminal |',
    '| `created_by` | text, nullable |',
    '| `created_at` / `updated_at` / `closed_at` | timestamptz |',
    ``,
    `### What can be updated (and where)`,
    ``,
    '| Column | How to update |',
    '| --- | --- |',
    '| `id`, `change_id` | **Do not change** — identity (human \`change_id\` is read-only on **Edit change**). |',
    '| `created_at`, `created_by` | Set at insert; normally **read-only**. |',
    '| `updated_at` | **DB trigger** on update. |',
    '| `type`, `primary_feature`, `feature_names`, `short_description`, `description`, `rollback_plan`, `discussed_details` | Dashboard **Edit change** (or SQL / MCP). |',
    '| `discussion_log` | Dashboard **Discussion** on change detail (append note); or SQL with full JSON array. |',
    '| `status`, `status_remark`, `status_history`, `final_state_note`, `closed_at` | Dashboard **Update change status** on detail — follows workflow rules (remarks, terminal notes). |',
    ``,
    `Related tables: \`change_reviews\` (approvers), \`change_tasks\` (CTASKs) — full snapshots below when you export from this page.`,
    ``,
    `---`,
    ``,
    `## Feature docs (check in chat before expanding scope)`,
    ``,
    `- Catalog: \`${featureCatalog}\``,
    `- Per-feature: \`${featureDocsDir}/\``,
    ``,
    `**Primary** and **possibly affected** features may be *(empty / unknown)* until you agree in chat.`,
    ``,
    `---`,
    ``,
    `## Primary feature (user intent)`,
    ``,
    change.primary_feature?.trim()
      ? `**${change.primary_feature}**`
      : `*(empty / unknown — discuss in chat)*`,
    ``,
    `---`,
    ``,
    `## Possibly affected features (\`feature_names\`)`,
    ``,
    (change.feature_names ?? []).length
      ? (change.feature_names ?? []).map((n) => `- \`${n}\``).join('\n')
      : `*(empty / unknown — discuss in chat)*`,
    ``,
    `---`,
    ``,
    `## Current row — all \`changes\` values (snapshot)`,
    ``,
    `| Column | Value |`,
    `| --- | --- |`,
    `| \`id\` | \`${change.id}\` |`,
    `| \`change_id\` | ${esc(change.change_id)} |`,
    `| \`status\` | ${esc(change.status)} |`,
    `| \`type\` | ${esc(change.type)} |`,
    `| \`primary_feature\` | ${esc(change.primary_feature)} |`,
    `| \`created_at\` | ${esc(change.created_at)} |`,
    `| \`updated_at\` | ${esc(change.updated_at)} |`,
    `| \`created_by\` | ${esc(change.created_by)} |`,
    `| \`closed_at\` | ${esc(change.closed_at)} |`,
    `| \`status_remark\` | ${esc(change.status_remark)} |`,
    `| \`final_state_note\` | ${esc(change.final_state_note)} |`,
    `| \`discussion_log\` | ${disc.length} note(s) — see **Discussion journal** for time-ordered text; JSON below for exact storage. |`,
    ``,
    block('`short_description`', change.short_description),
    block('`description`', change.description),
    block('`rollback_plan`', change.rollback_plan),
    block('`discussed_details`', change.discussed_details),
    `**\`discussion_log\` (JSON, as stored — newest first in array)**`,
    ``,
    '```json',
    jsonPretty(disc),
    '```',
    ``,
    `**\`discussion_log\` (JSON, chronological — oldest first; same data, sorted for reading)**`,
    ``,
    '```json',
    jsonPretty(discChrono),
    '```',
    ``,
    `**\`feature_names\` (JSON)**`,
    ``,
    '```json',
    jsonPretty(change.feature_names ?? []),
    '```',
    ``,
    `**\`status_history\` (JSON)**`,
    ``,
    '```json',
    jsonPretty(chHist),
    '```',
    ``,
    `---`,
    ``,
    `## Approvers (\`change_reviews\`) — full detail`,
    ``,
    approverBody,
    ``,
    `---`,
    ``,
    `## CTASKs (\`change_tasks\`) — full detail`,
    ``,
    taskBody,
    ``,
    `---`,
    ``,
    `## Cursor — workflow prompt (read this file @-tagged)`,
    ``,
    `**Ground rules:** Do not invent DB columns or skip RLS. Prefer updating via the change dashboard when possible.`,
    ``,
    `### Phase 1 — Discuss the change first (required detail)`,
    ``,
    `1. Read **Discussion journal** and **Status & audit timeline** for context already captured.`,
    `2. With the user, confirm **scope**, **risk**, **rollback** (align with \`rollback_plan\` and \`description\`), and what “done” means.`,
    `3. If anything is unclear, ask before proposing schema or code changes.`,
    ``,
    `### Phase 2 — Primary feature & affected features`,
    ``,
    `1. Using \`${featureCatalog}\` and \`${featureDocsDir}/\`, propose the **single best** \`primary_feature\` for this change.`,
    `2. List **every feature** that might be touched (UI, data, edge functions, notifications, etc.) as \`feature_names\` — be inclusive; narrow later if needed.`,
    `3. If you are **unsure** which owning teams or boundaries apply, say so explicitly: **we will run change review (CR)** once **approver teams** exist on this change — do not pretend scope is settled.`,
    ``,
    `### Phase 3 — After approver teams / CR rows exist`,
    ``,
    `1. When \`change_reviews\` (and CTASKs) are added, treat CR outcomes as authoritative for multi-team alignment.`,
    `2. **Update the discussion journal:** add a short \`discussion_log\` note summarizing decisions (who agreed, what changed, links to CR/CTASK). Keeps this export self-contained next time.`,
    ``,
    `### Phase 4 — Persist`,
    ``,
    `1. Update \`changes\` for \`id\` = \`${change.id}\` (or **Edit change** / **Discussion** / status UI). See **What can be updated** above.`,
    `2. Approver and CTASK sections in this file reflect what was loaded at export time — refresh the export after major updates.`,
    ``,
    `### File convention`,
    ``,
    `- Repo: **\`${repoPath}\`**`,
    `- Name: **\`${filename}\`**`,
    ``,
    `---`,
    ``,
    `*End of open change export.*`,
    ``,
  ].join('\n');
}

export function downloadMarkdownFile(filename: string, markdown: string): void {
  const blob = new Blob([markdown], { type: 'text/markdown;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.rel = 'noopener';
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

export type PersistChangeBuildingResult =
  | { mode: 'dev-server'; path: string }
  | { mode: 'file-picker' }
  | { mode: 'download' };

async function trySaveWithFilePicker(filename: string, markdown: string): Promise<boolean> {
  const w = window as Window & {
    showSaveFilePicker?: (options: {
      suggestedName?: string;
      types?: { description: string; accept: Record<string, string[]> }[];
    }) => Promise<{ createWritable: () => Promise<{ write: (data: string) => Promise<void>; close: () => Promise<void> }> }>;
  };
  if (!w.showSaveFilePicker) return false;
  try {
    const handle = await w.showSaveFilePicker({
      suggestedName: filename,
      types: [{ description: 'Markdown', accept: { 'text/markdown': ['.md'] } }],
    });
    const stream = await handle.createWritable();
    await stream.write(markdown);
    await stream.close();
    return true;
  } catch {
    return false;
  }
}

/**
 * 1) **Dev:** `npm run dev` — POSTs to Vite middleware → writes under repo `CHANGE-ACTIONS/change-building/`.
 * 2) **Browser:** `showSaveFilePicker` (Chrome/Edge) so you can pick that folder manually.
 * 3) **Fallback:** classic download (e.g. production build / preview).
 */
export async function persistChangeBuildingReport(
  filename: string,
  markdown: string,
): Promise<PersistChangeBuildingResult> {
  if (import.meta.env.DEV) {
    try {
      const r = await fetch('/__save-change-building', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ filename, markdown }),
      });
      if (r.ok) {
        const j = (await r.json()) as { path?: string };
        if (j.path) return { mode: 'dev-server', path: j.path };
      }
    } catch {
      /* dev server not running or middleware failed */
    }
  }

  const picked = await trySaveWithFilePicker(filename, markdown);
  if (picked) return { mode: 'file-picker' };

  downloadMarkdownFile(filename, markdown);
  return { mode: 'download' };
}
