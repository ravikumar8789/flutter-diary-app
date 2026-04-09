import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import type { ChangeType } from '../lib/types';
import { APP_FEATURE_NAMES } from '../data/appFeatures';
import { FeatureMultiSelect } from '../components/FeatureMultiSelect';

const TYPES: ChangeType[] = ['fix', 'add', 'remove', 'refactor', 'other'];

/** Every raised change is inserted as `new` (planning). Use Edit change to move to `started` when ready. */
const RAISE_CHANGE_STATUS = 'new' as const;

export function NewChangePage() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [changeIdOverride, setChangeIdOverride] = useState('');
  const [type, setType] = useState<ChangeType>('other');
  const [primaryFeature, setPrimaryFeature] = useState('');
  const [affectedFeatures, setAffectedFeatures] = useState<string[]>([]);
  const [shortDescription, setShortDescription] = useState('');
  const [description, setDescription] = useState('');
  const [rollbackPlan, setRollbackPlan] = useState('');
  const [discussedDetails, setDiscussedDetails] = useState('');

  useEffect(() => {
    if (!primaryFeature) return;
    setAffectedFeatures((prev) => prev.filter((f) => f !== primaryFeature));
  }, [primaryFeature]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const {
        data: { user },
      } = await supabase.auth.getUser();

      const payload: Record<string, unknown> = {
        status: RAISE_CHANGE_STATUS,
        type,
        primary_feature: primaryFeature.trim() || null,
        feature_names: affectedFeatures,
        short_description: shortDescription,
        description,
        rollback_plan: rollbackPlan || null,
        discussed_details: discussedDetails || null,
        created_by: user?.email ?? user?.id ?? null,
        status_history: [],
        final_state_note: null,
      };

      if (changeIdOverride.trim()) {
        payload.change_id = changeIdOverride.trim();
      }

      const { data, error: insErr } = await supabase.from('changes').insert(payload).select('id').single();
      if (insErr) throw insErr;
      if (data?.id) navigate(`/changes/${data.id}`);
      else navigate('/');
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Insert failed');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="page-stack">
      <header className="page-header">
        <div>
          <h1>Raise change</h1>
          <p className="muted" style={{ marginBottom: 0 }}>
            Simple submissions: title + description. New changes are created as <strong>new</strong> (planning). Use{' '}
            <strong>Edit change</strong> or the change detail page to set <code>started</code> when reviews are ready.
            Optional <code>change_id</code>, teams, rollback.
          </p>
        </div>
      </header>
      <form className="card" onSubmit={submit}>
        <div className="field">
          <label htmlFor="chg">Change id (optional)</label>
          <input
            id="chg"
            value={changeIdOverride}
            onChange={(e) => setChangeIdOverride(e.target.value)}
            placeholder="CHG0000042"
          />
        </div>
        <div className="field">
          <label htmlFor="tp">Type</label>
          <select id="tp" value={type} onChange={(e) => setType(e.target.value as ChangeType)}>
            {TYPES.map((t) => (
              <option key={t} value={t}>
                {t}
              </option>
            ))}
          </select>
        </div>
        <div className="field">
          <label htmlFor="pf">Primary feature</label>
          <select id="pf" value={primaryFeature} onChange={(e) => setPrimaryFeature(e.target.value)}>
            <option value="">— Not set (add in Edit later) —</option>
            {APP_FEATURE_NAMES.map((name) => (
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
          id="affected-features"
        />
        <div className="field">
          <label htmlFor="ss">Short description *</label>
          <input id="ss" value={shortDescription} onChange={(e) => setShortDescription(e.target.value)} required />
        </div>
        <div className="field">
          <label htmlFor="ds">Description *</label>
          <textarea id="ds" value={description} onChange={(e) => setDescription(e.target.value)} required />
        </div>
        <div className="field">
          <label htmlFor="rb">Rollback plan</label>
          <textarea id="rb" value={rollbackPlan} onChange={(e) => setRollbackPlan(e.target.value)} />
        </div>
        <div className="field">
          <label htmlFor="dd">Discussed details</label>
          <textarea id="dd" value={discussedDetails} onChange={(e) => setDiscussedDetails(e.target.value)} />
        </div>
        {error && <p className="error">{error}</p>}
        <button type="submit" className="btn btn-primary" disabled={loading}>
          {loading ? 'Saving…' : 'Create change'}
        </button>
      </form>
    </div>
  );
}
