import { useCallback, useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import type { ChangeStatus, ReviewStatus, TaskStatus } from '../lib/types';

type ChangeLite = { status: ChangeStatus };
type ReviewLite = { status: ReviewStatus };
type TaskLite = { status: TaskStatus };

function countBy<T extends string>(rows: { status: T }[], keys: readonly T[]): Record<T, number> {
  const init = {} as Record<T, number>;
  for (const k of keys) init[k] = 0;
  for (const r of rows) {
    if (keys.includes(r.status as T)) init[r.status as T] += 1;
  }
  return init;
}

const CHANGE_ORDER: ChangeStatus[] = ['new', 'started', 'closed', 'cancelled', 'rollbacked', 'rejected'];
const REVIEW_ORDER: ReviewStatus[] = ['new', 'open', 'implementing', 'rejected', 'approved', 'cancelled'];
const TASK_ORDER: TaskStatus[] = ['new', 'open', 'implementing', 'closed', 'rejected', 'skipped', 'cancelled'];

export function HomePage() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [changes, setChanges] = useState<ChangeLite[]>([]);
  const [reviews, setReviews] = useState<ReviewLite[]>([]);
  const [tasks, setTasks] = useState<TaskLite[]>([]);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const {
        data: { session },
        error: sessionErr,
      } = await supabase.auth.getSession();
      if (sessionErr) throw sessionErr;
      if (!session) {
        throw new Error(
          'No active session. Click Sign out, then sign in again. If this persists, check change-dashboard/.env (VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY) and restart npm run dev.'
        );
      }

      const [c, r, t] = await Promise.all([
        supabase.from('changes').select('status'),
        supabase.from('change_reviews').select('status'),
        supabase.from('change_tasks').select('status'),
      ]);
      if (c.error) throw c.error;
      if (r.error) throw r.error;
      if (t.error) throw t.error;
      setChanges((c.data ?? []) as ChangeLite[]);
      setReviews((r.data ?? []) as ReviewLite[]);
      setTasks((t.data ?? []) as TaskLite[]);
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : 'Could not load stats';
      const raw = String(e);
      const code = typeof e === 'object' && e !== null && 'code' in e ? String((e as { code?: string }).code) : '';
      const looks401 =
        raw.includes('401') ||
        msg.includes('JWT') ||
        msg.includes('Invalid API key') ||
        code === 'PGRST301' ||
        code === '42501';
      const hint = looks401
        ? ' — Fix: use anon key + same project URL in .env, restart `npm run dev`, sign in again; ensure migrations 008–010 are applied.'
        : '';
      setError(`${msg}${hint}`);
      setChanges([]);
      setReviews([]);
      setTasks([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const changeCounts = useMemo(() => countBy(changes, CHANGE_ORDER), [changes]);
  const reviewCounts = useMemo(() => countBy(reviews, REVIEW_ORDER), [reviews]);
  const taskCounts = useMemo(() => countBy(tasks, TASK_ORDER), [tasks]);

  const totalChanges = changes.length;
  const openChanges = changeCounts.new + changeCounts.started;
  const closedChanges = changeCounts.closed;
  const terminalChanges =
    changeCounts.cancelled + changeCounts.rollbacked + changeCounts.rejected;
  const totalTasks = tasks.length;
  const totalReviews = reviews.length;

  const maxChangeBar = Math.max(1, ...CHANGE_ORDER.map((k) => changeCounts[k]));
  const maxReviewBar = Math.max(1, ...REVIEW_ORDER.map((k) => reviewCounts[k]));
  const maxTaskBar = Math.max(1, ...TASK_ORDER.map((k) => taskCounts[k]));

  if (loading) {
    return (
      <div className="home-dashboard">
        <p className="muted">Loading overview…</p>
      </div>
    );
  }

  return (
    <div className="home-dashboard">
      <header className="home-dashboard__hero">
        <div>
          <h1 className="home-dashboard__title">Overview</h1>
          <p className="home-dashboard__subtitle">Changes, reviews, and CTASKs at a glance</p>
        </div>
        <Link to="/changes" className="btn btn-primary home-dashboard__cta">
          All changes
        </Link>
      </header>

      {error && <p className="error">{error}</p>}

      <section className="home-dashboard__section" aria-label="Summary">
        <div className="home-stat-grid">
          <article className="home-stat home-stat--accent">
            <span className="home-stat__label">Total changes</span>
            <span className="home-stat__value">{totalChanges}</span>
            <span className="home-stat__hint">Registered in the system</span>
          </article>
          <article className="home-stat home-stat--open">
            <span className="home-stat__label">Open / in progress</span>
            <span className="home-stat__value">{openChanges}</span>
            <span className="home-stat__hint">New + started</span>
          </article>
          <article className="home-stat home-stat--closed">
            <span className="home-stat__label">Closed</span>
            <span className="home-stat__value">{closedChanges}</span>
            <span className="home-stat__hint">Successfully completed</span>
          </article>
          <article className="home-stat home-stat--tasks">
            <span className="home-stat__label">CTASKs</span>
            <span className="home-stat__value">{totalTasks}</span>
            <span className="home-stat__hint">Across all teams</span>
          </article>
        </div>
      </section>

      <section className="home-dashboard__section" aria-label="Secondary totals">
        <div className="home-pill-row">
          <span className="home-pill">
            <strong>{totalReviews}</strong> change reviews
          </span>
          <span className="home-pill">
            <strong>{taskCounts.open + taskCounts.new}</strong> CTASKs open / new
          </span>
          <span className="home-pill home-pill--muted">
            <strong>{terminalChanges}</strong> terminal (cancelled + rollbacked + rejected)
          </span>
        </div>
      </section>

      <div className="home-dashboard__columns">
        <section className="home-panel" aria-labelledby="home-changes-heading">
          <h2 id="home-changes-heading" className="home-panel__title">
            Changes by status
          </h2>
          <ul className="home-bar-list">
            {CHANGE_ORDER.map((key) => (
              <li key={key} className="home-bar-item">
                <span className="home-bar-item__label">{key}</span>
                <div className="home-bar-item__track" role="presentation">
                  <div
                    className="home-bar-item__fill home-bar-item__fill--change"
                    style={{ width: `${(changeCounts[key] / maxChangeBar) * 100}%` }}
                  />
                </div>
                <span className="home-bar-item__n">{changeCounts[key]}</span>
              </li>
            ))}
          </ul>
        </section>

        <section className="home-panel" aria-labelledby="home-tasks-heading">
          <h2 id="home-tasks-heading" className="home-panel__title">
            CTASKs by status
          </h2>
          <ul className="home-bar-list">
            {TASK_ORDER.map((key) => (
              <li key={key} className="home-bar-item">
                <span className="home-bar-item__label">{key}</span>
                <div className="home-bar-item__track" role="presentation">
                  <div
                    className="home-bar-item__fill home-bar-item__fill--task"
                    style={{ width: `${(taskCounts[key] / maxTaskBar) * 100}%` }}
                  />
                </div>
                <span className="home-bar-item__n">{taskCounts[key]}</span>
              </li>
            ))}
          </ul>
        </section>

        <section className="home-panel home-panel--wide" aria-labelledby="home-reviews-heading">
          <h2 id="home-reviews-heading" className="home-panel__title">
            Change reviews by status
          </h2>
          <ul className="home-bar-list">
            {REVIEW_ORDER.map((key) => (
              <li key={key} className="home-bar-item">
                <span className="home-bar-item__label">{key}</span>
                <div className="home-bar-item__track" role="presentation">
                  <div
                    className="home-bar-item__fill home-bar-item__fill--review"
                    style={{ width: `${(reviewCounts[key] / maxReviewBar) * 100}%` }}
                  />
                </div>
                <span className="home-bar-item__n">{reviewCounts[key]}</span>
              </li>
            ))}
          </ul>
        </section>
      </div>
    </div>
  );
}
