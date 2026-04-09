import { useCallback, useEffect, useMemo, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { DELETE_CHANGE_PASSWORD } from '../config/deleteChangeAuth';
import {
  cascadeCancelUnderChange,
  historyLinePrefix,
  pushChangeTransition,
} from '../lib/changeHistory';
import {
  canNewToRollbackOrCancel,
  canSetChangeClosed,
  canSetChangeStarted,
  changeStatusRequiresFinalNote,
  terminalChangeBlocksTransition,
} from '../lib/changeRules';
import { parseDiscussionLog, parseFeatureNames, parseStatusHistory, previewTaskText } from '../lib/parse';
import {
  buildChangePlanningReportMarkdown,
  changeBuildingFilename,
  persistChangeBuildingReport,
} from '../lib/changeBuildingReport';
import { buildTeamOrder, findReviewForTeam } from '../lib/teamMatch';
import type { ChangeReviewRow, ChangeRow, ChangeStatus, ChangeTaskRow, DiscussionLogEntry } from '../lib/types';

const CHANGE_STATUSES: ChangeStatus[] = ['new', 'started', 'closed', 'cancelled', 'rollbacked', 'rejected'];

export function ChangeDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [change, setChange] = useState<ChangeRow | null>(null);
  const [reviews, setReviews] = useState<ChangeReviewRow[]>([]);
  const [tasksByReview, setTasksByReview] = useState<Record<string, ChangeTaskRow[]>>({});
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const [statusRemark, setStatusRemark] = useState('');
  const [finalStateNote, setFinalStateNote] = useState('');
  const [nextStatus, setNextStatus] = useState<ChangeStatus | ''>('');
  const [savingStatus, setSavingStatus] = useState(false);

  const [deleteOpen, setDeleteOpen] = useState(false);
  const [deletePassword, setDeletePassword] = useState('');
  const [deleteError, setDeleteError] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);

  const [planningSaveMsg, setPlanningSaveMsg] = useState<string | null>(null);
  const [planningSaving, setPlanningSaving] = useState(false);

  const [discussionNewBody, setDiscussionNewBody] = useState('');
  const [discussionSaving, setDiscussionSaving] = useState(false);

  const load = useCallback(async () => {
    if (!id) return;
    setError(null);
    const { data: c, error: e1 } = await supabase.from('changes').select('*').eq('id', id).maybeSingle();
    if (e1) {
      setError(e1.message);
      setChange(null);
      setLoading(false);
      return;
    }
    if (!c) {
      setError('Change not found');
      setChange(null);
      setLoading(false);
      return;
    }
    const raw = c as Record<string, unknown>;
    const row: ChangeRow = {
      ...(c as ChangeRow),
      feature_names: parseFeatureNames(raw.feature_names),
      final_state_note: (raw.final_state_note as string | null | undefined) ?? null,
      discussion_log: parseDiscussionLog(raw.discussion_log),
    };
    setChange(row);
    setNextStatus(row.status);

    const { data: revs, error: e2 } = await supabase.from('change_reviews').select('*').eq('change_id', id);
    if (e2) setError(e2.message);
    setReviews((revs ?? []) as ChangeReviewRow[]);

    const { data: tks, error: e3 } = await supabase.from('change_tasks').select('*').eq('change_id', id);
    if (e3) setError(e3.message);
    const map: Record<string, ChangeTaskRow[]> = {};
    for (const t of (tks ?? []) as ChangeTaskRow[]) {
      map[t.change_review_id] = map[t.change_review_id] ?? [];
      map[t.change_review_id].push(t);
    }
    setTasksByReview(map);
    setLoading(false);
  }, [id]);

  useEffect(() => {
    setLoading(true);
    void load();
  }, [load]);

  const teamRows = useMemo(() => {
    if (!change) return [];
    return buildTeamOrder(change.primary_feature, change.feature_names ?? [], reviews);
  }, [change, reviews]);

  const flatTasks = useMemo(() => {
    const out: { task: ChangeTaskRow; teamKey: string }[] = [];
    for (const r of reviews) {
      for (const t of tasksByReview[r.id] ?? []) {
        out.push({ task: t, teamKey: r.team_key });
      }
    }
    out.sort((a, b) => a.task.ctask_number.localeCompare(b.task.ctask_number));
    return out;
  }, [reviews, tasksByReview]);

  async function applyStatus(e: React.FormEvent) {
    e.preventDefault();
    if (!change || !id || !nextStatus) return;
    if (terminalChangeBlocksTransition(change.status)) {
      setError('This change is already in a terminal state; update via a new change record if needed.');
      return;
    }
    if (nextStatus === change.status) {
      setError('Choose a different status to record a transition.');
      return;
    }
    const remark = statusRemark.trim();
    if (!remark) {
      setError('Status remark is required when changing status.');
      return;
    }
    const finalNote = finalStateNote.trim();
    if (changeStatusRequiresFinalNote(nextStatus)) {
      if (!finalNote) {
        setError('Final state note is required for closed, cancelled, rollbacked, and rejected.');
        return;
      }
    }
    if (nextStatus === 'started' && !canSetChangeStarted(reviews)) {
      setError('Cannot set to started until every change review is approved (at least one review row must exist).');
      return;
    }
    if (nextStatus === 'closed' && !canSetChangeClosed(reviews)) {
      setError('Cannot close until every change review is approved.');
      return;
    }
    if (
      change.status === 'new' &&
      (nextStatus === 'rollbacked' || nextStatus === 'cancelled') &&
      !canNewToRollbackOrCancel(reviews)
    ) {
      setError('Cannot rollback or cancel from new while every review is already approved.');
      return;
    }
    setSavingStatus(true);
    setError(null);
    try {
      const history = pushChangeTransition(change, nextStatus, remark);
      const { error: err } = await supabase
        .from('changes')
        .update({
          status: nextStatus,
          status_remark: remark,
          status_history: history,
          final_state_note: changeStatusRequiresFinalNote(nextStatus) ? finalNote : null,
          closed_at: nextStatus === 'closed' ? new Date().toISOString() : null,
        })
        .eq('id', id);
      if (err) throw err;
      if (nextStatus === 'cancelled' || nextStatus === 'rejected') {
        await cascadeCancelUnderChange(id, remark);
      }
      setStatusRemark('');
      setFinalStateNote('');
      await load();
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Update failed');
    } finally {
      setSavingStatus(false);
    }
  }

  function openDeleteModal() {
    setDeletePassword('');
    setDeleteError(null);
    setDeleteOpen(true);
  }

  function closeDeleteModal() {
    if (!deleting) {
      setDeleteOpen(false);
      setDeletePassword('');
      setDeleteError(null);
    }
  }

  async function addDiscussionNote(e: React.FormEvent) {
    e.preventDefault();
    if (!change || !id) return;
    const body = discussionNewBody.trim();
    if (!body) {
      setError('Discussion note cannot be empty.');
      return;
    }
    setDiscussionSaving(true);
    setError(null);
    try {
      const { data: auth } = await supabase.auth.getUser();
      const u = auth.user;
      const author = u?.email?.trim() || u?.id || null;
      const prev = change.discussion_log;
      const entry: DiscussionLogEntry = { at: new Date().toISOString(), body, author };
      const next: DiscussionLogEntry[] = [entry, ...prev];
      const { error: err } = await supabase.from('changes').update({ discussion_log: next }).eq('id', id);
      if (err) throw err;
      setDiscussionNewBody('');
      await load();
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Could not save discussion note');
    } finally {
      setDiscussionSaving(false);
    }
  }

  async function downloadPlanningReport() {
    if (!change) return;
    setPlanningSaveMsg(null);
    setPlanningSaving(true);
    try {
      const md = buildChangePlanningReportMarkdown(change, { reviews, tasks: flatTasks });
      const fn = changeBuildingFilename(change.change_id);
      const result = await persistChangeBuildingReport(fn, md);
      if (result.mode === 'dev-server') {
        setPlanningSaveMsg(`Saved in repo: ${result.path} (dev server).`);
      } else if (result.mode === 'file-picker') {
        setPlanningSaveMsg('Saved to the folder you picked.');
      } else {
        setPlanningSaveMsg(
          'Downloaded via browser (production or picker unavailable). For auto-save into the repo, run `npm run dev` in change-dashboard.',
        );
      }
    } catch (err: unknown) {
      setPlanningSaveMsg(err instanceof Error ? err.message : 'Could not save file');
    } finally {
      setPlanningSaving(false);
    }
  }

  async function confirmDeleteChange() {
    if (!id) return;
    if (deletePassword !== DELETE_CHANGE_PASSWORD) {
      setDeleteError('Incorrect password.');
      return;
    }
    setDeleting(true);
    setDeleteError(null);
    try {
      const { error: delErr } = await supabase.from('changes').delete().eq('id', id);
      if (delErr) throw delErr;
      setDeleteOpen(false);
      navigate('/changes', { replace: true });
    } catch (err: unknown) {
      setDeleteError(err instanceof Error ? err.message : 'Delete failed');
    } finally {
      setDeleting(false);
    }
  }

  if (loading && !change) return <p className="muted">Loading…</p>;
  if (error && !change) return <p className="error">{error}</p>;
  if (!change) return null;

  const history = parseStatusHistory(change.status_history);

  return (
    <div className="page-stack detail-page">
      {deleteOpen && (
        <div className="modal-overlay" role="presentation" onClick={closeDeleteModal}>
          <div
            className="modal-dialog"
            role="dialog"
            aria-modal="true"
            aria-labelledby="delete-change-title"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 id="delete-change-title">Delete this change?</h3>
            <p className="muted" style={{ margin: '0 0 0.75rem', fontSize: '0.85rem' }}>
              This removes the change and related approver rows and CTASKs (database cascade). Enter the delete
              password to confirm.
            </p>
            <div className="field">
              <label htmlFor="delete-pw">Password</label>
              <input
                id="delete-pw"
                type="password"
                autoComplete="off"
                value={deletePassword}
                onChange={(e) => setDeletePassword(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') void confirmDeleteChange();
                }}
              />
            </div>
            {deleteError && <p className="error">{deleteError}</p>}
            <div className="modal-dialog__actions">
              <button type="button" className="btn" onClick={closeDeleteModal} disabled={deleting}>
                Cancel
              </button>
              <button type="button" className="btn btn-danger" onClick={() => void confirmDeleteChange()} disabled={deleting}>
                {deleting ? 'Deleting…' : 'Delete permanently'}
              </button>
            </div>
          </div>
        </div>
      )}

      <div className="detail-toolbar">
        <Link to="/changes" className="back-link muted">
          ← All changes
        </Link>
        <div className="detail-toolbar__actions">
          {(change.status === 'new' || change.status === 'started') && (
            <button
              type="button"
              className="btn"
              disabled={planningSaving}
              onClick={() => void downloadPlanningReport()}
            >
              {planningSaving ? 'Saving…' : 'Save open change report (.md)'}
            </button>
          )}
          <Link to={`/changes/${id}/edit`} className="btn btn-primary detail-toolbar__edit">
            Edit change
          </Link>
          <button type="button" className="btn btn-danger" onClick={openDeleteModal}>
            Delete change
          </button>
        </div>
      </div>

      {(change.status === 'new' || change.status === 'started') && (
        <div className="detail-box" style={{ marginBottom: '1rem' }}>
          <div className="detail-box__title">Open change — export (.md)</div>
          <div className="detail-box__body detail-box__body--tight">
            <p className="muted" style={{ margin: '0 0 0.65rem', fontSize: '0.8125rem' }}>
              While status is <strong>new</strong> or <strong>started</strong>, you can save a single markdown file with{' '}
              <strong>all change fields</strong>, <strong>every approver + CTASK</strong> loaded on this page, and a{' '}
              <strong>work notes</strong> section: discussion + status transitions merged <strong>oldest → newest</strong>{' '}
              by timestamp. With <code>npm run dev</code>, it writes to{' '}
              <code>CHANGE-ACTIONS/change-building/{change.change_id}-change-building.md</code> at the diaryapp repo
              root. Otherwise the browser asks where to save, or downloads. See{' '}
              <code>CHANGE-ACTIONS/change-building/README.md</code>.
            </p>
            {planningSaveMsg && (
              <p className="muted" style={{ margin: '0 0 0.65rem', fontSize: '0.8125rem', color: '#059669' }}>
                {planningSaveMsg}
              </p>
            )}
            <button
              type="button"
              className="btn btn-primary"
              disabled={planningSaving}
              onClick={() => void downloadPlanningReport()}
            >
              {planningSaving ? 'Saving…' : (
                <>
                  Save <code style={{ fontSize: '0.85em' }}>{change.change_id}-change-building.md</code>
                </>
              )}
            </button>
          </div>
        </div>
      )}

      {error && <p className="error">{error}</p>}

      <div className="detail-top-grid">
        <span className="lbl">Change</span>
        <span className="val">{change.change_id}</span>
        <span className="lbl">Status</span>
        <span className="val">
          <span className="status-pill">{change.status}</span>
        </span>

        <span className="lbl">Type</span>
        <span className="val">{change.type}</span>
        <span className="lbl">Primary</span>
        <span className="val">{change.primary_feature || '—'}</span>

        <span className="lbl">Created</span>
        <span className="val">{new Date(change.created_at).toLocaleString()}</span>
        <span className="lbl">By</span>
        <span className="val">{change.created_by || '—'}</span>
      </div>

      {change.final_state_note && (
        <div className="detail-box">
          <div className="detail-box__title">Final state note</div>
          <div className="detail-box__body">{change.final_state_note}</div>
        </div>
      )}

      <div className="detail-box">
        <div className="detail-box__title">Short description</div>
        <div className="detail-box__body">{change.short_description || '—'}</div>
      </div>

      <div className="detail-box">
        <div className="detail-box__title">Description</div>
        <div className="detail-box__body">{change.description || '—'}</div>
      </div>

      <div className="detail-box">
        <div className="detail-box__title">Affected features</div>
        <div className="detail-box__body detail-box__body--tight">
          {(change.feature_names ?? []).length ? (change.feature_names ?? []).join(', ') : '—'}
        </div>
      </div>

      <div className="detail-box">
        <div className="detail-box__title">Rollback plan</div>
        <div className="detail-box__body">{change.rollback_plan || '—'}</div>
      </div>

      <div className="detail-box">
        <div className="detail-box__title">Discussed details</div>
        <div className="detail-box__body">{change.discussed_details || '—'}</div>
      </div>

      <div className="detail-box">
        <div className="detail-box__title">Discussion</div>
        <div className="detail-box__body detail-box__body--tight" style={{ width: '100%', maxWidth: '100%' }}>
          <p className="muted" style={{ margin: '0 0 0.5rem', fontSize: '0.7rem' }}>
            Short thread of notes (newest on top). Separate from status history and the single “discussed details” field.
          </p>
          {change.discussion_log.length === 0 && <span className="muted" style={{ fontSize: '0.72rem' }}>No notes yet.</span>}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 0 }}>
            {change.discussion_log.map((d, i) => (
              <div
                key={`${d.at}-${i}`}
                style={{
                  fontSize: '0.72rem',
                  lineHeight: 1.35,
                  padding: '0.35rem 0',
                  borderBottom: '1px solid var(--border, #e8e8e8)',
                  width: '100%',
                }}
              >
                <div className="muted" style={{ fontSize: '0.65rem', marginBottom: '0.15rem' }}>
                  {new Date(d.at).toLocaleString()}
                  {d.author ? ` · ${d.author}` : ''}
                </div>
                <div style={{ whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>{d.body}</div>
              </div>
            ))}
          </div>
          <form
            onSubmit={(ev) => {
              void addDiscussionNote(ev);
            }}
            style={{ marginTop: '0.65rem' }}
          >
            <div className="field" style={{ marginBottom: '0.45rem' }}>
              <label htmlFor="disc-new">Add note</label>
              <textarea
                id="disc-new"
                value={discussionNewBody}
                onChange={(e) => setDiscussionNewBody(e.target.value)}
                placeholder="Discussion note…"
                rows={2}
                style={{ fontSize: '0.8rem', width: '100%', maxWidth: '100%', boxSizing: 'border-box' }}
              />
            </div>
            <button type="submit" className="btn btn-primary" disabled={discussionSaving}>
              {discussionSaving ? 'Saving…' : 'Append note'}
            </button>
          </form>
        </div>
      </div>

      <h2>Update change status</h2>
      <div className="detail-box">
        <div className="detail-box__title">Transition</div>
        <div className="detail-box__body detail-box__body--tight">
          <form onSubmit={applyStatus}>
            <div className="row" style={{ alignItems: 'flex-end', marginBottom: '0.5rem' }}>
              <div className="field" style={{ flex: 1, minWidth: 140, marginBottom: 0 }}>
                <label htmlFor="ns">New status</label>
                <select
                  id="ns"
                  value={nextStatus || change.status}
                  onChange={(e) => setNextStatus(e.target.value as ChangeStatus)}
                >
                  {CHANGE_STATUSES.map((s) => (
                    <option key={s} value={s}>
                      {s}
                    </option>
                  ))}
                </select>
              </div>
              <div className="field" style={{ flex: 2, minWidth: 200, marginBottom: 0 }}>
                <label htmlFor="rm">Status remark *</label>
                <textarea
                  id="rm"
                  value={statusRemark}
                  onChange={(e) => setStatusRemark(e.target.value)}
                  placeholder="Required — why this status change (shown in history below)"
                  rows={2}
                  required
                />
              </div>
            </div>
            {nextStatus && changeStatusRequiresFinalNote(nextStatus) && (
              <div className="field" style={{ marginBottom: '0.5rem' }}>
                <label htmlFor="fsn">Final state note *</label>
                <textarea
                  id="fsn"
                  value={finalStateNote}
                  onChange={(e) => setFinalStateNote(e.target.value)}
                  placeholder="Full detail for this terminal outcome (stored in final_state_note)"
                  rows={4}
                  required
                />
              </div>
            )}
            <button type="submit" className="btn btn-primary" disabled={savingStatus}>
              {savingStatus ? 'Saving…' : 'Save status'}
            </button>
          </form>
        </div>
      </div>

      <div className="detail-box">
        <div className="detail-box__title">Status history (change, approvers &amp; CTASKs)</div>
        <div className="detail-box__body detail-box__body--tight">
          {history.length === 0 && <span className="muted">No transitions yet.</span>}
          <ul style={{ margin: 0, paddingLeft: '1.1rem' }}>
            {history.map((h, i) => (
              <li key={i} style={{ marginBottom: '0.4rem' }}>
                <span className="muted" style={{ fontSize: '0.68rem', fontWeight: 700 }}>
                  {historyLinePrefix(h)}
                </span>{' '}
                {h.from ?? '?'} → <strong>{h.to}</strong>: {h.remark}{' '}
                <span className="muted">({new Date(h.at).toLocaleString()})</span>
              </li>
            ))}
          </ul>
        </div>
      </div>

      <h2>Approvers</h2>
      <p className="muted" style={{ fontSize: '0.72rem', margin: '-0.25rem 0 0.4rem' }}>
        Click a team row to open that approver&apos;s page (same boxed layout). Cursor updates CR in Supabase —
        approved rows still store full text.
      </p>

      <div className="cr-list">
        <div className="cr-list__head">
          <span>#</span>
          <span>Team</span>
          <span>Status</span>
        </div>
        {teamRows.length === 0 && (
          <div style={{ padding: '0.5rem 0.55rem', fontSize: '0.78rem' }} className="muted">
            No teams in scope. Set primary and affected features on this change, or add reviews in Supabase.
          </div>
        )}
        {teamRows.map((teamLabel, idx) => {
          const rev = findReviewForTeam(reviews, teamLabel);
          const open = !rev;
          const statusLabel = rev?.status ?? 'open';
          const to = `/changes/${id}/review/${encodeURIComponent(teamLabel)}`;
          return (
            <Link key={`${teamLabel}-${idx}`} to={to} className="cr-list__rowlink">
              <span className="muted" style={{ fontSize: '0.72rem' }}>
                {idx + 1}
              </span>
              <span>
                {teamLabel}
                <span className="cr-list__rowhint"> View →</span>
              </span>
              <span className={open ? 'status-pill status-pill--open' : 'status-pill'}>{statusLabel}</span>
            </Link>
          );
        })}
      </div>

      {flatTasks.length > 0 && (
        <>
          <h2>CTASKs</h2>
          <div className="detail-box">
            <div className="detail-box__title">All tasks for this change</div>
            <div className="detail-box__body" style={{ padding: 0 }}>
              <table className="ctask-table">
                <thead>
                  <tr>
                    <th>#</th>
                    <th>CTASK</th>
                    <th>Team</th>
                    <th>Status</th>
                    <th>Motive</th>
                    <th>Task</th>
                  </tr>
                </thead>
                <tbody>
                  {flatTasks.map((row, i) => (
                    <tr key={row.task.id}>
                      <td>{i + 1}</td>
                      <td>
                        <Link to={`/changes/${id}/ctask/${row.task.id}`}>
                          <strong>{row.task.ctask_number}</strong>
                        </Link>
                      </td>
                      <td>{row.teamKey}</td>
                      <td>
                        <span className="status-pill">{row.task.status}</span>
                      </td>
                      <td style={{ fontSize: '0.72rem' }}>{row.task.motive || '—'}</td>
                      <td style={{ fontSize: '0.72rem' }} title={row.task.task ?? undefined}>
                        {previewTaskText(row.task.task)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {flatTasks.some((r) => r.task.status_remark) && (
                <div style={{ padding: '0.4rem 0.6rem', fontSize: '0.72rem', borderTop: '1px solid #eee' }}>
                  <strong>Remarks:</strong>{' '}
                  {flatTasks
                    .filter((r) => r.task.status_remark)
                    .map((r) => `${r.task.ctask_number}: ${r.task.status_remark}`)
                    .join(' · ')}
                </div>
              )}
            </div>
          </div>
        </>
      )}
    </div>
  );
}
