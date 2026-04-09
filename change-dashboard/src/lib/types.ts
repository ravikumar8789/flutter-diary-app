export type ChangeStatus = 'new' | 'started' | 'closed' | 'cancelled' | 'rollbacked' | 'rejected';
export type ChangeType = 'fix' | 'add' | 'remove' | 'refactor' | 'other';
export type ReviewStatus = 'new' | 'open' | 'implementing' | 'rejected' | 'approved' | 'cancelled';
export type TaskStatus = 'new' | 'open' | 'implementing' | 'closed' | 'rejected' | 'skipped' | 'cancelled';

export type StatusHistoryEntry = {
  from: string | null;
  to: string;
  remark: string;
  at: string;
  /** Where this transition was recorded from */
  scope?: 'change' | 'review' | 'task';
  /** e.g. team_key or CTASK number */
  ref?: string;
};

/** One line in `changes.discussion_log` (newest first in array). */
export type DiscussionLogEntry = {
  at: string;
  body: string;
  author?: string | null;
};

export type ChangeRow = {
  id: string;
  change_id: string;
  created_at: string;
  updated_at: string;
  status: ChangeStatus;
  status_remark: string | null;
  status_history: StatusHistoryEntry[] | unknown;
  type: ChangeType;
  primary_feature: string | null;
  feature_names: string[];
  short_description: string;
  description: string;
  rollback_plan: string | null;
  discussed_details: string | null;
  /** Thread notes; newest first (prepend on add). */
  discussion_log: DiscussionLogEntry[];
  created_by: string | null;
  closed_at: string | null;
  /** Required when status is closed, cancelled, rollbacked, or rejected */
  final_state_note: string | null;
};

export type ChangeReviewRow = {
  id: string;
  change_id: string;
  team_key: string;
  status: ReviewStatus;
  /** Remark for the latest status transition (dashboard) */
  status_remark: string | null;
  /** Set when CR is rejected (e.g. from CTASK reject) */
  rejection_remark: string | null;
  status_history: StatusHistoryEntry[] | unknown;
  impact_summary: string | null;
  justification: string | null;
  conflict: boolean;
  full_discussion: string | null;
  doc_updates_suggested: string | null;
  reviewed_at: string | null;
  created_at: string;
  updated_at: string;
};

export type ChangeTaskRow = {
  id: string;
  change_id: string;
  change_review_id: string;
  ctask_number: string;
  motive: string | null;
  /** Detailed instructions to perform this CTASK */
  task: string | null;
  status: TaskStatus;
  status_remark: string | null;
  status_history: StatusHistoryEntry[] | unknown;
  created_at: string;
  updated_at: string;
};
