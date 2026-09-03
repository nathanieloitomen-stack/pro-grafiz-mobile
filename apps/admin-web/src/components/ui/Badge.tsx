import styles from './Badge.module.css';

export type PGBadgeTone = 'success' | 'warning' | 'danger' | 'auto' | 'neutral';

interface PGBadgeProps {
  label: string;
  tone?: PGBadgeTone;
}

/**
 * Status tag — e.g. MATCHED / NO MATCH / CONFIRMED, AUTO-DRAFT, over-SLA.
 * Display only; the tone→state mapping stays in feature code, this
 * component just renders whichever tone it's given.
 */
export function PGBadge({ label, tone = 'neutral' }: PGBadgeProps): JSX.Element {
  return <span className={[styles.tag, styles[tone]].join(' ')}>{label}</span>;
}
