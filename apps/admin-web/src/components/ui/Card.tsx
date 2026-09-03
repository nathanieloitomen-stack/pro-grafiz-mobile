import type { HTMLAttributes, ReactNode } from 'react';

import styles from './Card.module.css';

interface PGCardProps extends HTMLAttributes<HTMLDivElement> {
  variant?: 'paper' | 'hero' | 'clay';
  children: ReactNode;
}

/**
 * Generic card surface: paper (default list/detail card), hero (dark
 * ink summary card), or clay (accent/CTA card). No content assumptions —
 * feature code supplies children.
 */
export function PGCard({ variant = 'paper', className, children, ...props }: PGCardProps): JSX.Element {
  const variantClass = styles[variant];
  return (
    <div className={[styles.card, variantClass, className].filter(Boolean).join(' ')} {...props}>
      {children}
    </div>
  );
}
