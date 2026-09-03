import type { ButtonHTMLAttributes, ReactNode } from 'react';

import styles from './Button.module.css';

interface PGButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary';
  children: ReactNode;
}

/**
 * Primary/secondary button matching the approved design tokens: ember
 * pill with press-scale feedback for primary actions, ink/hairline
 * outline for secondary actions. Purely presentational — no
 * form-submission or business logic here.
 */
export function PGButton({ variant = 'primary', className, children, ...props }: PGButtonProps): JSX.Element {
  const variantClass = variant === 'primary' ? styles.primary : styles.secondary;
  return (
    <button className={[styles.button, variantClass, className].filter(Boolean).join(' ')} {...props}>
      {children}
    </button>
  );
}
