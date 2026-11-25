import fs from 'node:fs';
import path from 'node:path';
import type { Session } from '@supabase/supabase-js';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

function makeJwt(payload: Record<string, unknown>): string {
  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
  return `${header}.${body}.sig`;
}

function makeSession(
  userId: string,
  email: string,
  amr: Array<{ method: string; timestamp: number }> | string[],
  iat = 1700000000,
): Session {
  return {
    access_token: makeJwt({ sub: userId, email, amr, iat }),
    refresh_token: `refresh-${userId}`,
    expires_in: 3600,
    token_type: 'bearer',
    user: {
      id: userId,
      email,
      app_metadata: {},
      user_metadata: {},
      aud: 'authenticated',
      created_at: new Date().toISOString(),
    } as Session['user'],
  };
}

function createMemoryStorage() {
  const map = new Map<string, string>();
  return {
    map,
    storage: {
      get length() {
        return map.size;
      },
      key: (index: number) => [...map.keys()][index] ?? null,
      getItem: (key: string) => map.get(key) ?? null,
      setItem: (key: string, value: string) => {
        map.set(key, String(value));
      },
      removeItem: (key: string) => {
        map.delete(key);
      },
      clear: () => {
        map.clear();
      },
    } as Storage,
  };
}

function createHookDispatcher() {
  const states: unknown[] = [];
  const refs: Array<{ current: unknown }> = [];
  const memos: Array<{ deps: unknown[]; value: unknown }> = [];
  const callbacks: Array<{ deps: unknown[]; fn: unknown }> = [];
  const effects: Array<{ deps?: unknown[]; cleanup?: (() => void) | void }> = [];
  const pendingEffects: Array<{ idx: number; fn: () => void | (() => void); deps?: unknown[] }> = [];
  let idx = 0;

  return {
    reset() {
      idx = 0;
    },
    useState<T>(init: T | (() => T)): [T, (next: T | ((prev: T) => T)) => void] {
      const slot = idx++;
      if (!(slot in states)) {
        states[slot] = typeof init === 'function' ? (init as () => T)() : init;
      }
      const setState = (next: T | ((prev: T) => T)) => {
        states[slot] = typeof next === 'function' ? (next as (prev: T) => T)(states[slot] as T) : next;
      };
      return [states[slot] as T, setState];
    },
    useRef<T>(init: T): { current: T } {
      const slot = idx++;
      if (!(slot in refs)) {
        refs[slot] = { current: init };
      }
      return refs[slot] as { current: T };
    },
    useMemo<T>(factory: () => T, deps: unknown[]): T {
      const slot = idx++;
      const prev = memos[slot];
      if (!prev || deps.length !== prev.deps.length || deps.some((d, k) => !Object.is(d, prev.deps[k]))) {
        memos[slot] = { deps: [...deps], value: factory() };
      }
      return memos[slot].value as T;
    },
    useCallback<T extends (...args: never[]) => unknown>(fn: T, deps: unknown[] = []): T {
      const slot = idx++;
      const prev = callbacks[slot];
      if (!prev || deps.length !== prev.deps.length || deps.some((d, k) => !Object.is(d, prev.deps[k]))) {
        callbacks[slot] = { deps: [...deps], fn };
      }
      return callbacks[slot].fn as T;
    },
    useSyncExternalStore<T>(_sub: unknown, getSnapshot: () => T): T {
      idx++;
      return getSnapshot();
    },
    useId() {
      return `w0b3-id-${idx++}`;
    },
    useEffect(fn: () => void | (() => void), deps?: unknown[]) {
      const slot = idx++;
      const prev = effects[slot];
      const changed =
        !prev ||
        !deps ||
        !prev.deps ||
        deps.length !== prev.deps.length ||
        deps.some((d, k) => !Object.is(d, prev.deps![k]));
      if (changed) {
        pendingEffects.push({ idx: slot, fn, deps: deps ? [...deps] : undefined });
      }
    },
    flushEffects() {
      while (pendingEffects.length > 0) {
        const next = pendingEffects.shift()!;
        const prevCleanup = effects[next.idx]?.cleanup;
        if (typeof prevCleanup === 'function') prevCleanup();
        const cleanup = next.fn();
        effects[next.idx] = { deps: next.deps, cleanup };
      }
    },
    unmount() {
      for (const eff of effects) {
        if (typeof eff?.cleanup === 'function') {
          eff.cleanup();
        }
      }
    },
  };
}

