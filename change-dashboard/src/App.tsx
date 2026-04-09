import { useEffect, useMemo, useState } from 'react';
import { Navigate, NavLink, Outlet, Route, Routes, useLocation } from 'react-router-dom';
import type { Session } from '@supabase/supabase-js';
import { supabase, isSupabaseConfigured } from './lib/supabase';
import { LoginPage } from './pages/LoginPage';
import { HomePage } from './pages/HomePage';
import { ChangeListPage } from './pages/ChangeListPage';
import { NewChangePage } from './pages/NewChangePage';
import { ChangeDetailPage } from './pages/ChangeDetailPage';
import { EditChangePage } from './pages/EditChangePage';
import { ChangeReviewDetailPage } from './pages/ChangeReviewDetailPage';
import { CtaskDetailPage } from './pages/CtaskDetailPage';

function RequireAuth() {
  const [session, setSession] = useState<Session | null | undefined>(undefined);
  const location = useLocation();

  useEffect(() => {
    let mounted = true;
    supabase.auth.getSession().then(({ data }) => {
      if (mounted) setSession(data.session);
    });
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_e, s) => setSession(s));
    return () => {
      mounted = false;
      subscription.unsubscribe();
    };
  }, []);

  if (session === undefined) {
    return (
      <div className="auth-screen">
        <p className="muted">Loading…</p>
      </div>
    );
  }

  if (!session) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  return <Outlet />;
}

function topBarTitle(pathname: string): string {
  if (pathname === '/') return 'Overview';
  if (pathname === '/changes') return 'Changes';
  if (pathname === '/changes/new') return 'Raise change';
  if (pathname.includes('/edit')) return 'Edit change';
  if (pathname.includes('/review/')) return 'Approver review';
  if (pathname.includes('/ctask/')) return 'CTASK';
  if (pathname.startsWith('/changes/')) return 'Change detail';
  return 'Workspace';
}

function Layout() {
  const { pathname } = useLocation();
  const pageTitle = useMemo(() => topBarTitle(pathname), [pathname]);

  return (
    <div className="app-layout">
      <aside className="app-sidebar" aria-label="Main navigation">
        <div className="app-sidebar__head">
          <div className="app-sidebar__brand">Change control</div>
          <div className="app-sidebar__product">Operations</div>
        </div>
        <div className="app-sidebar__tag">Navigate</div>
        <nav className="app-sidebar__nav">
          <NavLink to="/" end className={({ isActive }) => 'app-sidebar__link' + (isActive ? ' app-sidebar__link--active' : '')}>
            Overview
          </NavLink>
          <NavLink
            to="/changes"
            end
            className={({ isActive }) => 'app-sidebar__link' + (isActive ? ' app-sidebar__link--active' : '')}
          >
            All changes
          </NavLink>
          <NavLink
            to="/changes/new"
            className={({ isActive }) => 'app-sidebar__link' + (isActive ? ' app-sidebar__link--active' : '')}
          >
            Raise change
          </NavLink>
        </nav>
        <div className="app-sidebar__foot">
          <button type="button" className="app-sidebar__signout" onClick={() => supabase.auth.signOut()}>
            Sign out
          </button>
        </div>
      </aside>
      <div className="app-body">
        <header className="app-topbar">
          <div className="app-topbar__left">
            <h1 className="app-topbar__title">{pageTitle}</h1>
            <span className="app-topbar__path" title={pathname}>
              {pathname}
            </span>
          </div>
        </header>
        <main className="app-main">
          <Outlet />
        </main>
      </div>
    </div>
  );
}

function MissingEnvScreen() {
  return (
    <div className="auth-screen">
      <div className="page-stack" style={{ maxWidth: 520 }}>
        <h1>Configuration needed</h1>
      <div className="card">
        <p>
          Create <code>change-dashboard/.env</code> with:
        </p>
        <pre style={{ fontSize: '0.8rem', overflow: 'auto' }}>
          {`VITE_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
VITE_SUPABASE_ANON_KEY=your_anon_key`}
        </pre>
        <p className="muted">
          Copy from your Flutter <code>.env</code> as <code>SUPABASE_URL</code> → <code>VITE_SUPABASE_URL</code> and{' '}
          <code>SUPABASE_ANON_KEY</code> → <code>VITE_SUPABASE_ANON_KEY</code>. Then stop the dev server and run{' '}
          <code>npm run dev</code> again (Vite reads env only at startup).
        </p>
      </div>
      </div>
    </div>
  );
}

export default function App() {
  if (!isSupabaseConfigured) {
    return <MissingEnvScreen />;
  }

  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route element={<RequireAuth />}>
        <Route element={<Layout />}>
          <Route index element={<HomePage />} />
          <Route path="changes/new" element={<NewChangePage />} />
          <Route path="changes/:id/edit" element={<EditChangePage />} />
          <Route path="changes/:id/review/:teamKey" element={<ChangeReviewDetailPage />} />
          <Route path="changes/:id/ctask/:taskId" element={<CtaskDetailPage />} />
          <Route path="changes/:id" element={<ChangeDetailPage />} />
          <Route path="changes" element={<ChangeListPage />} />
        </Route>
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
