import { createClient, SupabaseClient } from '@supabase/supabase-js';

export const isProduction = import.meta.env.PROD;
export const rawSupabaseUrl = import.meta.env.VITE_SUPABASE_URL || '';
export const rawSupabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY || '';

// Only trust well-formed Supabase URLs. A malformed or non-Supabase URL must
// never silently connect the app to an unexpected project.
export function isValidSupabaseUrl(url: string): boolean {
  return /^https:\/\/[a-z0-9][a-z0-9-]*\.supabase\.co\/?$/i.test(url.trim());
}

// Reject privileged service_role or sb_secret_* keys from ever initializing the
// client-side Supabase bundle.
export function isServiceRoleKey(rawKey: string): boolean {
  const trimmed = rawKey.trim();
  if (!trimmed) return false;
  if (/^sb_secret_/i.test(trimmed)) return true;
  if (/\bservice_role\b/i.test(trimmed)) return true;

  const parts = trimmed.split('.');
  if (parts.length !== 3) return false;

  try {
    const base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const padded = base64.padEnd(base64.length + ((4 - (base64.length % 4)) % 4), '=');
    const json =
      typeof atob === 'function'
        ? new TextDecoder().decode(Uint8Array.from(atob(padded), (ch) => ch.charCodeAt(0)))
        : Buffer.from(padded, 'base64').toString('utf8');
    const payload = JSON.parse(json) as { role?: unknown } | null;
    return typeof payload?.role === 'string' && payload.role.trim().toLowerCase() === 'service_role';
  } catch {
    return false;
  }
}

export const isSupabaseConfigured = Boolean(
  rawSupabaseKey &&
    !isServiceRoleKey(rawSupabaseKey) &&
    (isValidSupabaseUrl(rawSupabaseUrl) ||
      (import.meta.env.DEV && /^http:\/\/(?:127\.0\.0\.1|localhost):\d+\/?$/.test(rawSupabaseUrl))),
);

// Fail closed: when env is missing or malformed, do NOT silently fall back to a
// hardcoded production project — that would attach the app to real production
// data with a placeholder key. Use a clearly-invalid local URL so the client is
// inert and `isSupabaseConfigured` is false.
const FALLBACK_URL = 'https://invalid-not-configured.supabase.co';
const FALLBACK_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.mock-anon-key';

const supabaseUrl = isSupabaseConfigured ? rawSupabaseUrl : FALLBACK_URL;
const supabaseAnonKey = isSupabaseConfigured ? rawSupabaseKey : FALLBACK_KEY;

export const supabaseProjectRef = supabaseUrl.replace(/^https?:\/\//, '').split('.')[0];

export const buildFingerprint = {
  isProduction,
  isConfigured: isSupabaseConfigured,
  projectRef: supabaseProjectRef,
  buildTime: '2026-08-17T16:15:00Z',
};

if (typeof window !== 'undefined') {
  (window as unknown as { __BILIMYOL_CONFIG__: typeof buildFingerprint }).__BILIMYOL_CONFIG__ = buildFingerprint;
  if (import.meta.env.DEV) {
    console.debug('[CONFIG] Supabase status:', {
      isProduction,
      isSupabaseConfigured,
      projectRef: supabaseProjectRef,
    });
  }
}

export const supabase: SupabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    flowType: 'pkce',
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
});

