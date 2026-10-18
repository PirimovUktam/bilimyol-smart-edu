import type { Session } from '@supabase/supabase-js';
import { isSupabaseConfigured } from '@/core/config/supabase';

export const isLocalDemoAllowed = (configured: boolean, production: boolean): boolean =>
  !configured && !production;

export const isProtectedAuthReady = (
  configured: boolean,
  production: boolean,
  session: Session | null,
  profile: { id: string } | null,
): boolean => {
  const sessionMatchesProfile = Boolean(session?.user?.id && profile?.id === session.user.id);
  return Boolean(profile) && (sessionMatchesProfile || isLocalDemoAllowed(configured, production));
};

export const canUseLocalDemoMode = (): boolean =>
  isLocalDemoAllowed(isSupabaseConfigured, import.meta.env.PROD);
