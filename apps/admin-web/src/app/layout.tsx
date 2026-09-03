import type { ReactNode } from 'react';
import { Instrument_Serif, Karla } from 'next/font/google';

import '../styles/globals.css';

// next/font/google self-hosts these at build time (no runtime calls to
// Google Fonts). Building this scaffold had no network access, so this
// is written correctly but unverified — run `npm run build` once to
// confirm the fonts download and the CSS variables below apply.
const instrumentSerif = Instrument_Serif({
  subsets: ['latin'],
  weight: ['400'],
  style: ['normal', 'italic'],
  variable: '--pg-font-serif-loaded',
  display: 'swap',
});

const karla = Karla({
  subsets: ['latin'],
  weight: ['300', '400', '500', '600', '700', '800'],
  variable: '--pg-font-sans-loaded',
  display: 'swap',
});

export const metadata = {
  title: 'Pro_Grafiz Admin',
  description: 'Pro_Grafiz staff administration (foundation build).',
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" className={`${instrumentSerif.variable} ${karla.variable}`}>
      <body>{children}</body>
    </html>
  );
}
