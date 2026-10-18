import { describe, expect, it } from 'vitest';
import { isLocalDemoAllowed, isProtectedAuthReady } from '../core/utils/authGuards';

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
  it('does not treat a cached demo profile without a Supabase session as auth', () => {
    const authReady = isProtectedAuthReady(true, true, null, demoProfile);

    expect(authReady).toBe(false);
    expect(resolveProtectedRoute('dashboard', authReady)).toBe('login');
    // AppRouter uses the same readiness gate before starting protected loads.
    expect(authReady).toBe(false);
    expect(isProtectedAuthReady(true, true, { user: { id: 'different-user' } } as never, demoProfile)).toBe(false);
  });

  it('allows a real authenticated profile in a configured environment', () => {
    const session = { user: { id: 'auth-user' } } as never;

    expect(isProtectedAuthReady(true, true, session, {
      ...demoProfile,
      id: 'auth-user',
      email: 'student@example.uz',
    })).toBe(true);
  });

  it('preserves local demo mode when Supabase is not configured outside production', () => {
    expect(isLocalDemoAllowed(false, false)).toBe(true);
    expect(isProtectedAuthReady(false, false, null, demoProfile)).toBe(true);
    expect(isLocalDemoAllowed(false, true)).toBe(false);
    expect(isProtectedAuthReady(false, true, null, demoProfile)).toBe(false);
  });
});
