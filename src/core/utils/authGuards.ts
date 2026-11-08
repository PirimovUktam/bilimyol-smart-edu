import type { Session } from '@supabase/supabase-js';

export const isProtectedAuthReady = (
  session: Session | null,
  profile: { id: string } | null,
  demoMode = false,
): boolean => {
  const sessionMatchesProfile = Boolean(session?.user?.id && profile?.id === session.user.id);
  return Boolean(profile) && (demoMode || sessionMatchesProfile);
};
