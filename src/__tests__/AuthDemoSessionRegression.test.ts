import { describe, expect, it } from 'vitest';
import { canUseHostedDemoMode, isLocalDemoAllowed, isProtectedAuthReady } from '../core/utils/authGuards';

const demoProfile = {
  id: 'guest_user_01',
  firstName: 'Foydalanuvchi',
  lastName: '',
  email: 'guest@bilimyol.uz',
  role: 'student' as const,
};

const resolveProtectedRoute = (requestedView: string, authReady: boolean): string => {
  const publicViews = ['pitch', 'demo', 'login', 'register', 'forgot-password'];
  return !authReady && !publicViews.includes(requestedView) ? 'login' : requestedView;
};

describe('configured Supabase demo-session regression', () => {
  it('does not treat an unmarked cached profile without a Supabase session as auth', () => {
    const authReady = isProtectedAuthReady(true, true, null, demoProfile, false);

    expect(authReady).toBe(false);
    expect(resolveProtectedRoute('dashboard', authReady)).toBe('login');
    // AppRouter uses the same readiness gate before starting protected loads.
    expect(authReady).toBe(false);
    expect(isProtectedAuthReady(true, true, { user: { id: 'different-user' } } as never, demoProfile, false)).toBe(false);
  });

  it('allows the explicit hosted demo through the local data plane without a Supabase session', () => {
    expect(canUseHostedDemoMode()).toBe(true);
    expect(isProtectedAuthReady(true, true, null, demoProfile, true)).toBe(true);
    expect(resolveProtectedRoute('dashboard', isProtectedAuthReady(true, true, null, demoProfile, true))).toBe('dashboard');
  });

  it('allows a real authenticated profile in a configured environment', () => {
    const session = { user: { id: 'auth-user' } } as never;

    expect(isProtectedAuthReady(true, true, session, {
      ...demoProfile,
      id: 'auth-user',
      email: 'student@example.uz',
    }, false)).toBe(true);
  });

  it('preserves local demo mode when Supabase is not configured outside production', () => {
    expect(isLocalDemoAllowed(false, false)).toBe(true);
    expect(isProtectedAuthReady(false, false, null, demoProfile, false)).toBe(true);
    expect(isLocalDemoAllowed(false, true)).toBe(false);
    expect(isProtectedAuthReady(false, true, null, demoProfile, false)).toBe(false);
  });
});
