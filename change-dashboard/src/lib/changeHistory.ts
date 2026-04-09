import { supabase } from './supabase';
import type { ChangeReviewRow, ChangeRow, ChangeTaskRow, StatusHistoryEntry } from './types';
import { parseStatusHistory } from './parse';

/** Append one audit line to `changes.status_history` (reads current row, then updates). */
export async function appendChangeAuditLine(
  changeId: string,
  entry: Omit<StatusHistoryEntry, 'at'> & { at?: string },
): Promise<StatusHistoryEntry[]> {
  const { data: row, error: e1 } = await supabase.from('changes').select('status_history').eq('id', changeId).maybeSingle();
  if (e1) throw e1;
  const history = parseStatusHistory(row?.status_history);
  const full: StatusHistoryEntry = {
    from: entry.from,
    to: entry.to,
    remark: entry.remark,
    at: entry.at ?? new Date().toISOString(),
    ...(entry.scope !== undefined ? { scope: entry.scope } : {}),
    ...(entry.ref !== undefined ? { ref: entry.ref } : {}),
  };
  history.push(full);
  const { error: e2 } = await supabase.from('changes').update({ status_history: history }).eq('id', changeId);
  if (e2) throw e2;
  return history;
}

/** Set all approver rows + CTASK rows under a change to cancelled with the same remark. */
export async function cascadeCancelUnderChange(changeId: string, remark: string): Promise<void> {
  const ts = new Date().toISOString();
  const { error: e1 } = await supabase
    .from('change_reviews')
    .update({ status: 'cancelled', status_remark: remark, reviewed_at: ts })
    .eq('change_id', changeId);
  if (e1) throw e1;
  const { error: e2 } = await supabase
    .from('change_tasks')
    .update({ status: 'cancelled', status_remark: remark })
    .eq('change_id', changeId);
  if (e2) throw e2;
}

/** After one CTASK rejects: cancel sibling reviews/tasks so the rejected CR row is untouched. */
export async function cascadeCancelPeersAfterReject(
  changeId: string,
  excludeReviewId: string,
  excludeTaskId: string,
  remark: string,
): Promise<void> {
  const ts = new Date().toISOString();
  const { error: e1 } = await supabase
    .from('change_reviews')
    .update({ status: 'cancelled', status_remark: remark, reviewed_at: ts })
    .eq('change_id', changeId)
    .neq('id', excludeReviewId);
  if (e1) throw e1;
  const { error: e2 } = await supabase
    .from('change_tasks')
    .update({ status: 'cancelled', status_remark: remark })
    .eq('change_id', changeId)
    .neq('id', excludeTaskId);
  if (e2) throw e2;
}

/** Build next `status_history` after a change-level transition (caller persists with change update). */
export function pushChangeTransition(
  change: Pick<ChangeRow, 'status' | 'status_history'>,
  to: string,
  remark: string,
): StatusHistoryEntry[] {
  const history = parseStatusHistory(change.status_history);
  history.push({
    from: change.status,
    to,
    remark,
    at: new Date().toISOString(),
    scope: 'change',
  });
  return history;
}

export function pushReviewTransition(
  review: Pick<ChangeReviewRow, 'status' | 'status_history'>,
  to: string,
  remark: string,
  teamKey: string,
): StatusHistoryEntry[] {
  const history = parseStatusHistory(review.status_history);
  history.push({
    from: review.status,
    to,
    remark,
    at: new Date().toISOString(),
    scope: 'review',
    ref: teamKey,
  });
  return history;
}

export function pushTaskTransition(
  task: Pick<ChangeTaskRow, 'status' | 'status_history'>,
  to: string,
  remark: string,
  ctaskNumber: string,
): StatusHistoryEntry[] {
  const history = parseStatusHistory(task.status_history);
  history.push({
    from: task.status,
    to,
    remark,
    at: new Date().toISOString(),
    scope: 'task',
    ref: ctaskNumber,
  });
  return history;
}

export function historyLinePrefix(h: StatusHistoryEntry): string {
  if (h.scope === 'review' && h.ref) return `[Approver ${h.ref}]`;
  if (h.scope === 'task' && h.ref) return `[CTASK ${h.ref}]`;
  return '[Change]';
}
