import { useCallback, useEffect, useMemo, useState } from 'react';
import { APP_FEATURE_NAMES } from '../data/appFeatures';

type Props = {
  /** Selected feature / team names (order follows catalog). */
  value: string[];
  onChange: (next: string[]) => void;
  /** Excluded from lists (same as primary — implied). */
  primaryFeature?: string;
  id?: string;
};

function orderByCatalog(names: Set<string>): string[] {
  return APP_FEATURE_NAMES.filter((n) => names.has(n));
}

/**
 * Dual-list picker: check teams on the left, → moves to selected (right), ← removes.
 * Save commits to the parent (form still uses its own submit for the full record).
 */
export function FeatureMultiSelect({ value, onChange, primaryFeature = '', id = 'affected-features' }: Props) {
  const [draft, setDraft] = useState<string[]>(() => [...value]);
  const [checkedLeft, setCheckedLeft] = useState<Set<string>>(() => new Set());
  const [checkedRight, setCheckedRight] = useState<Set<string>>(() => new Set());
  const [savedHint, setSavedHint] = useState(false);

  const primary = primaryFeature.trim();

  useEffect(() => {
    setDraft(orderByCatalog(new Set(value.filter((x) => x !== primary))));
  }, [value, primary]);

  const draftSet = useMemo(() => new Set(draft), [draft]);

  const available = useMemo(() => {
    return APP_FEATURE_NAMES.filter((name) => name !== primary && !draftSet.has(name));
  }, [primary, draftSet]);

  const toggleLeft = useCallback((name: string) => {
    setCheckedLeft((prev) => {
      const next = new Set(prev);
      if (next.has(name)) next.delete(name);
      else next.add(name);
      return next;
    });
  }, []);

  const toggleRight = useCallback((name: string) => {
    setCheckedRight((prev) => {
      const next = new Set(prev);
      if (next.has(name)) next.delete(name);
      else next.add(name);
      return next;
    });
  }, []);

  const moveToSelected = useCallback(() => {
    const toAdd = available.filter((n) => checkedLeft.has(n));
    if (toAdd.length === 0) return;
    const next = new Set(draft);
    toAdd.forEach((n) => next.add(n));
    const ordered = orderByCatalog(next);
    setDraft(ordered);
    onChange(ordered);
    setCheckedLeft(new Set());
  }, [available, checkedLeft, draft, onChange]);

  const moveToAvailable = useCallback(() => {
    if (checkedRight.size === 0) return;
    const next = draft.filter((n) => !checkedRight.has(n));
    setDraft(next);
    onChange(next);
    setCheckedRight(new Set());
  }, [checkedRight, draft, onChange]);

  const handleSave = useCallback(() => {
    onChange(draft);
    setSavedHint(true);
    window.setTimeout(() => setSavedHint(false), 2000);
  }, [draft, onChange]);

  const labelId = `${id}-label`;

  return (
    <div className="field feature-transfer-field">
      <span id={labelId} className="feature-transfer-field__label">
        Affected teams / features
      </span>
      <p className="muted feature-transfer-field__hint">
        Tick teams on the left, <strong>→</strong> moves them to <strong>Selected</strong> (saved to the form immediately).{' '}
        <strong>←</strong> moves checked items back. <strong>Save selection</strong> confirms and shows a brief “Saved”
        hint. Primary feature stays excluded.
      </p>
      <div className="feature-transfer" role="group" aria-labelledby={labelId}>
        <div className="feature-transfer__panel">
          <div className="feature-transfer__panel-title">All teams</div>
          <div className="feature-transfer__list" role="list">
            {available.length === 0 ? (
              <span className="muted feature-transfer__empty">Nothing left to add</span>
            ) : (
              available.map((name) => (
                <label key={name} className="feature-transfer__row">
                  <input
                    type="checkbox"
                    className="feature-transfer__checkbox"
                    checked={checkedLeft.has(name)}
                    onChange={() => toggleLeft(name)}
                  />
                  <span className="feature-transfer__name">{name}</span>
                </label>
              ))
            )}
          </div>
        </div>

        <div className="feature-transfer__mid">
          <button
            type="button"
            className="btn feature-transfer__arrow"
            onClick={moveToSelected}
            disabled={!available.some((n) => checkedLeft.has(n))}
            aria-label="Move checked into selected"
            title="Add checked to selected"
          >
            →
          </button>
          <button
            type="button"
            className="btn feature-transfer__arrow"
            onClick={moveToAvailable}
            disabled={checkedRight.size === 0}
            aria-label="Remove checked from selected"
            title="Remove checked from selected"
          >
            ←
          </button>
          <button type="button" className="btn btn-primary feature-transfer__save" onClick={handleSave}>
            Save selection
          </button>
          {savedHint && <span className="feature-transfer__saved">Saved</span>}
        </div>

        <div className="feature-transfer__panel">
          <div className="feature-transfer__panel-title">Selected</div>
          <div className="feature-transfer__list" role="list">
            {draft.length === 0 ? (
              <span className="muted feature-transfer__empty">None selected yet</span>
            ) : (
              draft.map((name) => (
                <label key={name} className="feature-transfer__row">
                  <input
                    type="checkbox"
                    className="feature-transfer__checkbox"
                    checked={checkedRight.has(name)}
                    onChange={() => toggleRight(name)}
                  />
                  <span className="feature-transfer__name">{name}</span>
                </label>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
