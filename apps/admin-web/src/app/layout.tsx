import type { ReactNode } from 'react';

export const metadata = {
  title: 'Pro_Grafiz Admin',
  description: 'Pro_Grafiz staff administration (foundation build).',
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
