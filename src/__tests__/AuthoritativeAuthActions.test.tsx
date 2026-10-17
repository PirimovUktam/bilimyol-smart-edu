import React from 'react';
import { renderToString } from 'react-dom/server';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { AuthProvider, useAuth } from '../core/context/AuthContext';

const backend = vi.hoisted(() => ({
  configured: true, query: vi.fn(), from: vi.fn(), signIn: vi.fn(), signUp: vi.fn(),
  signOut: vi.fn(), getUser: vi.fn(), role: vi.fn(), reset: vi.fn(),
}));
vi.mock('../core/config/supabase', () => ({
  get isSupabaseConfigured() { return backend.configured; },
  supabase: {
    from: backend.from,
    auth: { signInWithPassword: backend.signIn, signUp: backend.signUp, signOut: backend.signOut, getUser: backend.getUser },
  },
}));
vi.mock('../app/store/useMonitoringStore', () => ({
  useMonitoringStore: { setState: backend.role, getState: () => ({ resetAll: backend.reset }) },
}));

// Exercise the provider's real public auth actions without introducing a DOM
// dependency. SSR does not run its startup effect; browser lifecycle is a
// separate smoke-check concern, not coverage claimed by these action tests.
function actions() {
  let result!: ReturnType<typeof useAuth>;
  function Capture() { result = useAuth(); return null; }
  renderToString(<AuthProvider><Capture /></AuthProvider>);
  return result;
}
const user = { id: 'auth-user', email: 'auth@example.invalid', user_metadata: { role: 'admin', first_name: 'Forged' } };
const row = { id: user.id, email: user.email, first_name: 'Ali', last_name: 'Vali', avatar_url: '', role: 'student' };

beforeEach(() => {
  vi.resetAllMocks();
  backend.configured = true;
  const storage = new Map<string, string>();
  vi.stubGlobal('localStorage', {
    getItem: (key: string) => storage.get(key) ?? null,
    setItem: (key: string, value: string) => storage.set(key, value),
    removeItem: (key: string) => storage.delete(key),
  });
  backend.from.mockReturnValue({ select: () => ({ eq: () => ({ maybeSingle: backend.query }) }) });
  backend.signIn.mockResolvedValue({ data: { user, session: { user } }, error: null });
  backend.signOut.mockResolvedValue({ error: null });
  backend.getUser.mockResolvedValue({ data: { user }, error: null });
  backend.query.mockResolvedValue({ data: row, error: null });
  vi.spyOn(console, 'warn').mockImplementation(() => {});
});
afterEach(() => { vi.restoreAllMocks(); vi.unstubAllGlobals(); vi.unstubAllEnvs(); });

describe('authoritative configured authentication actions', () => {
  it('uses the database role, never signup metadata, after sign-in', async () => {
    const result = await actions().signIn(user.email, 'not-a-real-password');
    expect(result.error).toBeNull();
    expect(result.profile).toMatchObject({ id: user.id, firstName: 'Ali', role: 'student' });
    expect(JSON.parse(localStorage.getItem('bilimyol_auth_session')!).profile.role).toBe('student');
  });

  it.each([
    { data: null, error: null },
    { data: null, error: { message: 'permission denied' } },
    { data: { ...row, role: 'superadmin' }, error: null },
    { data: { ...row, id: 'different-account' }, error: null },
  ])('does not fabricate a role/profile when the authoritative read fails (%j)', async (response) => {
    backend.query.mockResolvedValueOnce(response);
    const result = await actions().signIn(user.email, 'not-a-real-password');
    expect(result.error).toBeInstanceOf(Error);
    expect(result.profile).toBeUndefined();
    expect(localStorage.getItem('bilimyol_auth_session')).toBeNull();
    expect(backend.role).not.toHaveBeenCalledWith({ currentRole: 'admin' });
  });

  it('does not query or cache a profile while email confirmation is pending', async () => {
    backend.signUp.mockResolvedValueOnce({ data: { user, session: null }, error: null });
    const result = await actions().signUp(user.email, 'not-a-real-password', 'Ali', 'Vali', 'admin');
    expect(result.error).toBeNull();
    expect(result.requiresEmailConfirmation).toBe(true);
    expect(backend.from).not.toHaveBeenCalled();
    expect(localStorage.getItem('bilimyol_auth_session')).toBeNull();
    expect(backend.role).not.toHaveBeenCalled();
  });

  it('reports unavailable authoritative provisioning instead of successful signed-in signup', async () => {
    backend.signUp.mockResolvedValueOnce({ data: { user, session: { user } }, error: null });
    backend.query.mockResolvedValueOnce({ data: null, error: null });
    const result = await actions().signUp(user.email, 'not-a-real-password', 'Ali', 'Vali');
    expect(result.error).toBeInstanceOf(Error);
    expect(localStorage.getItem('bilimyol_auth_session')).toBeNull();
  });

  it('discards an authoritative profile response after explicit sign-out', async () => {
    let resolve!: (value: unknown) => void;
    backend.query.mockReturnValueOnce(new Promise((done) => { resolve = done; }));
    const auth = actions();
    const login = auth.signIn(user.email, 'not-a-real-password');
    await vi.waitFor(() => expect(backend.query).toHaveBeenCalledOnce());
    await auth.signOut();
    resolve({ data: row, error: null });
    expect((await login).error).toBeInstanceOf(Error);
    expect(localStorage.getItem('bilimyol_auth_session')).toBeNull();
    expect(backend.reset).toHaveBeenCalledOnce();
  });

  it('turns a rejected auth transport into an actionable failure', async () => {
    backend.signIn.mockRejectedValueOnce(new Error('network offline'));
    const result = await actions().signIn(user.email, 'not-a-real-password');
    expect(result.error?.message).toContain('network offline');
    expect(localStorage.getItem('bilimyol_auth_session')).toBeNull();
  });

  it('does not create a mock signup session in production without Supabase configuration', async () => {
    backend.configured = false;
    vi.stubEnv('PROD', true);
    const result = await actions().signUp(user.email, 'not-a-real-password', 'Ali', 'Vali', 'admin');
    expect(result.error).toBeInstanceOf(Error);
    expect(localStorage.getItem('bilimyol_auth_session')).toBeNull();
    expect(backend.role).not.toHaveBeenCalled();
  });
});
