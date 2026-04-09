import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import type { ChangeRow } from '../lib/types';
import { parseDiscussionLog, parseFeatureNames } from '../lib/parse';

export function ChangeListPage() {
  const [rows, setRows] = useState<ChangeRow[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setLoading(true);
      const { data, error: err } = await supabase
        .from('changes')
        .select('*')
        .order('created_at', { ascending: false });
      if (cancelled) return;
      if (err) {
        setError(err.message);
        setRows([]);
      } else {
        setError(null);
        setRows(
          (data ?? []).map((r) => ({
            ...r,
            feature_names: parseFeatureNames(r.feature_names),
            status_history: r.status_history,
            discussion_log: parseDiscussionLog(r.discussion_log),
          })) as ChangeRow[]
        );
      }
      setLoading(false);
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  if (loading) return <p className="muted page-stack">Loading changes…</p>;

  return (
    <div className="page-stack">
      <header className="page-header">
        <div>
          <h1>Changes</h1>
          <p className="muted">All registered changes — open a row for full detail, reviews, and CTASKs.</p>
        </div>
      </header>
      {error && <p className="error">{error}</p>}
      {!error && rows.length === 0 && <p className="muted">No changes yet. Raise one from the sidebar.</p>}
      {rows.length > 0 && (
        <div className="data-table-wrap">
          <table>
            <thead>
              <tr>
                <th>ID</th>
                <th>Status</th>
                <th>Type</th>
                <th>Summary</th>
                <th>Created</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((c) => (
                <tr key={c.id}>
                  <td>
                    <Link to={`/changes/${c.id}`}>
                      <strong>{c.change_id}</strong>
                    </Link>
                  </td>
                  <td>
                    <span className="badge">{c.status}</span>
                  </td>
                  <td>{c.type}</td>
                  <td className="table-cell-wrap">{c.short_description || '—'}</td>
                  <td className="muted">{new Date(c.created_at).toLocaleString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
