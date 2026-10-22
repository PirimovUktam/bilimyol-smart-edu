import { createClient, SupabaseClient } from '@supabase/supabase-js';

export const isProduction = import.meta.env.PROD;
export const rawSupabaseUrl = import.meta.env.VITE_SUPABASE_URL || '';
export const rawSupabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY || '';

// Only trust well-formed Supabase URLs. A malformed or non-Supabase URL must
// never silently connect the app to an unexpected project.
export function isValidSupabaseUrl(url: string): boolean {
  return /^https:\/\/[a-z0-9][a-z0-9-]*\.supabase\.co\/?$/i.test(url.trim());
}

export const isSupabaseConfigured = Boolean(
  rawSupabaseUrl && rawSupabaseKey && isValidSupabaseUrl(rawSupabaseUrl),
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
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
});

