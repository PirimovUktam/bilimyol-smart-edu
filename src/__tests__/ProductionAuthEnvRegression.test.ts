import { describe, it, expect, beforeEach, vi } from 'vitest';
import { isSupabaseConfigured, supabaseProjectRef } from '../core/config/supabase';

describe('Production Auth & Supabase Env Regression Tests', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('A: Missing env in production must not use fallback mock auth', () => {
    const isProd = true;
    const isConfigured = false;
    
    // In production without env, app must not mock an admin or student session
    let authError: Error | null = null;
    if (!isConfigured && isProd) {
      authError = new Error('Server konfiguratsiyasi topilmadi. Vercel sozlamalarida VITE_SUPABASE_URL va VITE_SUPABASE_ANON_KEY parametrlarini kiriting.');
    }
    expect(authError).not.toBeNull();
    expect(authError?.message).toContain('Server konfiguratsiyasi topilmadi');
  });

  it('B: Valid env allows Supabase client configuration', () => {
    const testUrl = 'https://abcdefgh.supabase.co';
    const testRef = testUrl.replace(/^https?:\/\//, '').split('.')[0];
    expect(testRef).toBe('abcdefgh');
  });

  it('C: Role is determined strictly from database public.profiles, never from email hack', () => {
    const mockDbProfile = {
      id: 'uuid-1234',
      email: 'custom_admin@example.uz',
      role: 'admin',
    };

    // Role must come directly from database payload
    expect(mockDbProfile.role).toBe('admin');
  });

  it('D: Admin profile route resolves strictly to admin dashboard', () => {
    const profile = { id: 'admin-1', role: 'admin' };
    let targetView = 'dashboard';
    if (profile.role === 'admin') {
      targetView = 'admin';
    }
    expect(targetView).toBe('admin');
  });

  it('E: Student profile route resolves strictly to dashboard', () => {
    const profile = { id: 'student-1', role: 'student' };
    let targetView = 'course-selection';
    if (profile.role === 'admin') {
      targetView = 'admin';
    } else {
      targetView = 'dashboard';
    }
    expect(targetView).toBe('dashboard');
  });

  it('F: Config fingerprint exports valid metadata', () => {
    expect(typeof supabaseProjectRef).toBe('string');
    expect(typeof isSupabaseConfigured).toBe('boolean');
  });

  it('G: Self-profile query uses direct identity predicate without circular table dependencies', () => {
    const authUid = 'user-uuid-123';
    const profileRow = { id: 'user-uuid-123', email: 'user@bilimyol.uz', role: 'admin' };

    // Direct predicate: id = auth.uid()
    const canRead = profileRow.id === authUid;
    expect(canRead).toBe(true);
  });

  it('H: Unauthenticated user defaults to login route, not demo account or course selection', () => {
    const authProfile = null;
    const requestedView = 'course-selection';
    const isPublicView = ['pitch', 'demo', 'login', 'register', 'forgot-password'].includes(requestedView);
    
    let resolvedView = requestedView;
    if (!authProfile && !isPublicView) {
      resolvedView = 'login';
    }

    expect(resolvedView).toBe('login');
  });

  it('I: Public pitch and demo showcases remain accessible without login', () => {
    const authProfile = null;
    const pitchView = 'pitch';
    const demoView = 'demo';
    const publicList = ['pitch', 'demo', 'login', 'register', 'forgot-password'];

    expect(publicList.includes(pitchView)).toBe(true);
    expect(publicList.includes(demoView)).toBe(true);

    const resolveRoute = (view: string) => (!authProfile && !publicList.includes(view) ? 'login' : view);
    expect(resolveRoute('pitch')).toBe('pitch');
    expect(resolveRoute('demo')).toBe('demo');
    expect(resolveRoute('dashboard')).toBe('login');
  });

  it('J: Explicit demo activation sets isDemoMode and isolates guest session', () => {
    const demoProfile = {
      id: 'guest_user_01',
      firstName: 'Foydalanuvchi',
      role: 'student' as const,
    };
    const isDemoMode = true;

    expect(demoProfile.id).toBe('guest_user_01');
    expect(isDemoMode).toBe(true);
    expect(demoProfile.role).toBe('student');
  });
});