function withReactHookDispatcher<T>(
  reactMod: typeof import('react'),
  hooks: ReturnType<typeof createHookDispatcher>,
  render: () => T,
): T {
  const internals =
    (
      reactMod as unknown as {
        __CLIENT_INTERNALS_DO_NOT_USE_OR_WARN_USERS_THEY_CANNOT_UPGRADE?: { H: unknown };
        default?: { __CLIENT_INTERNALS_DO_NOT_USE_OR_WARN_USERS_THEY_CANNOT_UPGRADE?: { H: unknown } };
      }
    ).__CLIENT_INTERNALS_DO_NOT_USE_OR_WARN_USERS_THEY_CANNOT_UPGRADE ??
    (
      reactMod as unknown as {
        default?: { __CLIENT_INTERNALS_DO_NOT_USE_OR_WARN_USERS_THEY_CANNOT_UPGRADE?: { H: unknown } };
      }
    ).default?.__CLIENT_INTERNALS_DO_NOT_USE_OR_WARN_USERS_THEY_CANNOT_UPGRADE;
  if (!internals) {
    throw new Error('React hook dispatcher internals unavailable in test harness');
  }
  const prev = internals.H;
  internals.H = {
    useState: hooks.useState.bind(hooks),
    useRef: hooks.useRef.bind(hooks),
    useMemo: hooks.useMemo.bind(hooks),
    useCallback: hooks.useCallback.bind(hooks),
    useSyncExternalStore: hooks.useSyncExternalStore.bind(hooks),
    useId: hooks.useId.bind(hooks),
    useEffect: hooks.useEffect.bind(hooks),
    useDebugValue: () => undefined,
  };
  try {
    hooks.reset();
    return render();
  } finally {
    internals.H = prev;
  }
}

function findNode(
  node: unknown,
  predicate: (el: { type: unknown; props: Record<string, unknown> }) => boolean,
): { type: unknown; props: Record<string, unknown> } | null {
  if (!node || typeof node !== 'object') return null;
  if (Array.isArray(node)) {
    for (const child of node) {
      const found = findNode(child, predicate);
      if (found) return found;
    }
    return null;
  }
  const el = node as { type?: unknown; props?: Record<string, unknown> };
  if ('type' in el && el.props) {
    const candidate = { type: el.type, props: el.props };
    if (predicate(candidate)) return candidate;
    if (el.props.children !== undefined) {
      return findNode(el.props.children, predicate);
    }
  }
  return null;
}

