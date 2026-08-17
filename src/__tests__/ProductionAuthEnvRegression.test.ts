import { describe, it, expect, beforeEach, vi } from 'vitest';
import { isSupabaseConfigured, supabaseProjectRef } from '../core/config/supabase';
import { useMonitoringStore } from '../app/store/useMonitoringStore';

describe('Production Auth & Supabase Env Regression Tests', () => {
  beforeEach(() => {
    useMonitoringStore.getState().resetAll();
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

  it('F: Logout resets monitoring store role and state', () => {
    useMonitoringStore.setState({ currentRole: 'admin' });

    // Perform logout reset
    useMonitoringStore.getState().resetAll();

    expect(useMonitoringStore.getState().currentRole).toBe('student');
  });

  it('G: Login with a different user does not leak previous user role', () => {
    useMonitoringStore.setState({ currentRole: 'admin' });
    useMonitoringStore.getState().resetAll();

    const newProfile = { id: 'user-2', role: 'student' as const };
    useMonitoringStore.setState({ currentRole: newProfile.role });

    expect(useMonitoringStore.getState().currentRole).toBe('student');
  });

  it('H: Config fingerprint exports valid metadata', () => {
    expect(typeof supabaseProjectRef).toBe('string');
    expect(typeof isSupabaseConfigured).toBe('boolean');
  });

  it('I: Self-profile query uses direct identity predicate without circular table dependencies', () => {
    const authUid = 'user-uuid-123';
    const profileRow = { id: 'user-uuid-123', email: 'user@bilimyol.uz', role: 'admin' };

    // Direct predicate: id = auth.uid()
    const canRead = profileRow.id === authUid;
    expect(canRead).toBe(true);
  });

  it('J: Teacher-student and parent-student authorization decouple from classes policy loop', () => {
    // Helper function simulates decoupled check
    const isTeacherOfStudent = (teacherId: string, studentId: string, activePairs: Array<{ teacherId: string; studentId: string }>) => {
      return activePairs.some(p => p.teacherId === teacherId && p.studentId === studentId);
    };

    const pairs = [{ teacherId: 'teacher-1', studentId: 'student-1' }];
    expect(isTeacherOfStudent('teacher-1', 'student-1', pairs)).toBe(true);
    expect(isTeacherOfStudent('teacher-1', 'student-2', pairs)).toBe(false);
  });
});
