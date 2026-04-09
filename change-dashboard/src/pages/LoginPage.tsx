import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { DASHBOARD_ADMIN_EMAIL, DASHBOARD_ADMIN_PASSWORD } from '../config/dashboardAuth';

export function LoginPage() {
  const navigate = useNavigate();
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function signIn() {
    setError(null);
    setLoading(true);
    try {
      const { error: err } = await supabase.auth.signInWithPassword({
        email: DASHBOARD_ADMIN_EMAIL,
        password: DASHBOARD_ADMIN_PASSWORD,
      });
      if (err) throw err;
      navigate('/', { replace: true });
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Sign in failed');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="auth-screen">
      <div>
        <h1>Change control</h1>
        <p className="muted" style={{ marginBottom: '1.25rem', textAlign: 'center' }}>
          Sign in as admin (fixed account). Create the user once in Supabase if it does not exist — see README.
        </p>
        <div className="card">
          <button type="button" className="btn btn-primary" style={{ width: '100%' }} onClick={() => void signIn()} disabled={loading}>
            {loading ? 'Signing in…' : 'Sign in'}
          </button>
          {error && <p className="error" style={{ marginTop: '0.75rem' }}>{error}</p>}
        </div>
      </div>
    </div>
  );
}
