import { describe, expect, it } from 'vitest';
import { isProtectedAuthReady } from '../core/utils/authGuards';

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
    const authReady = isProtectedAuthReady(null, demoProfile);

    expect(authReady).toBe(false);
    expect(resolveProtectedRoute('dashboard', authReady)).toBe('login');
    // AppRouter uses the same readiness gate before starting protected loads.
    expect(authReady).toBe(false);
    expect(isProtectedAuthReady({ user: { id: 'different-user' } } as never, demoProfile)).toBe(false);
  });

  it('allows the explicit hosted demo through the local data plane without a Supabase session', () => {
    expect(isProtectedAuthReady(null, demoProfile, true)).toBe(true);
    expect(resolveProtectedRoute('dashboard', isProtectedAuthReady(null, demoProfile, true))).toBe('dashboard');
  });

  it('allows a real authenticated profile in a configured environment', () => {
    const session = { user: { id: 'auth-user' } } as never;

    expect(isProtectedAuthReady(session, {
      ...demoProfile,
      id: 'auth-user',
      email: 'student@example.uz',
    }, false)).toBe(true);
  });

  it('requires a profile even when the demo mode flag is set', () => {
    expect(isProtectedAuthReady(null, null, true)).toBe(false);
  });
});
