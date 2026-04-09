import type { ChangeReviewRow, ChangeStatus } from './types';

/** Change statuses that require `final_state_note` in the database. */
export const TERMINAL_CHANGE_STATUSES: ChangeStatus[] = ['closed', 'cancelled', 'rollbacked', 'rejected'];

export function changeStatusRequiresFinalNote(status: ChangeStatus): boolean {
  return TERMINAL_CHANGE_STATUSES.includes(status);
}

/** Started only when every existing CR row is approved (and at least one CR exists). */
export function canSetChangeStarted(reviews: Pick<ChangeReviewRow, 'status'>[]): boolean {
  return reviews.length > 0 && reviews.every((r) => r.status === 'approved');
}

/** Closed only when every CR is approved. */
export function canSetChangeClosed(reviews: Pick<ChangeReviewRow, 'status'>[]): boolean {
  return reviews.length > 0 && reviews.every((r) => r.status === 'approved');
}

/**
 * From `new`, rollback/cancel allowed only if not every CR is already approved.
 * (No CR rows → allowed.)
 */
export function canNewToRollbackOrCancel(reviews: Pick<ChangeReviewRow, 'status'>[]): boolean {
  if (reviews.length === 0) return true;
  return !reviews.every((r) => r.status === 'approved');
}

export function terminalChangeBlocksTransition(current: ChangeStatus): boolean {
  return TERMINAL_CHANGE_STATUSES.includes(current);
}
