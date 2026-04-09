import { useEffect, useMemo, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import type { ChangeReviewRow, ChangeStatus, ChangeType } from '../lib/types';
import { APP_FEATURE_NAMES } from '../data/appFeatures';
import { FeatureMultiSelect } from '../components/FeatureMultiSelect';
import { cascadeCancelUnderChange, pushChangeTransition } from '../lib/changeHistory';
import {
  canNewToRollbackOrCancel,
  canSetChangeClosed,
  canSetChangeStarted,
  changeStatusRequiresFinalNote,
  terminalChangeBlocksTransition,
} from '../lib/changeRules';
import { parseFeatureNames } from '../lib/parse';

const STATUSES: ChangeStatus[] = ['new', 'started', 'closed', 'cancelled', 'rollbacked', 'rejected'];
const TYPES: ChangeType[] = ['fix', 'add', 'remove', 'refactor', 'other'];

function primaryOptions(current: string | null): string[] {
  const cur = current?.trim();
  if (cur && !APP_FEATURE_NAMES.includes(cur)) {
    return [cur, ...APP_FEATURE_NAMES];
  }
  return [...APP_FEATURE_NAMES];
}

export function EditChangePage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [loadError, setLoadError] = useState<string | null>(null);
  const [loadingData, setLoadingData] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [changeIdDisplay, setChangeIdDisplay] = useState('');
  const [status, setStatus] = useState<ChangeStatus>('new');
  const [type, setType] = useState<ChangeType>('other');
  const [primaryFeature, setPrimaryFeature] = useState('');
  const [affectedFeatures, setAffectedFeatures] = useState<string[]>([]);
  const [shortDescription, setShortDescription] = useState('');
  const [description, setDescription] = useState('');
  const [rollbackPlan, setRollbackPlan] = useState('');
  const [discussedDetails, setDiscussedDetails] = useState('');
  const [baselineStatus, setBaselineStatus] = useState<ChangeStatus>('new');
  const [statusHistoryRaw, setStatusHistoryRaw] = useState<unknown>([]);
  const [statusRemarkEdit, setStatusRemarkEdit] = useState('');
  const [finalStateNoteEdit, setFinalStateNoteEdit] = useState('');
  const [reviewsForRules, setReviewsForRules] = useState<Pick<ChangeReviewRow, 'status'>[]>([]);

  useEffect(() => {
    if (!primaryFeature) return;
    setAffectedFeatures((prev) => prev.filter((f) => f !== primaryFeature));
  }, [primaryFeature]);

  useEffect(() => {
    if (!id) return;
    let cancelled = false;
    (async () => {
      setLoadingData(true);
      setLoadError(null);
      const { data, error: e } = await supabase.from('changes').select('*').eq('id', id).maybeSingle();
      if (cancelled) return;
      if (e || !data) {
        setLoadError(e?.message ?? 'Change not found');
        setLoadingData(false);
        return;
      }
      const { data: revRows } = await supabase.from('change_reviews').select('status').eq('change_id', id);
      if (!cancelled) setReviewsForRules((revRows ?? []) as Pick<ChangeReviewRow, 'status'>[]);

      setChangeIdDisplay(data.change_id);
      setStatus(data.status as ChangeStatus);
      setType(data.type as ChangeType);
      setPrimaryFeature(data.primary_feature?.trim() ?? '');
      setAffectedFeatures(parseFeatureNames(data.feature_names));
      setShortDescription(data.short_description ?? '');
      setDescription(data.description ?? '');
      setRollbackPlan(data.rollback_plan ?? '');
      setDiscussedDetails(data.discussed_details ?? '');
      setBaselineStatus(data.status as ChangeStatus);
      setStatusHistoryRaw(data.status_history ?? []);
      setStatusRemarkEdit('');
      setFinalStateNoteEdit((data as { final_state_note?: string | null }).final_state_note ?? '');
      setLoadingData(false);
    })();
    return () => {
      cancelled = true;
    };
  }, [id]);

  const primarySelectOptions = useMemo(() => primaryOptions(primaryFeature || null), [primaryFeature]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!id) return;
    setError(null);
    if (!shortDescription.trim()) {
      setError('Short title / summary is required.');
      return;
    }
    setSaving(true);
    try {
      if (status !== baselineStatus) {
        if (terminalChangeBlocksTransition(baselineStatus)) {
          setError('This change is already terminal; status cannot be edited here.');
          setSaving(false);
          return;
        }
        const rm = statusRemarkEdit.trim();
        if (!rm) {
          setError('Status remark is required when changing status.');
          setSaving(false);
          return;
        }
        const fsn = finalStateNoteEdit.trim();
        if (changeStatusRequiresFinalNote(status)) {
          if (!fsn) {
            setError('Final state note is required for closed, cancelled, rollbacked, and rejected.');
            setSaving(false);
            return;
          }
        }
        if (status === 'started' && !canSetChangeStarted(reviewsForRules)) {
          setError('Cannot set to started until every change review is approved.');
          setSaving(false);
          return;
        }
        if (status === 'closed' && !canSetChangeClosed(reviewsForRules)) {
          setError('Cannot close until every change review is approved.');
          setSaving(false);
          return;
        }
        if (
          baselineStatus === 'new' &&
          (status === 'rollbacked' || status === 'cancelled') &&
          !canNewToRollbackOrCancel(reviewsForRules)
        ) {
          setError('Cannot rollback or cancel from new while every review is already approved.');
          setSaving(false);
          return;
        }
        const history = pushChangeTransition(
          { status: baselineStatus, status_history: statusHistoryRaw },
          status,
          rm,
        );
        const { error: err } = await supabase
          .from('changes')
          .update({
            status,
            type,
            primary_feature: primaryFeature.trim() || null,
            feature_names: affectedFeatures,
            short_description: shortDescription.trim(),
            description,
            rollback_plan: rollbackPlan.trim() || null,
            discussed_details: discussedDetails.trim() || null,
            status_remark: rm,
            status_history: history,
            final_state_note: changeStatusRequiresFinalNote(status) ? fsn : null,
            closed_at: status === 'closed' ? new Date().toISOString() : null,
          })
          .eq('id', id);
        if (err) throw err;
        if (status === 'cancelled' || status === 'rejected') {
          await cascadeCancelUnderChange(id, rm);
        }
      } else {
        const { error: err } = await supabase
          .from('changes')
          .update({
            status,
            type,
            primary_feature: primaryFeature.trim() || null,
            feature_names: affectedFeatures,
            short_description: shortDescription.trim(),
            description,
            rollback_plan: rollbackPlan.trim() || null,
            discussed_details: discussedDetails.trim() || null,
          })
          .eq('id', id);
        if (err) throw err;
      }
      navigate(`/changes/${id}`);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Save failed');
    } finally {
      setSaving(false);
    }
  }

  if (loadingData) {
    return <p className="muted">Loading…</p>;
  }
  if (loadError) {
    return (
      <div>
        <p className="error">{loadError}</p>
        <Link to="/changes">← All changes</Link>
      </div>
    );
  }

  return (
    <div className="page-stack detail-page">
      <header className="page-header">
        <div>
          <h1>Edit change</h1>
          <p className="muted" style={{ marginBottom: 0, fontSize: '0.875rem' }}>
            Add primary feature, affected teams, rollback, and motive / technical notes. <code>change_id</code> is
            read-only.
          </p>
        </div>
      </header>
      <form className="card" onSubmit={submit}>
        <div className="field">
          <label>Change id</label>
          <input value={changeIdDisplay} disabled readOnly />
        </div>
        <div className="row">
          <div className="field" style={{ flex: 1, minWidth: 140 }}>
            <label htmlFor="est">Status</label>
            <select id="est" value={status} onChange={(e) => setStatus(e.target.value as ChangeStatus)}>
              {STATUSES.map((s) => (
                <option key={s} value={s}>
                  {s}
                </option>
              ))}
            </select>
          </div>
          <div className="field" style={{ flex: 1, minWidth: 140 }}>
            <label htmlFor="etp">Type</label>
            <select id="etp" value={type} onChange={(e) => setType(e.target.value as ChangeType)}>
              {TYPES.map((t) => (
                <option key={t} value={t}>
                  {t}
                </option>
              ))}
            </select>
          </div>
        </div>
        {status !== baselineStatus && (
          <>
            <div className="field">
              <label htmlFor="esrm">Status remark *</label>
              <textarea
                id="esrm"
                value={statusRemarkEdit}
                onChange={(e) => setStatusRemarkEdit(e.target.value)}
                rows={3}
                placeholder="Required when changing status — appears in status history on the change page"
                required
              />
            </div>
            {changeStatusRequiresFinalNote(status) && (
              <div className="field">
                <label htmlFor="efs">Final state note *</label>
                <textarea
                  id="efs"
                  value={finalStateNoteEdit}
                  onChange={(e) => setFinalStateNoteEdit(e.target.value)}
                  rows={4}
                  placeholder="Full detail for this terminal outcome"
                  required
                />
              </div>
            )}
          </>
        )}
        <div className="field">
          <label htmlFor="epf">Primary feature</label>
          <select id="epf" value={primaryFeature} onChange={(e) => setPrimaryFeature(e.target.value)}>
            <option value="">— Not set yet (add when scoped) —</option>
            {primarySelectOptions.map((name) => (
              <option key={name} value={name}>
                {name}
              </option>
            ))}
          </select>
        </div>
        <FeatureMultiSelect
          value={affectedFeatures}
          onChange={setAffectedFeatures}
          primaryFeature={primaryFeature}
          id="edit-affected-features"
        />
        <div className="field">
          <label htmlFor="ess">Short title / summary *</label>
          <input
            id="ess"
            value={shortDescription}
            onChange={(e) => setShortDescription(e.target.value)}
            required
            placeholder="Plain-language title"
          />
        </div>
        <div className="field">
          <label htmlFor="eds">Description</label>
          <textarea
            id="eds"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="What testers asked for; you can add technical detail here"
          />
        </div>
        <div className="field">
          <label htmlFor="erb">Rollback plan</label>
          <textarea
            id="erb"
            value={rollbackPlan}
            onChange={(e) => setRollbackPlan(e.target.value)}
            placeholder="How to revert if needed"
          />
        </div>
        <div className="field">
          <label htmlFor="edd">Motive &amp; discussed details</label>
          <textarea
            id="edd"
            value={discussedDetails}
            onChange={(e) => setDiscussedDetails(e.target.value)}
            placeholder="Why we’re doing this, CAB notes, technical motive — maps to discussed_details in DB"
          />
        </div>
        {error && <p className="error">{error}</p>}
        <div className="row" style={{ gap: '0.5rem' }}>
          <button type="submit" className="btn btn-primary" disabled={saving}>
            {saving ? 'Saving…' : 'Save changes'}
          </button>
          <Link to={`/changes/${id}`} className="btn">
            Cancel
          </Link>
        </div>
      </form>
    </div>
  );
}