describe('W0-B3 Web PKCE, /reset-password lock, logout cache purge & admin getUser()', () => {
  beforeEach(() => {
    vi.resetModules();
    vi.restoreAllMocks();
  });

  afterEach(() => {
    vi.doUnmock('@/core/config/supabase');
    vi.doUnmock('@/core/context/AuthContext');
    vi.doUnmock('@/core/locales/useTranslation');
    vi.unstubAllGlobals();
    vi.resetModules();
  });

  it('1. configures Supabase Web client with flowType: pkce', async () => {
    const { supabase } = await import('@/core/config/supabase');
    const authConfig = supabase.auth as unknown as { flowType?: string };
    expect(authConfig.flowType).toBe('pkce');
  });

  it('2. persists recovery across F5 & cross-tab events, ignores bare /reset-password, prevents post-update amr re-lock, and isolates multi-account sessions', async () => {
    const localMem = createMemoryStorage();
    const sessionMem = createMemoryStorage();
    const historyReplace = vi.fn();
    const historyPush = vi.fn();
    const storageListeners = new Set<(event: StorageEvent) => void>();
    const dispatchStorageEvent = (key: string | null) => {
      for (const listener of [...storageListeners]) {
        listener({ key } as StorageEvent);
      }
    };
    const crossTabLocalStorage: Storage = {
      get length() {
        return localMem.storage.length;
      },
      key: (index: number) => localMem.storage.key(index),
      getItem: (key: string) => localMem.storage.getItem(key),
      setItem: (key: string, value: string) => {
        localMem.storage.setItem(key, value);
        dispatchStorageEvent(key);
      },
      removeItem: (key: string) => {
        localMem.storage.removeItem(key);
        dispatchStorageEvent(key);
      },
      clear: () => {
        localMem.storage.clear();
        dispatchStorageEvent(null);
      },
    };
    vi.stubGlobal('localStorage', crossTabLocalStorage);
    vi.stubGlobal('sessionStorage', sessionMem.storage);
    vi.stubGlobal('window', {
      location: { pathname: '/reset-password', search: '', hash: '', origin: 'https://bilimyol.test' },
      history: { replaceState: historyReplace, pushState: historyPush },
      addEventListener: vi.fn((type: string, listener: EventListenerOrEventListenerObject) => {
        if (type === 'storage' && typeof listener === 'function') {
          storageListeners.add(listener as (event: StorageEvent) => void);
        }
      }),
      removeEventListener: vi.fn((type: string, listener: EventListenerOrEventListenerObject) => {
        if (type === 'storage' && typeof listener === 'function') {
          storageListeners.delete(listener as (event: StorageEvent) => void);
        }
      }),
      scrollTo: vi.fn(),
    });

    type AuthListener = (event: string, session: Session | null) => void;
    const listeners = new Set<AuthListener>();
    const authState = {
      currentSession: null as Session | null,
      profileRole: 'student' as 'student' | 'admin',
      updateUserError: null as Error | null,
    };

    const getSessionMock = vi.fn(async () => ({ data: { session: authState.currentSession }, error: null }));
    const signOutMock = vi.fn(async () => {
      authState.currentSession = null;
      for (const cb of [...listeners]) cb('SIGNED_OUT', null);
      return { error: null };
    });
    const signInMock = vi.fn(async ({ email }: { email: string }) => {
      const id = email.startsWith('account-b') ? 'user-b' : 'user-a';
      const s = makeSession(id, email, [{ method: 'password', timestamp: 1700001000 }]);
      authState.currentSession = s;
      for (const cb of [...listeners]) cb('SIGNED_IN', s);
      return { data: { user: s.user, session: s }, error: null };
    });
    const updateUserMock = vi.fn(async () => {
      if (authState.updateUserError) {
        return { data: { user: null }, error: authState.updateUserError };
      }
      // GoTrueClient emits USER_UPDATED before updateUser() resolves back to callers.
      for (const cb of [...listeners]) cb('USER_UPDATED', authState.currentSession);
      return { data: { user: authState.currentSession?.user ?? null }, error: null };
    });

    vi.doMock('@/core/config/supabase', () => ({
      isSupabaseConfigured: true,
      supabase: {
        auth: {
          getSession: getSessionMock,
          getUser: vi.fn(async () => ({ data: { user: authState.currentSession?.user ?? null }, error: null })),
          signInWithPassword: signInMock,
          signUp: vi.fn(),
          signOut: signOutMock,
          updateUser: updateUserMock,
          onAuthStateChange: vi.fn((cb: AuthListener) => {
            listeners.add(cb);
            return { data: { subscription: { unsubscribe: () => listeners.delete(cb) } } };
          }),
        },
        from: vi.fn(() => ({
          select: () => ({
            eq: (_col: string, id: string) => ({
              maybeSingle: async () => ({
                data: {
                  id,
                  first_name: id === 'user-b' ? 'Bek' : 'Ali',
                  last_name: '',
                  display_name: id === 'user-b' ? 'Bek' : 'Ali',
                  email: `${id}@bilimyol.test`,
                  avatar_url: '',
                  role: authState.profileRole,
                },
                error: null,
              }),
            }),
          }),
        })),
      },
    }));

    const authMod = await import('@/core/context/AuthContext');
    expect(authMod.RECOVERY_USER_STORAGE_KEY).toBe('bilimyol_recovery_user_id');

    const recoverySession = makeSession(
      'user-rec',
      'user-rec@bilimyol.test',
      [{ method: 'recovery', timestamp: 1700000100 }],
      1700000100,
    );
    const refreshedHistoricalRecoverySession = {
      ...makeSession(
        'user-rec',
        'user-rec@bilimyol.test',
        [{ method: 'recovery', timestamp: 1700000100 }],
        1700000200,
      ),
      access_token: `${recoverySession.access_token}-refreshed`,
    };
    const normalPasswordSession = makeSession(
      'user-normal',
      'normal@bilimyol.test',
      [{ method: 'password', timestamp: 1700000500 }],
      1700000500,
    );

    // Pure helper checks
    expect(authMod.hasUnresolvedRecoveryAmrClaim(recoverySession)).toBe(true);
    expect(authMod.hasUnresolvedRecoveryAmrClaim(normalPasswordSession)).toBe(false);
    expect(
      authMod.hasUnresolvedRecoveryAmrClaim(
        makeSession('user-rec', 'user-rec@bilimyol.test', [
          { method: 'recovery', timestamp: 100 },
          { method: 'password', timestamp: 200 },
        ]),
      ),
    ).toBe(false);
    expect(
      authMod.resolveInitialOrEventRecoveryState({
        event: 'INITIAL_SESSION',
        session: recoverySession,
        storedRecoveryUserId: 'user-rec',
      }),
    ).toMatchObject({ isPasswordRecovery: true, recoveryUserId: 'user-rec' });
    expect(
      authMod.resolveInitialOrEventRecoveryState({
        event: 'INITIAL_SESSION',
        session: normalPasswordSession,
        storedRecoveryUserId: null,
      }),
    ).toMatchObject({ isPasswordRecovery: false, recoveryUserId: null });

    // Live AuthProvider F5 + cross-tab + bare /reset-password + post-updatePassword amr check
    const reactMod = await import('react');
    const hooksTab1 = createHookDispatcher();
    const renderTab1 = () => {
      const el = withReactHookDispatcher(reactMod, hooksTab1, () =>
        authMod.AuthProvider({ children: null }),
      ) as { props: { value: ReturnType<typeof authMod.useAuth> } };
      hooksTab1.flushEffects();
      return el.props.value;
    };

    authState.currentSession = null;
    let tab1 = renderTab1();
    await new Promise((r) => setTimeout(r, 0));

    // Fire PASSWORD_RECOVERY in Tab 1
    authState.currentSession = recoverySession;
    for (const cb of [...listeners]) cb('PASSWORD_RECOVERY', recoverySession);
    tab1 = renderTab1();
    expect(tab1.isPasswordRecovery).toBe(true);
    expect(localMem.storage.getItem('bilimyol_recovery_user_id')).toBe('user-rec');

    // Simulate F5 reload (fresh AuthProvider where activeUserId starts null, INITIAL_SESSION fires)
    hooksTab1.unmount();
    const hooksF5 = createHookDispatcher();
    const renderF5 = () => {
      const el = withReactHookDispatcher(reactMod, hooksF5, () =>
        authMod.AuthProvider({ children: null }),
      ) as { props: { value: ReturnType<typeof authMod.useAuth> } };
      hooksF5.flushEffects();
      return el.props.value;
    };
    let f5Ctx = renderF5();
    for (const cb of [...listeners]) cb('INITIAL_SESSION', recoverySession);
    await new Promise((r) => setTimeout(r, 0));
    f5Ctx = renderF5();
    expect(f5Ctx.isPasswordRecovery).toBe(true);

    // Simulate Tab 2 receiving cross-tab SIGNED_IN while localStorage still holds bilimyol_recovery_user_id
    const hooksTab2 = createHookDispatcher();
    const renderTab2 = () => {
      const el = withReactHookDispatcher(reactMod, hooksTab2, () =>
        authMod.AuthProvider({ children: null }),
      ) as { props: { value: ReturnType<typeof authMod.useAuth> } };
      hooksTab2.flushEffects();
      return el.props.value;
    };
    renderTab2();
    await new Promise((r) => setTimeout(r, 0));
    for (const cb of [...listeners]) cb('SIGNED_IN', recoverySession);
    let tab2Ctx = renderTab2();
    expect(tab2Ctx.isPasswordRecovery).toBe(true);

    // Update password in F5 tab (updateUserMock emits USER_UPDATED before resolving) ->
    // storage event immediately unlocks Tab 2 WITHOUT waiting for TOKEN_REFRESHED/F5,
    // and subsequent historical amr in USER_UPDATED / TOKEN_REFRESHED does NOT re-lock.
    const updateRes = await f5Ctx.updatePassword('NewStrongPass123');
    expect(updateRes.error).toBeNull();
    expect(localMem.storage.getItem('bilimyol_recovery_user_id')).toBeNull();
    f5Ctx = renderF5();
    tab2Ctx = renderTab2();
    expect(f5Ctx.isPasswordRecovery).toBe(false);
    expect(tab2Ctx.isPasswordRecovery).toBe(false);

    authState.currentSession = refreshedHistoricalRecoverySession;
    for (const cb of [...listeners]) cb('USER_UPDATED', refreshedHistoricalRecoverySession);
    for (const cb of [...listeners]) cb('TOKEN_REFRESHED', refreshedHistoricalRecoverySession);
    await new Promise((r) => setTimeout(r, 0));
    f5Ctx = renderF5();
    tab2Ctx = renderTab2();
    expect(f5Ctx.isPasswordRecovery).toBe(false);
    expect(tab2Ctx.isPasswordRecovery).toBe(false);
    hooksTab2.unmount();
    hooksF5.unmount();
    expect(storageListeners.size).toBe(0);

    // Bare /reset-password pathname with normal password session never triggers recovery
    const hooksNormal = createHookDispatcher();
    const renderNormal = () => {
      const el = withReactHookDispatcher(reactMod, hooksNormal, () =>
        authMod.AuthProvider({ children: null }),
      ) as { props: { value: ReturnType<typeof authMod.useAuth> } };
      hooksNormal.flushEffects();
      return el.props.value;
    };
    authState.currentSession = normalPasswordSession;
    localMem.storage.removeItem('bilimyol_recovery_user_id');
    let normalCtx = renderNormal();
    await new Promise((r) => setTimeout(r, 0));
    for (const cb of [...listeners]) cb('INITIAL_SESSION', normalPasswordSession);
    normalCtx = renderNormal();
    expect(normalCtx.isPasswordRecovery).toBe(false);

    // Multi-account session isolation (Account A -> signOut -> Account B -> signOut -> Account A) preserves tour completion
    localMem.storage.setItem('bilimyol.product_tour_completed', 'true');
    const { useCourseStore } = await import('@/app/store/useCourseStore');
    const { useLearnerStore } = await import('@/app/store/useLearnerStore');
    useCourseStore.setState({ error: 'account-a-course-dirty' });
    useLearnerStore.setState({ isLoading: true });
    const signInA1 = await normalCtx.signIn('account-a@bilimyol.test', 'Pass1234!');
    expect(signInA1.profile?.id).toBe('user-a');
    await normalCtx.signOut();
    expect(useCourseStore.getState().error).toBeNull();
    expect(useLearnerStore.getState().isLoading).toBe(false);
    expect(localMem.storage.getItem('bilimyol.product_tour_completed')).toBe('true');

    const signInB = await normalCtx.signIn('account-b@bilimyol.test', 'Pass1234!');
    expect(signInB.error).toBeNull();
    expect(signInB.profile?.id).toBe('user-b');
    await normalCtx.signOut();
    const signInA2 = await normalCtx.signIn('account-a@bilimyol.test', 'Pass1234!');
    expect(signInA2.error).toBeNull();
    expect(signInA2.profile?.id).toBe('user-a');
    hooksNormal.unmount();

    // sessionStorage fallback when localStorage throws SecurityError
    vi.stubGlobal('localStorage', {
      getItem: () => { throw new Error('SecurityError'); },
      setItem: () => { throw new Error('SecurityError'); },
      removeItem: () => { throw new Error('SecurityError'); },
    });
    const hooksFallback = createHookDispatcher();
    const renderFallback = () => {
      const el = withReactHookDispatcher(reactMod, hooksFallback, () =>
        authMod.AuthProvider({ children: null }),
      ) as { props: { value: ReturnType<typeof authMod.useAuth> } };
      hooksFallback.flushEffects();
      return el.props.value;
    };
    authState.currentSession = null;
    renderFallback();
    await new Promise((r) => setTimeout(r, 0));
    for (const cb of [...listeners]) cb('PASSWORD_RECOVERY', recoverySession);
    const fbCtx = renderFallback();
    expect(fbCtx.isPasswordRecovery).toBe(true);
    expect(sessionMem.storage.getItem('bilimyol_recovery_user_id')).toBe('user-rec');
    hooksFallback.unmount();
  }, 15_000);

  it('3. locks AppRouter hasUsableAuth and showcase/tour routes during recovery and signs out on any ResetPasswordView exit with session', async () => {
    const localMem = createMemoryStorage();
    const sessionMem = createMemoryStorage();
    const replaceState = vi.fn();
    const pushState = vi.fn();
    const currentLocation = { pathname: '/admin', search: '?view=admin', hash: '', origin: 'https://bilimyol.test' };

    vi.stubGlobal('localStorage', localMem.storage);
    vi.stubGlobal('sessionStorage', sessionMem.storage);
    vi.stubGlobal('window', {
      location: currentLocation,
      history: { replaceState, pushState },
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
      scrollTo: vi.fn(),
    });

    const authMockState = {
      user: { id: 'admin-1', email: 'admin@bilimyol.test' },
      session: makeSession('admin-1', 'admin@bilimyol.test', [{ method: 'recovery', timestamp: 1700000100 }]),
      profile: { id: 'admin-1', firstName: 'Admin', lastName: '', email: 'admin@bilimyol.test', role: 'admin' as const },
      isLoading: false,
      isDemoMode: false,
      isPasswordRecovery: true,
      signOut: vi.fn(async () => {}),
      updatePassword: vi.fn(async () => ({ error: null })),
    };

    vi.doMock('@/core/context/AuthContext', () => ({
      useAuth: () => authMockState,
    }));
    vi.doMock('@/core/locales/useTranslation', () => ({
      useTranslation: () => ({
        language: 'uz' as const,
        t: (key: string) => key,
      }),
    }));

    const reactMod = await import('react');
    const routerMod = await import('@/app/router/AppRouter');
    const resetViewMod = await import('@/features/auth/ResetPasswordView');

    // Pure helper contract for ResetPasswordView exit sign-out
    expect(resetViewMod.shouldSignOutOnRecoveryExit({ isPasswordRecovery: true, done: false, hasSession: false })).toBe(true);
    expect(resetViewMod.shouldSignOutOnRecoveryExit({ isPasswordRecovery: false, done: true, hasSession: false })).toBe(true);
    expect(resetViewMod.shouldSignOutOnRecoveryExit({ isPasswordRecovery: false, done: false, hasSession: true })).toBe(true);
    expect(resetViewMod.shouldSignOutOnRecoveryExit({ isPasswordRecovery: false, done: false, hasSession: false })).toBe(false);

    // Frame-1 AppRouter check on /admin while isPasswordRecovery = true: must NOT render AdminDashboardView and must redirect to /reset-password
    const hooksAdmin = createHookDispatcher();
    const treeAdmin = withReactHookDispatcher(reactMod, hooksAdmin, () => routerMod.AppRouter());
    const serializedAdmin = JSON.stringify(treeAdmin);
    expect(serializedAdmin).not.toContain('AdminDashboardView');
    hooksAdmin.flushEffects();
    expect(replaceState).toHaveBeenCalledWith(null, '', '/reset-password');
    hooksAdmin.unmount();

    // Showcase/Tour routes (/pitch, /demo, /tour) must also redirect to /reset-password when isPasswordRecovery = true
    for (const bypassPath of ['/pitch', '/demo', '/tour']) {
      replaceState.mockClear();
      currentLocation.pathname = bypassPath;
      currentLocation.search = '';
      const hooksBypass = createHookDispatcher();
      withReactHookDispatcher(reactMod, hooksBypass, () => routerMod.AppRouter());
      hooksBypass.flushEffects();
      expect(replaceState, `Expected ${bypassPath} to redirect during recovery`).toHaveBeenCalledWith(
        null,
        '',
        '/reset-password',
      );
      hooksBypass.unmount();
    }

    // ResetPasswordView returnToLogin calls signOut() whenever session !== null even if isPasswordRecovery=false && done=false
    authMockState.isPasswordRecovery = false;
    authMockState.signOut.mockClear();
    const onNavigateLogin = vi.fn();
    const hooksReset = createHookDispatcher();
    const resetTree = withReactHookDispatcher(reactMod, hooksReset, () =>
      resetViewMod.ResetPasswordView({ onNavigateLogin }),
    );
    const { Button } = await import('@/presentation/components/Button');
    const backBtn = findNode(resetTree, (el) => el.type === Button && el.props.variant === 'ghost');
    expect(backBtn).not.toBeNull();
    await (backBtn!.props.onClick as () => Promise<void> | void)();
    expect(authMockState.signOut).toHaveBeenCalledTimes(1);
    expect(onNavigateLogin).toHaveBeenCalledTimes(1);
    hooksReset.unmount();
  }, 15_000);

  it('4. purges questionAnswerKeys, demo progress, learner/lesson repo caches, and admin demoStores on resetAllSessionStores while keeping product_tour_completed', async () => {
    const localMem = createMemoryStorage();
    const sessionMem = createMemoryStorage();
    localMem.storage.setItem('bilimyol.product_tour_completed', 'true');
    sessionMem.storage.setItem('bilimyol_demo_progress', JSON.stringify({ profile: { id: 'learner_default_01' } }));

    vi.stubGlobal('localStorage', localMem.storage);
    vi.stubGlobal('sessionStorage', sessionMem.storage);

    vi.doMock('@/core/config/supabase', () => ({
      isSupabaseConfigured: false,
      supabase: { auth: { getUser: vi.fn() } },
    }));

    const { setDemoRuntimeActive } = await import('@/core/runtime/demoRuntime');
    setDemoRuntimeActive(true);

    const { resetAllSessionStores } = await import('@/core/runtime/sessionReset');
    const { registerQuestionAnswerKey, getQuestionAnswerKey } = await import('@/core/runtime/questionAnswerKeys');
    const { supabaseLessonRepository } = await import('@/data/repositories/SupabaseLessonRepository');
    const { supabaseLearnerRepository } = await import('@/data/repositories/SupabaseLearnerRepository');
    const { adminContentService } = await import('@/data/services/AdminContentService');

    // Populate all 5 dynamic caches
    registerQuestionAnswerKey({
      id: 'q_runtime_1',
      options: ['A', 'B'],
      correctIndex: 1,
      explanation: 'B',
    });
    expect(getQuestionAnswerKey('q_runtime_1')).toBeDefined();

    await supabaseLessonRepository.saveLesson({
      id: 'demo_runtime_lesson_1',
      courseId: 'course_math_01',
      skillId: 'skill_math_functions',
      title: 'Demo Runtime Lesson',
      estimatedMinutes: 5,
      summary: 'Summary',
      steps: [],
      reinforcementExercise: {
        id: 'q_demo_1',
        courseId: 'course_math_01',
        skillId: 'skill_math_functions',
        text: '1+1?',
        options: ['1', '2'],
        difficulty: 'easy',
        explanation: '',
      },
    });
    expect(supabaseLessonRepository.getCachedDemoLessonSync('demo_runtime_lesson_1')?.id).toBe('demo_runtime_lesson_1');

    await supabaseLearnerRepository.setLearningReminders(false);
    await supabaseLearnerRepository.updateProfile({ xp: 777 });
    expect(await supabaseLearnerRepository.getLearningReminders()).toBe(false);
    expect((await supabaseLearnerRepository.getProfile()).xp).toBe(777);

    await adminContentService.saveCourse({ id: 'course_temp_demo', title: 'Temp Demo Course' });
    expect((await adminContentService.getCourses()).some((c) => c.id === 'course_temp_demo')).toBe(true);

    // Purge via sessionReset
    resetAllSessionStores();

    expect(getQuestionAnswerKey('q_runtime_1')).toBeUndefined();
    expect(sessionMem.storage.getItem('bilimyol_demo_progress')).toBeNull();
    expect(supabaseLessonRepository.getCachedDemoLessonSync('demo_runtime_lesson_1')).toBeNull();
    expect(await supabaseLearnerRepository.getLearningReminders()).toBe(true);
    expect((await supabaseLearnerRepository.getProfile()).xp).toBe(0);
    expect((await adminContentService.getCourses()).some((c) => c.id === 'course_temp_demo')).toBe(false);
    expect(localMem.storage.getItem('bilimyol.product_tour_completed')).toBe('true');

    // Verify W0-B2 invariant: AuthContext.tsx and sessionReset.ts contain zero static imports of banned modules
    const root = process.cwd();
    const authSrc = fs.readFileSync(path.resolve(root, 'src/core/context/AuthContext.tsx'), 'utf8');
    const resetSrc = fs.readFileSync(path.resolve(root, 'src/core/runtime/sessionReset.ts'), 'utf8');
    for (const banned of ['questionAnswerKeys', 'InMemoryLessonRepository', 'InMemoryLearnerRepository', 'datasources/lessons', 'datasources/questions']) {
      expect(authSrc).not.toContain(banned);
      expect(resetSrc).not.toContain(banned);
    }

    setDemoRuntimeActive(false);
  }, 15_000);

  it('5. verifies supabase.auth.getUser() once per live AdminContentService method and blocks PostgREST on error or null user', async () => {
    const fromMock = vi.fn();
    const rpcMock = vi.fn();
    const getUserMock = vi.fn();

    vi.doMock('@/core/config/supabase', () => ({
      isSupabaseConfigured: true,
      supabase: {
        auth: { getUser: getUserMock },
        from: fromMock,
        rpc: rpcMock,
      },
    }));

    const { setDemoRuntimeActive } = await import('@/core/runtime/demoRuntime');
    setDemoRuntimeActive(false);
    const { AdminContentService } = await import('@/data/services/AdminContentService');
    const svc = new AdminContentService();

    // Case A: null user -> throws before PostgREST
    getUserMock.mockResolvedValueOnce({ data: { user: null }, error: null });
    await expect(svc.getCourses()).rejects.toThrow();
    expect(getUserMock).toHaveBeenCalledTimes(1);
    expect(fromMock).not.toHaveBeenCalled();

    // Case B: getUser error -> throws before PostgREST
    getUserMock.mockClear();
    getUserMock.mockResolvedValueOnce({ data: { user: null }, error: new Error('JWT revoked') });
    await expect(svc.deleteCourse('course_1')).rejects.toThrow('JWT revoked');
    expect(getUserMock).toHaveBeenCalledTimes(1);
    expect(fromMock).not.toHaveBeenCalled();

    // Case C: getSkillOptions paginates across 2 pages while calling getUser() only ONCE before the loop
    getUserMock.mockClear();
    getUserMock.mockResolvedValueOnce({ data: { user: { id: 'admin-1' } }, error: null });
    let rangeCall = 0;
    fromMock.mockImplementation(() => ({
      select: () => ({
        eq: () => ({
          order: () => ({
            order: () => ({
              range: async () => {
                rangeCall += 1;
                return {
                  data: rangeCall === 1
                    ? Array.from({ length: 100 }, (_, i) => ({ id: `s-${i}`, name: `Skill ${i}` }))
                    : [{ id: 's-100', name: 'Skill 100' }],
                  error: null,
                };
              },
            }),
          }),
        }),
      }),
    }));

    const options = await svc.getSkillOptions('course_math_01');
    expect(options).toHaveLength(101);
    expect(getUserMock).toHaveBeenCalledTimes(1);
    expect(rangeCall).toBe(2);

    // Case D: all other live AdminContentService methods check getUser() and abort before PostgREST/RPC when null
    const liveCalls: Array<[string, () => Promise<unknown>]> = [
      ['saveCourse', () => svc.saveCourse({ id: 'c1', title: 'T' })],
      ['getSkills', () => svc.getSkills('c1')],
      ['saveSkill', () => svc.saveSkill({ id: 's1', name: 'S' })],
      ['deleteSkill', () => svc.deleteSkill('s1')],
      ['getLessons', () => svc.getLessons('c1')],
      ['getLessonDetails', () => svc.getLessonDetails('l1')],
      ['saveLesson', () => svc.saveLesson({ id: 'l1', title: 'L' })],
      ['toggleLessonPublish', () => svc.toggleLessonPublish('l1', true)],
      ['toggleLessonArchive', () => svc.toggleLessonArchive('l1', true)],
      ['deleteLesson', () => svc.deleteLesson('l1')],
      ['getQuestions', () => svc.getQuestions('c1')],
      ['saveQuestion', () => svc.saveQuestion({ id: 'q1', text: 'Q' })],
      ['deleteQuestion', () => svc.deleteQuestion('q1')],
    ];
    for (const [label, fn] of liveCalls) {
      getUserMock.mockClear();
      fromMock.mockClear();
      rpcMock.mockClear();
      getUserMock.mockResolvedValueOnce({ data: { user: null }, error: null });
      await expect(fn(), `Expected ${label} to reject without user`).rejects.toThrow();
      expect(getUserMock, `Expected ${label} to call getUser once`).toHaveBeenCalledTimes(1);
      expect(fromMock, `Expected ${label} not to query PostgREST`).not.toHaveBeenCalled();
      expect(rpcMock, `Expected ${label} not to invoke RPC`).not.toHaveBeenCalled();
    }
  });
});
