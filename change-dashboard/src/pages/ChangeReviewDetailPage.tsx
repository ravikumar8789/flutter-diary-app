import { useCallback, useEffect, useMemo, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { appendChangeAuditLine, pushReviewTransition, pushTaskTransition } from '../lib/changeHistory';
import { parseDiscussionLog, parseFeatureNames, previewTaskText } from '../lib/parse';
import { findReviewForTeam } from '../lib/teamMatch';
import type { ChangeReviewRow, ChangeRow, ChangeTaskRow, ReviewStatus } from '../lib/types';

const REVIEW_STATUSES: ReviewStatus[] = ['new', 'open', 'implementing', 'rejected', 'approved', 'cancelled'];

export function ChangeReviewDetailPage() {
  const { id, teamKey: teamKeyParam } = useParams<{ id: string; teamKey: string }>();
  const teamLabel = useMemo(() => {
    if (!teamKeyParam) return '';
    try {
      return decodeURIComponent(teamKeyParam);
    } catch {
      return teamKeyParam;
    }
  }, [teamKeyParam]);

  const [change, setChange] = useState<ChangeRow | null>(null);
  const [review, setReview] = useState<ChangeReviewRow | null>(null);
  const [tasks, setTasks] = useState<ChangeTaskRow[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [nextCrStatus, setNextCrStatus] = useState<ReviewStatus>('open');
  const [crRemark, setCrRemark] = useState('');
  const [savingCrStatus, setSavingCrStatus] = useState(false);
  const [resetRemark, setResetRemark] = useState('');
  const [resetting, setResetting] = useState(false);

  const load = useCallback(async () => {
    if (!id || !teamLabel) return;
    setError(null);
    setLoading(true);
    const { data: c, error: e1 } = await supabase.from('changes').select('*').eq('id', id).maybeSingle();
    if (e1 || !c) {
      setError(e1?.message ?? 'Change not found');
      setChange(null);
      setReview(null);
      setTasks([]);
      setLoading(false);
      return;
    }
    const rawC = c as Record<string, unknown>;
    const row: ChangeRow = {
      ...(c as ChangeRow),
      feature_names: parseFeatureNames(rawC.feature_names),
      discussion_log: parseDiscussionLog(rawC.discussion_log),
    };
    setChange(row);

    const { data: revs, error: e2 } = await supabase.from('change_reviews').select('*').eq('change_id', id);
    if (e2) setError(e2.message);
    const list = (revs ?? []) as ChangeReviewRow[];
    const r = findReviewForTeam(list, teamLabel) ?? null;
    setReview(
      r
        ? {
            ...r,
            rejection_remark: (r as unknown as { rejection_remark?: string | null }).rejection_remark ?? null,
            status_history: (r as unknown as { status_history?: unknown }).status_history ?? [],
          }
        : null,
    );

    if (r) {
      const { data: tks, error: e3 } = await supabase
        .from('change_tasks')
        .select('*')
        .eq('change_review_id', r.id)
        .order('ctask_number');
      if (e3) setError(e3.message);
      setTasks(
        ((tks ?? []) as ChangeTaskRow[]).map((t) => ({
          ...t,
          status_history: (t as unknown as { status_history?: unknown }).status_history ?? [],
        })),
      );
    } else {
      setTasks([]);
    }
    setLoading(false);
  }, [id, teamLabel]);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    if (review) {
      setNextCrStatus(review.status);
      setCrRemark(review.status_remark ?? '');
    }
  }, [review?.id, review?.status, review?.status_remark]);

  async function saveCrStatus(e: React.FormEvent) {
    e.preventDefault();
    if (!review || !id || !change) return;
    const remark = crRemark.trim();
    if (!remark) {
      setError('Status remark is required.');
      return;
    }
    if (nextCrStatus === 'approved') {
      const ok = tasks.every((t) => t.status === 'closed' || t.status === 'skipped');
      if (!ok) {
        setError('Cannot set CR to approved until every CTASK is closed or skipped.');
        return;
      }
    }
    setSavingCrStatus(true);
    setError(null);
    try {
      const prev = review.status;
      const rh = pushReviewTransition(review, nextCrStatus, remark, review.team_key);
      const rejectionRemark = nextCrStatus === 'rejected' ? remark : null;
      const { error: err } = await supabase
        .from('change_reviews')
        .update({
          status: nextCrStatus,
          reviewed_at: new Date().toISOString(),
          status_remark: remark,
          status_history: rh,
          rejection_remark: rejectionRemark,
        })
        .eq('id', review.id);
      if (err) throw err;
      await appendChangeAuditLine(id, {
        from: prev,
        to: nextCrStatus,
        remark,
        scope: 'review',
        ref: review.team_key,
      });
      await load();
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Could not update review status');
    } finally {
      setSavingCrStatus(false);
    }
  }

  async function resetCrAndTasks(e: React.FormEvent) {
    e.preventDefault();
    if (!review || !id) return;
    const remark = resetRemark.trim();
    if (!remark) {
      setError('Reset remark is required.');
      return;
    }
    setResetting(true);
    setError(null);
    try {
      for (const t of tasks) {
        const th = pushTaskTransition(t, 'new', remark, t.ctask_number);
        const { error: te } = await supabase
          .from('change_tasks')
          .update({ status: 'new', status_remark: remark, status_history: th })
          .eq('id', t.id);
        if (te) throw te;
      }
      const rh = pushReviewTransition(review, 'new', remark, review.team_key);
      const { error: re } = await supabase
        .from('change_reviews')
        .update({
          status: 'new',
          status_remark: remark,
          status_history: rh,
          rejection_remark: null,
          reviewed_at: new Date().toISOString(),
        })
        .eq('id', review.id);
      if (re) throw re;
      await appendChangeAuditLine(id, {
        from: review.status,
        to: 'new',
        remark: `Reset CR & CTASKs: ${remark}`,
        scope: 'review',
        ref: review.team_key,
      });
      setResetRemark('');
      await load();
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Reset failed');
    } finally {
      setResetting(false);
    }
  }

  if (loading) return <p className="muted">Loading…</p>;
  if (error && !change) return <p className="error">{error}</p>;
  if (!change) return null;

  const statusLabel = review?.status ?? 'open';

  return (
    <div className="page-stack detail-page">
      <div className="detail-toolbar">
        <Link to={`/changes/${id}`} className="back-link muted">
          ← Back to change
        </Link>
      </div>

      {error && <p className="error">{error}</p>}

      <div className="detail-top-grid">
        <span className="lbl">Change</span>
        <span className="val">{change.change_id}</span>
        <span className="lbl">Team</span>
        <span className="val">{teamLabel}</span>

        <span className="lbl">Review status</span>
        <span className="val">
          <span className={review ? 'status-pill' : 'status-pill status-pill--open'}>{statusLabel}</span>
        </span>
        <span className="lbl">Conflict</span>
        <span className="val">{review?.conflict ? 'Yes' : 'No'}</span>
      </div>

      {!review ? (
        <div className="detail-box">
          <div className="detail-box__title">No review row</div>
          <div className="detail-box__body detail-box__body--tight">
            There is no <code>change_reviews</code> row for this team yet (status <strong>open</strong>). Cursor can
            insert the CR in Supabase when ready.
          </div>
        </div>
      ) : (
        <>
          <div className="detail-box">
            <div className="detail-box__title">Review status — you (after Cursor check)</div>
            <div className="detail-box__body detail-box__body--tight">
              <p className="muted" style={{ margin: '0 0 0.5rem', fontSize: '0.72rem' }}>
                Use <strong>open</strong> while CTASKs are not all done. <strong>approved</strong> is allowed only when
                every CTASK is <strong>closed</strong> or <strong>skipped</strong> (or use reset below to put CR and all
                CTASKs back to <strong>new</strong> for a clean re-run).
              </p>
              <form onSubmit={saveCrStatus}>
                <div className="row" style={{ alignItems: 'flex-end', gap: '0.5rem', flexWrap: 'wrap' }}>
                  <div className="field" style={{ marginBottom: 0, minWidth: 200 }}>
                    <label htmlFor="crs">Status</label>
                    <select id="crs" value={nextCrStatus} onChange={(e) => setNextCrStatus(e.target.value as ReviewStatus)}>
                      {REVIEW_STATUSES.map((s) => (
                        <option key={s} value={s}>
                          {s}
                        </option>
                      ))}
                    </select>
                  </div>
                  <button type="submit" className="btn btn-primary" disabled={savingCrStatus}>
                    {savingCrStatus ? 'Saving…' : 'Save status'}
                  </button>
                </div>
                <div className="field" style={{ marginTop: '0.5rem', marginBottom: 0 }}>
                  <label htmlFor="crr">Status remark *</label>
                  <textarea
                    id="crr"
                    value={crRemark}
                    onChange={(e) => setCrRemark(e.target.value)}
                    rows={2}
                    placeholder="Required — recorded on this approver row and in the change status history"
                    required
                  />
                </div>
              </form>
              {tasks.length > 0 && (
                <form
                  onSubmit={(ev) => void resetCrAndTasks(ev)}
                  style={{ marginTop: '1rem', paddingTop: '0.75rem', borderTop: '1px solid #eee' }}
                >
                  <div className="detail-box__title" style={{ fontSize: '0.8rem', marginBottom: '0.35rem' }}>
                    Reset CR &amp; CTASKs to <code>new</code>
                  </div>
                  <p className="muted" style={{ margin: '0 0 0.5rem', fontSize: '0.7rem' }}>
                    Re-opens implementation for this team: all CTASKs and this CR become <strong>new</strong>, with audit
                    history preserved.
                  </p>
                  <div className="field" style={{ marginBottom: '0.5rem' }}>
                    <label htmlFor="reset-rm">Reset remark *</label>
                    <textarea
                      id="reset-rm"
                      value={resetRemark}
                      onChange={(e) => setResetRemark(e.target.value)}
                      rows={2}
                      placeholder="Why resetting (recorded on each row and change history)"
                      required
                    />
                  </div>
                  <button type="submit" className="btn" disabled={resetting}>
                    {resetting ? 'Resetting…' : 'Reset to new'}
                  </button>
                </form>
              )}
            </div>
          </div>
          {review.rejection_remark && (
            <div className="detail-box">
              <div className="detail-box__title">Rejection remark</div>
              <div className="detail-box__body">{review.rejection_remark}</div>
            </div>
          )}
          <div className="detail-box">
            <div className="detail-box__title">Impact summary</div>
            <div className="detail-box__body">{review.impact_summary || '—'}</div>
          </div>
          <div className="detail-box">
            <div className="detail-box__title">Justification</div>
            <div className="detail-box__body">{review.justification || '—'}</div>
          </div>
          <div className="detail-box">
            <div className="detail-box__title">Full discussion</div>
            <div className="detail-box__body">{review.full_discussion || '—'}</div>
          </div>
          <div className="detail-box">
            <div className="detail-box__title">Doc updates suggested</div>
            <div className="detail-box__body detail-box__body--tight">{review.doc_updates_suggested || '—'}</div>
          </div>
          <div className="detail-box">
            <div className="detail-box__title">Review meta</div>
            <div className="detail-box__body detail-box__body--tight">
              <strong>Reviewed at:</strong> {review.reviewed_at ? new Date(review.reviewed_at).toLocaleString() : '—'}
              <br />
              <strong>Row updated:</strong> {new Date(review.updated_at).toLocaleString()}
            </div>
          </div>
        </>
      )}

      {review && tasks.length > 0 && (
        <>
          <h2 style={{ fontSize: '0.9rem', marginTop: '1rem' }}>CTASKs for this team</h2>
          <div className="detail-box">
            <div className="detail-box__title">Tasks linked to this review</div>
            <div className="detail-box__body" style={{ padding: 0 }}>
              <table className="ctask-table">
                <thead>
                  <tr>
                    <th>#</th>
                    <th>CTASK</th>
                    <th>Status</th>
                    <th>Motive</th>
                    <th>Task</th>
                  </tr>
                </thead>
                <tbody>
                  {tasks.map((t, i) => (
                    <tr key={t.id}>
                      <td>{i + 1}</td>
                      <td>
                        <Link to={`/changes/${id}/ctask/${t.id}`}>
                          <strong>{t.ctask_number}</strong>
                        </Link>
                      </td>
                      <td>
                        <span className="status-pill">{t.status}</span>
                      </td>
                      <td style={{ fontSize: '0.72rem' }}>{t.motive || '—'}</td>
                      <td style={{ fontSize: '0.72rem' }} title={t.task ?? undefined}>
                        {previewTaskText(t.task)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {tasks.some((t) => t.status_remark) && (
                <div style={{ padding: '0.4rem 0.6rem', fontSize: '0.72rem', borderTop: '1px solid #eee' }}>
                  {tasks
                    .filter((t) => t.status_remark)
                    .map((t) => (
                      <div key={t.id}>
                        <strong>{t.ctask_number}:</strong> {t.status_remark}
                      </div>
                    ))}
                </div>
              )}
            </div>
          </div>
        </>
      )}
    </div>
  );
}
