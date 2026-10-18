import type { Session } from '@supabase/supabase-js';
import { isSupabaseConfigured } from '@/core/config/supabase';

export const isLocalDemoAllowed = (configured: boolean, production: boolean): boolean =>
  !configured && !production;

export const isProtectedAuthReady = (
  configured: boolean,
  production: boolean,
  session: Session | null,
  profile: { id: string } | null,
  demoMode = false,
): boolean => {
  const sessionMatchesProfile = Boolean(session?.user?.id && profile?.id === session.user.id);
  return Boolean(profile) && (demoMode || sessionMatchesProfile || isLocalDemoAllowed(configured, production));
};

export const canUseLocalDemoMode = (): boolean =>
  isLocalDemoAllowed(isSupabaseConfigured, import.meta.env.PROD);

// Hosted demo content is bundled and routed through the local data plane. It
// never needs a Supabase session or backend configuration.
export const canUseHostedDemoMode = (): boolean => true;
