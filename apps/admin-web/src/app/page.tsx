import { PGBadge, PGButton, PGCard, PGPill } from '@/components/ui';

// Temporary placeholder proving the design system renders — not a real
// admin screen. Replaced when staff-facing feature work starts.
export default function Home(): JSX.Element {
  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 20, maxWidth: 480 }}>
      <h1>Pro_Grafiz Admin</h1>
      <p style={{ color: 'var(--pg-text-soft)', fontSize: 'var(--pg-text-meta)' }}>
        Design system — PG-002
      </p>
      <div style={{ display: 'flex', gap: 8 }}>
        <PGPill label="All" selected />
        <PGPill label="Idu" />
        <PGBadge label="Matched" tone="success" />
        <PGBadge label="No match" tone="danger" />
      </div>
      <PGCard variant="hero">
        <h2>Deposit confirmed</h2>
      </PGCard>
      <PGButton variant="primary">Primary action</PGButton>
    </main>
  );
}
