import { useCallback, useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import {
  appendChangeAuditLine,
  cascadeCancelPeersAfterReject,
  pushReviewTransition,
  pushTaskTransition,
} from '../lib/changeHistory';
import { parseDiscussionLog, parseFeatureNames, parseStatusHistory } from '../lib/parse';
import type { ChangeReviewRow, ChangeRow, ChangeTaskRow, ChangeStatus, TaskStatus } from '../lib/types';

const TASK_STATUSES: TaskStatus[] = ['new', 'open', 'implementing', 'closed', 'rejected', 'skipped', 'cancelled'];

const TERMINAL_CHANGE: ChangeStatus[] = ['closed', 'cancelled', 'rollbacked', 'rejected'];

/** Drive CR from CTASK rows: all closed/skipped → approved; any implementing/closed → implementing. */
async function syncReviewStatusFromTasks(changeReviewId: string) {
  const { data: tasks, error } = await supabase
    .from('change_tasks')
    .select('status')
    .eq('change_review_id', changeReviewId);
  if (error) throw error;
  if (!tasks?.length) return;

  const { data: cr, error: e2 } = await supabase
    .from('change_reviews')
    .select('id, status, status_history')
    .eq('id', changeReviewId)
    .maybeSingle();
  if (e2 || !cr) return;

  const crRow = cr as ChangeReviewRow;
  if (crRow.status === 'rejected' || crRow.status === 'cancelled') return;

  const stats = tasks.map((t: { status: string }) => t.status);
  const allDone = stats.every((s) => s === 'closed' || s === 'skipped');
  const anyWork = stats.some((s) => s === 'implementing' || s === 'closed');

  const ts = new Date().toISOString();

  if (allDone) {
    const { error: e3 } = await supabase
      .from('change_reviews')
      .update({ status: 'approved', reviewed_at: ts })
      .eq('id', changeReviewId);
    if (e3) throw e3;
    return;
  }

  if (anyWork && crRow.status !== 'approved') {
    const { error: e4 } = await supabase
      .from('change_reviews')
      .update({ status: 'implementing', reviewed_at: ts })
      .eq('id', changeReviewId);
    if (e4) throw e4;
  }
}

function mapTaskRow(t: ChangeTaskRow): ChangeTaskRow {
  const raw = t as unknown as Record<string, unknown>;
  return {
    ...t,
    task: t.task ?? null,
    status_history: raw.status_history ?? [],
  };
}

export function CtaskDetailPage() {
  const { id: changeUuid, taskId } = useParams<{ id: string; taskId: string }>();
  const [change, setChange] = useState<ChangeRow | null>(null);
  const [task, setTask] = useState<ChangeTaskRow | null>(null);
  const [review, setReview] = useState<ChangeReviewRow | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [nextStatus, setNextStatus] = useState<TaskStatus>('open');
  const [statusRemark, setStatusRemark] = useState('');
  /** DB column `task` — detailed instructions */
  const [instruction, setInstruction] = useState('');
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    if (!changeUuid || !taskId) return;
    setError(null);
    setLoading(true);
    const { data: t, error: e1 } = await supabase.from('change_tasks').select('*').eq('id', taskId).maybeSingle();
    if (e1 || !t) {
      setError(e1?.message ?? 'CTASK not found');
      setTask(null);
      setChange(null);
      setReview(null);
      setLoading(false);
      return;
    }
    const row = mapTaskRow(t as ChangeTaskRow);
    if (row.change_id !== changeUuid) {
      setError('This CTASK does not belong to this change.');
      setTask(null);
      setChange(null);
      setReview(null);
      setLoading(false);
      return;
    }
    setTask(row);
    setNextStatus(row.status);
    setStatusRemark(row.status_remark ?? '');
    setInstruction(row.task ?? '');

    const { data: c, error: e2 } = await supabase.from('changes').select('*').eq('id', changeUuid).maybeSingle();
    if (e2 || !c) {
      setError(e2?.message ?? 'Change not found');
      setLoading(false);
      return;
    }
    const cr = c as Record<string, unknown>;
    setChange({
      ...(c as ChangeRow),
      feature_names: parseFeatureNames(cr.feature_names),
      final_state_note: (cr.final_state_note as string | null | undefined) ?? null,
      discussion_log: parseDiscussionLog(cr.discussion_log),
    });

    const { data: r, error: e3 } = await supabase
      .from('change_reviews')
      .select('*')
      .eq('id', row.change_review_id)
      .maybeSingle();
    if (e3) setError(e3.message);
    const rev = r as ChangeReviewRow | null;
    setReview(
      rev
        ? {
            ...rev,
            rejection_remark: (rev as unknown as { rejection_remark?: string | null }).rejection_remark ?? null,
            status_history: (rev as unknown as { status_history?: unknown }).status_history ?? [],
          }
        : null,
    );
    setLoading(false);
  }, [changeUuid, taskId]);

  useEffect(() => {
    void load();
  }, [load]);

  async function save(e: React.FormEvent) {
    e.preventDefault();
    if (!task || !change || !changeUuid || !review) return;
    const remark = statusRemark.trim();
    if (!remark) {
      setError('Status remark is required.');
      return;
    }
    setSaving(true);
    setError(null);
    try {
      const prevStatus = task.status;
      const taskHist = pushTaskTransition(task, nextStatus, remark, task.ctask_number);

      if (nextStatus === 'rejected') {
        if (!TERMINAL_CHANGE.includes(change.status)) {
          const finalNote = remark;
          const crHist = pushReviewTransition(review, 'rejected', remark, review.team_key);
          const chHist = parseStatusHistory(change.status_history);
          const at = new Date().toISOString();
          chHist.push({
            from: prevStatus,
            to: 'rejected',
            remark,
            at,
            scope: 'task',
            ref: task.ctask_number,
          });
          chHist.push({
            from: change.status,
            to: 'rejected',
            remark: `Change rejected after CTASK ${task.ctask_number} rejected.`,
            at,
            scope: 'change',
          });

          const { error: u1 } = await supabase
            .from('change_tasks')
            .update({
              status: 'rejected',
              status_remark: remark,
              task: instruction.trim() || null,
              status_history: taskHist,
            })
            .eq('id', task.id)
            .eq('change_id', changeUuid);
          if (u1) throw u1;

          const { error: u2 } = await supabase
            .from('change_reviews')
            .update({
              status: 'rejected',
              reviewed_at: at,
              status_remark: remark,
              rejection_remark: remark,
              status_history: crHist,
            })
            .eq('id', task.change_review_id);
          if (u2) throw u2;

          const { error: u3 } = await supabase
            .from('changes')
            .update({
              status: 'rejected',
              status_remark: `CTASK ${task.ctask_number} rejected`,
              status_history: chHist,
              final_state_note: finalNote,
              closed_at: null,
            })
            .eq('id', changeUuid);
          if (u3) throw u3;

          await cascadeCancelPeersAfterReject(changeUuid, review.id, task.id, remark);
        } else {
          const { error: u1 } = await supabase
            .from('change_tasks')
            .update({
              status: 'rejected',
              status_remark: remark,
              task: instruction.trim() || null,
              status_history: taskHist,
            })
            .eq('id', task.id)
            .eq('change_id', changeUuid);
          if (u1) throw u1;
          await appendChangeAuditLine(changeUuid, {
            from: prevStatus,
            to: 'rejected',
            remark,
            scope: 'task',
            ref: task.ctask_number,
          });
        }
      } else {
        const { error: u1 } = await supabase
          .from('change_tasks')
          .update({
            status: nextStatus,
            status_remark: remark,
            task: instruction.trim() || null,
            status_history: taskHist,
          })
          .eq('id', task.id)
          .eq('change_id', changeUuid);
        if (u1) throw u1;
        await appendChangeAuditLine(changeUuid, {
          from: prevStatus,
          to: nextStatus,
          remark,
          scope: 'task',
          ref: task.ctask_number,
        });
        await syncReviewStatusFromTasks(task.change_review_id);
      }

      await load();
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Save failed');
    } finally {
      setSaving(false);
    }
  }

  if (loading) return <p className="muted">Loading…</p>;
  if (error && !task) return <p className="error">{error}</p>;
  if (!task || !change) return null;

  return (
    <div className="page-stack detail-page">
      <div className="detail-toolbar">
        <Link to={`/changes/${changeUuid}`} className="back-link muted">
          ← Back to change
        </Link>
      </div>
      {error && <p className="error">{error}</p>}

      <div className="detail-top-grid">
        <span className="lbl">Change</span>
        <span className="val">{change.change_id}</span>
        <span className="lbl">CTASK</span>
        <span className="val">{task.ctask_number}</span>
        <span className="lbl">Team (CR)</span>
        <span className="val">{review?.team_key ?? '—'}</span>
        <span className="lbl">Status</span>
        <span className="val">
          <span className="status-pill">{task.status}</span>
        </span>
      </div>

      <div className="detail-box">
        <div className="detail-box__title">Motive</div>
        <div className="detail-box__body">{task.motive || '—'}</div>
      </div>

      <div className="detail-box">
        <div className="detail-box__title">Update CTASK</div>
        <div className="detail-box__body detail-box__body--tight">
          <p className="muted" style={{ margin: '0 0 0.5rem', fontSize: '0.72rem' }}>
            <strong>open</strong> / <strong>new</strong>: not accepted yet. Accept work → set <strong>implementing</strong>,
            then <strong>closed</strong> when done. <strong>rejected</strong> sets this CR to rejected, parent change to{' '}
            <strong>rejected</strong> (with this remark as <code>final_state_note</code>), and cancels sibling reviews /
            tasks. When every CTASK for the team is <strong>closed</strong> or <strong>skipped</strong>, the CR becomes{' '}
            <strong>approved</strong>; any <strong>implementing</strong> or <strong>closed</strong> task moves CR to{' '}
            <strong>implementing</strong>.
          </p>
          <form onSubmit={save}>
            <div className="field" style={{ marginBottom: '0.5rem' }}>
              <label htmlFor="ct-task">Task (detailed instructions)</label>
              <textarea
                id="ct-task"
                value={instruction}
                onChange={(e) => setInstruction(e.target.value)}
                placeholder="Step-by-step or detailed instructions to perform this CTASK"
                rows={6}
              />
            </div>
            <div className="field" style={{ marginBottom: '0.5rem' }}>
              <label htmlFor="cts">Status</label>
              <select id="cts" value={nextStatus} onChange={(e) => setNextStatus(e.target.value as TaskStatus)}>
                {TASK_STATUSES.map((s) => (
                  <option key={s} value={s}>
                    {s}
                  </option>
                ))}
              </select>
            </div>
            <div className="field" style={{ marginBottom: '0.5rem' }}>
              <label htmlFor="ctr">Status remark *</label>
              <textarea
                id="ctr"
                value={statusRemark}
                onChange={(e) => setStatusRemark(e.target.value)}
                placeholder="Required — audit note; for reject, also fills final_state_note on the change"
                rows={3}
                required
              />
            </div>
            <button type="submit" className="btn btn-primary" disabled={saving}>
              {saving ? 'Saving…' : 'Save'}
            </button>
          </form>
        </div>
      </div>

      {review && (
        <p className="muted" style={{ fontSize: '0.75rem' }}>
          Review:{' '}
          <Link to={`/changes/${changeUuid}/review/${encodeURIComponent(review.team_key)}`}>
            Open team CR ({review.team_key})
          </Link>
        </p>
      )}
    </div>
  );
}
