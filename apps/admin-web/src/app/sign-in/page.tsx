'use client';

import { useEffect, useState } from 'react';

import { createClient } from '@/lib/supabase/client';
import { PGButton } from '@/components/ui';

/**
 * Minimal staff sign-in for admin-web. No approved design exists for a
 * web admin sign-in screen — the design handoff is mobile-only, and its
 * one Sign-in screen (#11) is a bottom-sheet account-picker pattern that
 * doesn't translate directly to a desktop/keyboard-first surface. This
 * reuses the same backend as mobile (PIN-as-Supabase-Auth-password —
 * see supabase/migrations/20260904000013_staff_authentication.sql) with
 * a simpler two-field form instead of the mobile picker, styled with
 * PG-002 tokens. Revisit with the product owner/designer.
 *
 * UNTESTED: written without `npm install` or a live Supabase project in
 * this environment. Review before deploying.
 */
export default function SignInPage(): JSX.Element {
  const [identities, setIdentities] = useState<StaffIdentity[]>([]);
  const [selected, setSelected] = useState<StaffIdentity | null>(null);
  const [pin, setPin] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    const supabase = createClient();
    supabase.functions
      .invoke('staff-list-signin-identities')
      .then(({ data, error: fnError }) => {
        if (fnError) {
          setError('Could not load accounts.');
        } else {
          setIdentities((data as { identities: StaffIdentity[] }).identities);
        }
      })
      .finally(() => setLoading(false));
  }, []);

  async function submit() {
    if (!selected) return;
    if (pin.length !== 4) {
      setError('Enter your four-digit PIN.');
      return;
    }
    setSubmitting(true);
    setError(null);
    const supabase = createClient();
    const { error: signInError } = await supabase.auth.signInWithPassword({
      email: selected.auth_login_handle,
      password: pin,
    });
    setSubmitting(false);
    if (signInError) {
      setError('Incorrect PIN. Try again.');
      return;
    }
    window.location.href = '/';
  }

  return (
    <main style={{ padding: 24, maxWidth: 420, margin: '0 auto' }}>
      <h1>Pro_Grafiz Admin</h1>
      {!selected ? (
        <>
          <p style={{ color: 'var(--pg-text-soft)', fontSize: 'var(--pg-text-body)' }}>
            Pick your account.
          </p>
          {loading && <p>Loading…</p>}
          {error && <p style={{ color: 'var(--pg-danger-fg)' }}>{error}</p>}
          <ul style={{ listStyle: 'none', padding: 0, display: 'flex', flexDirection: 'column', gap: 4 }}>
            {identities.map((identity) => (
              <li key={identity.id}>
                <button
                  type="button"
                  onClick={() => setSelected(identity)}
                  style={{
                    width: '100%',
                    textAlign: 'left',
                    padding: '12px 14px',
                    border: '1px solid var(--pg-hairline)',
                    borderRadius: 12,
                    background: '#fff',
                  }}
                >
                  <strong>{identity.full_name}</strong>
                  <br />
                  <span style={{ fontSize: 'var(--pg-text-caption)', color: 'var(--pg-text-soft)' }}>
                    {identity.role.replace('_', ' ')}
                    {identity.branches?.name ? ` · ${identity.branches.name}` : ''}
                  </span>
                </button>
              </li>
            ))}
          </ul>
        </>
      ) : (
        <>
          <p>{selected.full_name}</p>
          <input
            type="password"
            inputMode="numeric"
            maxLength={4}
            value={pin}
            onChange={(e) => setPin(e.target.value)}
            placeholder="••••"
            style={{
              height: 48,
              width: '100%',
              borderRadius: 'var(--pg-radius-pill)',
              border: `1.5px solid ${error ? 'var(--pg-danger-fg)' : 'var(--pg-hairline)'}`,
              padding: '0 20px',
              fontSize: 18,
              letterSpacing: '0.4em',
              marginBottom: 8,
            }}
          />
          {error && <p style={{ color: 'var(--pg-danger-fg)', fontSize: 'var(--pg-text-caption)' }}>{error}</p>}
          <div style={{ display: 'flex', gap: 8 }}>
            <PGButton variant="secondary" onClick={() => { setSelected(null); setPin(''); setError(null); }}>
              Back
            </PGButton>
            <PGButton variant="primary" onClick={submit} disabled={submitting}>
              {submitting ? 'Signing in…' : 'Sign in'}
            </PGButton>
          </div>
        </>
      )}
    </main>
  );
}

interface StaffIdentity {
  id: string;
  full_name: string;
  role: string;
  auth_login_handle: string;
  initials: string | null;
  branches: { name: string } | null;
}
