import { createClient, SupabaseClient } from '@supabase/supabase-js';

export const isProduction = import.meta.env.PROD;
export const rawSupabaseUrl = import.meta.env.VITE_SUPABASE_URL || '';
export const rawSupabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY || '';

export const isSupabaseConfigured = Boolean(rawSupabaseUrl && rawSupabaseKey);

const supabaseUrl = rawSupabaseUrl || 'https://bilimyol-demo.supabase.co';
const supabaseAnonKey = rawSupabaseKey || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.demo-anon-key';

export const supabaseProjectRef = rawSupabaseUrl
  ? rawSupabaseUrl.replace(/^https?:\/\//, '').split('.')[0]
  : 'not-configured';

export const buildFingerprint = {
  isProduction,
  isConfigured: isSupabaseConfigured,
  projectRef: supabaseProjectRef,
  buildTime: '2026-08-17T16:15:00Z',
};

if (typeof window !== 'undefined') {
  (window as unknown as { __BILIMYOL_CONFIG__: typeof buildFingerprint }).__BILIMYOL_CONFIG__ = buildFingerprint;
  console.log('[CONFIG] Supabase status:', {
    isProduction,
    isSupabaseConfigured,
    projectRef: supabaseProjectRef,
  });
}

export const supabase: SupabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
});

