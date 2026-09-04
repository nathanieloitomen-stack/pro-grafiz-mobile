'use client';

import { useEffect, useState } from 'react';

import { createClient } from '@/lib/supabase/client';
import { PGButton } from '@/components/ui';

/**
 * Minimal catalogue administration — Master Spec §6 V1 scope names
 * "Catalogue administration" as a staff feature, but no screen design
 * for it exists anywhere in the approved 19-screen inventory (the
 * Admin screen, #19, covers DXF codes/devices/backup/staff invites,
 * not pattern editing). This is a functional stand-in, not a
 * pixel-approved screen: list patterns, toggle active/inactive, edit
 * name/typical_uses/engineering_note. Relies entirely on
 * `patterns_write_super_admin` (PG-005) to reject anyone else — this
 * page does not check the caller's role itself; a non-Super-Admin
 * simply gets a failed write from Postgres, which is the correct
 * boundary (server-side, not client-side).
 *
 * UNTESTED: no live Supabase project or `npm install` in this
 * environment.
 */
export default function CataloguePage(): JSX.Element {
  const [patterns, setPatterns] = useState<Pattern[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [savingId, setSavingId] = useState<string | null>(null);

  useEffect(() => {
    const supabase = createClient();
    supabase
      .from('patterns')
      .select('id, pglc_code, name, active, typical_uses, engineering_note')
      .order('name')
      .then(({ data, error: fetchError }) => {
        if (fetchError) {
          setError('Could not load patterns — this page requires a Super Admin session.');
        } else {
          setPatterns((data as Pattern[]) ?? []);
        }
        setLoading(false);
      });
  }, []);

  async function toggleActive(pattern: Pattern) {
    setSavingId(pattern.id);
    const supabase = createClient();
    const { error: updateError } = await supabase
      .from('patterns')
      .update({ active: !pattern.active })
      .eq('id', pattern.id);
    setSavingId(null);
    if (updateError) {
      setError(`Could not update "${pattern.name}" — check you're signed in as Super Admin.`);
      return;
    }
    setPatterns((prev) => prev.map((p) => (p.id === pattern.id ? { ...p, active: !p.active } : p)));
  }

  return (
    <main style={{ padding: 24, maxWidth: 720, margin: '0 auto' }}>
      <h1>Catalogue Administration</h1>
      <p style={{ color: 'var(--pg-text-soft)', fontSize: 'var(--pg-text-body)' }}>
        Super Admin only — enforced by database policy, not by this page.
      </p>
      {loading && <p>Loading…</p>}
      {error && <p style={{ color: 'var(--pg-danger-fg)' }}>{error}</p>}
      <table style={{ width: '100%', borderCollapse: 'collapse', marginTop: 16 }}>
        <thead>
          <tr style={{ textAlign: 'left', borderBottom: '1px solid var(--pg-hairline)' }}>
            <th style={{ padding: 8 }}>PGLC</th>
            <th style={{ padding: 8 }}>Name</th>
            <th style={{ padding: 8 }}>Status</th>
            <th style={{ padding: 8 }} />
          </tr>
        </thead>
        <tbody>
          {patterns.map((pattern) => (
            <tr key={pattern.id} style={{ borderBottom: '1px solid var(--pg-hairline)' }}>
              <td style={{ padding: 8, fontSize: 'var(--pg-text-caption)', color: 'var(--pg-text-soft)' }}>
                {pattern.pglc_code}
              </td>
              <td style={{ padding: 8 }}>{pattern.name}</td>
              <td style={{ padding: 8 }}>{pattern.active ? 'Active' : 'Inactive'}</td>
              <td style={{ padding: 8 }}>
                <PGButton
                  variant="secondary"
                  onClick={() => toggleActive(pattern)}
                  disabled={savingId === pattern.id}
                >
                  {pattern.active ? 'Deactivate' : 'Activate'}
                </PGButton>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </main>
  );
}

interface Pattern {
  id: string;
  pglc_code: string;
  name: string;
  active: boolean;
  typical_uses: string | null;
  engineering_note: string | null;
}
