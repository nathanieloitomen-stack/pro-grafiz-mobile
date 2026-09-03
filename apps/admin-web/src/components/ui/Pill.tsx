import type { ButtonHTMLAttributes } from 'react';

import styles from './Pill.module.css';

interface PGPillProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  label: string;
  selected?: boolean;
}

/**
 * Filter/category/branch-scope chip. Selection state is controlled by
 * the caller (this component has no internal state), matching the
 * branch-chip and category-chip patterns used throughout the approved
 * staff and customer surfaces.
 */
export function PGPill({ label, selected = false, className, ...props }: PGPillProps): JSX.Element {
  return (
    <button
      type="button"
      className={[styles.pill, selected ? styles.selected : '', className].filter(Boolean).join(' ')}
      {...props}
    >
      {label}
    </button>
  );
}
