/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // No image domains, redirects, or env passthrough configured yet.
  // Add as later PG tasks require them (e.g. Supabase Storage signed
  // URL host once PG-003/PG-011 land) — do not add speculative config.
};

module.exports = nextConfig;
