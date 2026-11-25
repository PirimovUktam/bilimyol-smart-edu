import { LocalizedError } from '@/core/locales/LocalizedError';
import React, { createContext, useContext, useEffect, useState, useCallback, useRef } from 'react';
import { User, Session } from '@supabase/supabase-js';
import { supabase, isSupabaseConfigured } from '../config/supabase';
import { ACTIVE_COURSE_STORAGE_KEY, resetAllSessionStores } from '@/core/runtime/sessionReset';
import { isDemoRuntimeActive, setDemoRuntimeActive } from '@/core/runtime/demoRuntime';
import { clearTutorHistory } from '@/core/runtime/tutorHistory';
import { authError } from '@/core/utils/authErrors';

export interface UserProfile {
  id: string;
  firstName: string;
  lastName: string;
  email: string;
  avatarUrl?: string;
  role?: 'student' | 'admin';
}

interface AuthContextType {
  user: User | null;
  session: Session | null;
  profile: UserProfile | null;
  isLoading: boolean;
  isDemoMode: boolean;
  isPasswordRecovery: boolean;
  signIn: (email: string, password: string) => Promise<{ error: Error | null; profile?: UserProfile | null }>;
  signUp: (email: string, password: string, firstName: string, lastName: string) => Promise<{ error: Error | null; requiresEmailConfirmation?: boolean }>;
  signOut: (scope?: 'local' | 'global') => Promise<void>;
  resetPassword: (email: string) => Promise<{ error: Error | null }>;
  resendConfirmation: (email: string) => Promise<{ error: Error | null }>;
  updatePassword: (newPassword: string) => Promise<{ error: Error | null }>;
  updateProfile: (data: Partial<UserProfile>) => Promise<{ error: Error | null }>;
  refreshProfile: () => Promise<UserProfile | null>;
  setDemoUser: () => void;
}

const defaultDemoProfile: UserProfile = {
  id: 'guest_user_01',
  firstName: 'Foydalanuvchi',
  lastName: '',
  email: 'guest@bilimyol.uz',
  avatarUrl: '',
  role: 'student',
};

export const RECOVERY_USER_STORAGE_KEY = 'bilimyol_recovery_user_id';
const CLEARED_RECOVERY_STORAGE_KEY = 'bilimyol_recovery_cleared_claim';

export interface ClearedRecoveryClaim {
  userId?: string;
  accessToken?: string;
  recoveryTimestamp?: number;
  clearedAt?: number;
}

export type ClearedRecoveryToken = string | number | ClearedRecoveryClaim | null;

export interface ResolveRecoveryStateInput {
  event: string;
  session: Session | null;
  storedRecoveryUserId: string | null;
  clearedToken?: ClearedRecoveryToken;
}

export interface ResolveRecoveryStateResult {
  isPasswordRecovery: boolean;
  recoveryUserId: string | null;
  clearClearedMarker: boolean;
}

interface NormalizedAmrEntry {
  method: string;
  timestamp: number;
}

function decodeJwtPayload(token: string | undefined | null): Record<string, unknown> | null {
  if (!token || typeof token !== 'string') return null;
  const parts = token.split('.');
  if (parts.length < 2) return null;
  try {
    const normalized = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const padded = normalized.padEnd(normalized.length + ((4 - (normalized.length % 4)) % 4), '=');
    const json = typeof globalThis.atob === 'function'
      ? globalThis.atob(padded)
      : Buffer.from(padded, 'base64').toString('utf8');
    const parsed = JSON.parse(json) as unknown;
    return parsed && typeof parsed === 'object' ? (parsed as Record<string, unknown>) : null;
  } catch {
    return null;
  }
}

function extractAmrEntries(session: Session | null, payload: Record<string, unknown> | null): NormalizedAmrEntry[] {
  const rawAmr = payload?.amr ?? (session as { amr?: unknown } | null)?.amr;
  if (!Array.isArray(rawAmr)) return [];
  const entries: NormalizedAmrEntry[] = [];
  for (const item of rawAmr) {
    if (typeof item === 'string' && item) {
      entries.push({ method: item, timestamp: 0 });
    } else if (item && typeof item === 'object' && typeof (item as { method?: unknown }).method === 'string') {
      const ts = (item as { timestamp?: unknown }).timestamp;
      entries.push({
        method: (item as { method: string }).method,
        timestamp: typeof ts === 'number' && Number.isFinite(ts) ? ts : 0,
      });
    }
  }
  return entries;
}

function parseClearedToken(clearedToken?: ClearedRecoveryToken): ClearedRecoveryClaim | null {
  if (clearedToken === undefined || clearedToken === null) return null;
  if (typeof clearedToken === 'number' && Number.isFinite(clearedToken)) {
    return { clearedAt: clearedToken };
  }
  if (typeof clearedToken === 'string') {
    const trimmed = clearedToken.trim();
    if (!trimmed) return null;
    if (trimmed.startsWith('{')) {
      try {
        const parsed = JSON.parse(trimmed) as unknown;
        if (parsed && typeof parsed === 'object') return parsed as ClearedRecoveryClaim;
      } catch { /* Treat as raw access token when not JSON. */ }
    }
    return { accessToken: trimmed };
  }
  if (typeof clearedToken === 'object') return clearedToken;
  return null;
}

export function hasUnresolvedRecoveryAmrClaim(
  session: Session | null,
  clearedToken?: ClearedRecoveryToken,
): boolean {
  if (!session?.user?.id) return false;
  const payload = decodeJwtPayload(session.access_token);
  const entries = extractAmrEntries(session, payload);
  const recoveryEntries = entries.filter((entry) => entry.method === 'recovery');
  if (recoveryEntries.length === 0) return false;

  const latestRecoveryTs = Math.max(...recoveryEntries.map((entry) => entry.timestamp));
  const hasNewerPasswordAuth = entries.some(
    (entry) => entry.method === 'password' && entry.timestamp > latestRecoveryTs,
  );
  if (hasNewerPasswordAuth) return false;

  const cleared = parseClearedToken(clearedToken);
  if (cleared && (!cleared.userId || cleared.userId === session.user.id)) {
    if (cleared.accessToken && session.access_token === cleared.accessToken) {
      return false;
    }
    if (
      typeof cleared.recoveryTimestamp === 'number' &&
      Number.isFinite(cleared.recoveryTimestamp) &&
      latestRecoveryTs > 0 &&
      latestRecoveryTs <= cleared.recoveryTimestamp
    ) {
      return false;
    }
    if (typeof cleared.clearedAt === 'number' && Number.isFinite(cleared.clearedAt)) {
      if (latestRecoveryTs > 0 && latestRecoveryTs <= cleared.clearedAt) {
        return false;
      }
      const iat = typeof payload?.iat === 'number' && Number.isFinite(payload.iat) ? payload.iat : undefined;
      if (latestRecoveryTs === 0 && (iat === undefined || iat <= cleared.clearedAt)) {
        return false;
      }
    }
  }

  return true;
}

export function resolveInitialOrEventRecoveryState({
  event,
  session,
  storedRecoveryUserId,
  clearedToken,
}: ResolveRecoveryStateInput): ResolveRecoveryStateResult {
  if (event === 'SIGNED_OUT' || !session?.user?.id) {
    return { isPasswordRecovery: false, recoveryUserId: null, clearClearedMarker: false };
  }
  const userId = session.user.id;
  if (event === 'PASSWORD_RECOVERY') {
    return { isPasswordRecovery: true, recoveryUserId: userId, clearClearedMarker: true };
  }
  if (storedRecoveryUserId === userId || hasUnresolvedRecoveryAmrClaim(session, clearedToken)) {
    return { isPasswordRecovery: true, recoveryUserId: userId, clearClearedMarker: false };
  }
  return { isPasswordRecovery: false, recoveryUserId: null, clearClearedMarker: false };
}

function readStorageWithFallback(key: string): string | null {
  try {
    const value = globalThis.localStorage?.getItem(key);
    if (value) return value;
  } catch { /* Fall back to sessionStorage when localStorage is unavailable. */ }
  try {
    const value = globalThis.sessionStorage?.getItem(key);
    if (value) return value;
  } catch { /* Storage unavailable; fall back to in-memory state. */ }
  return null;
}

function writeStorageWithFallback(key: string, value: string | null): boolean {
  if (value === null) {
    let ok = true;
    try {
      globalThis.localStorage?.removeItem(key);
    } catch { ok = false; }
    try {
      globalThis.sessionStorage?.removeItem(key);
    } catch { ok = false; }
    return ok;
  }
  try {
    globalThis.localStorage?.setItem(key, value);
    try {
      globalThis.sessionStorage?.removeItem(key);
    } catch { /* Ignore fallback cleanup error. */ }
    return true;
  } catch { /* Fall back to sessionStorage when localStorage is blocked. */ }
  try {
    globalThis.sessionStorage?.setItem(key, value);
    return true;
  } catch { /* In-memory ref still tracks the active tab. */ }
  return false;
}

const DEMO_SESSION_KEY = 'bilimyol_demo_session';

function readDemoProfile(): UserProfile | null {
  try {
    const stored = JSON.parse(sessionStorage.getItem(DEMO_SESSION_KEY) ?? 'null');
    const profile = stored?.profile;
    if (stored?.isDemoMode === true && profile?.id === defaultDemoProfile.id && profile.role === 'student') {
      return {
        ...defaultDemoProfile,
        firstName: typeof profile.firstName === 'string' ? profile.firstName : defaultDemoProfile.firstName,
        lastName: typeof profile.lastName === 'string' ? profile.lastName : '',
      };
    }
  } catch { /* The demo is still available if browser storage cannot be read. */ }
  return null;
}

function storeDemoProfile(profile: UserProfile | null) {
  try {
    if (profile) sessionStorage.setItem(DEMO_SESSION_KEY, JSON.stringify({ profile, isDemoMode: true }));
    else sessionStorage.removeItem(DEMO_SESSION_KEY);
  } catch { /* A demo can still run in the current page. */ }
}

interface ProfileFetchOptions {
  provisionIfMissing?: {
    firstName: string;
    lastName: string;
  };
  throwOnError?: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [isDemoMode, setIsDemoMode] = useState<boolean>(false);
  const [isPasswordRecovery, setIsPasswordRecovery] = useState(false);
  const profileRequest = useRef(0);
  const authRevision = useRef(0);
  const authAction = useRef(0);
  const activeUserId = useRef<string | null>(null);
  const activeSessionRef = useRef<Session | null>(null);
  const pendingAuth = useRef<{ request: number; email: string; userId?: string } | null>(null);
  // Entries live only until their action settles, including canceled SDK calls.
  const authOperations = useRef(new Map<number, string>());
  const signingOut = useRef<number | null>(null);
  const recoveryUserId = useRef<string | null>(null);
  const recoveryStorageAvailable = useRef(true);
  const clearedRecoveryRef = useRef<ClearedRecoveryClaim | null>(null);

  const setRecoveryUser = useCallback((userId: string | null) => {
    recoveryUserId.current = userId;
    recoveryStorageAvailable.current = writeStorageWithFallback(RECOVERY_USER_STORAGE_KEY, userId);
    setIsPasswordRecovery(userId !== null);
  }, []);

  const getStoredRecoveryUserId = useCallback((): string | null => {
    const stored = readStorageWithFallback(RECOVERY_USER_STORAGE_KEY);
    if (stored) return stored;
    return recoveryStorageAvailable.current ? null : recoveryUserId.current;
  }, []);

  const clearClearedRecovery = useCallback(() => {
    clearedRecoveryRef.current = null;
    writeStorageWithFallback(CLEARED_RECOVERY_STORAGE_KEY, null);
  }, []);

  const recordClearedRecovery = useCallback((userId: string, currentSession: Session | null) => {
    const payload = decodeJwtPayload(currentSession?.access_token);
    const entries = extractAmrEntries(currentSession, payload);
    const recoveryTimestamps = entries
      .filter((entry) => entry.method === 'recovery' && entry.timestamp > 0)
      .map((entry) => entry.timestamp);
    const claim: ClearedRecoveryClaim = {
      userId,
      accessToken: currentSession?.access_token,
      recoveryTimestamp: recoveryTimestamps.length > 0 ? Math.max(...recoveryTimestamps) : undefined,
      clearedAt: Math.floor(Date.now() / 1000),
    };
    clearedRecoveryRef.current = claim;
    writeStorageWithFallback(CLEARED_RECOVERY_STORAGE_KEY, JSON.stringify(claim));
  }, []);

  const getActiveClearedRecovery = useCallback((): ClearedRecoveryToken => {
    const stored = readStorageWithFallback(CLEARED_RECOVERY_STORAGE_KEY);
    if (stored) return stored;
    return recoveryStorageAvailable.current ? null : clearedRecoveryRef.current;
  }, []);

  const clearSessionStores = useCallback(() => {
    resetAllSessionStores();
    clearTutorHistory();
    try {
      localStorage.removeItem(ACTIVE_COURSE_STORAGE_KEY);
    } catch { /* The authenticated profile is still the source of truth. */ }
  }, []);

  const invalidatePendingAuth = useCallback(() => {
    authRevision.current++;
    authAction.current++;
    profileRequest.current++;
    pendingAuth.current = null;
  }, []);

  const clearAuthState = useCallback(() => {
    invalidatePendingAuth();
    activeUserId.current = null;
    activeSessionRef.current = null;
    setDemoRuntimeActive(false);
    storeDemoProfile(null);
    clearSessionStores();
    setUser(null);
    setSession(null);
    setProfile(null);
    setIsDemoMode(false);
    setRecoveryUser(null);
    setIsLoading(false);
  }, [clearSessionStores, invalidatePendingAuth, setRecoveryUser]);

  const beginAuthAction = (email: string) => {
    const request = ++authAction.current;
    authRevision.current++;
    profileRequest.current++;
    setDemoRuntimeActive(false);
    storeDemoProfile(null);
    pendingAuth.current = { request, email: email.toLowerCase().trim() };
    authOperations.current.set(request, pendingAuth.current.email);
    // A previous account's data must not render while another login is pending.
    if (activeUserId.current || profile) clearSessionStores();
    activeUserId.current = null;
    activeSessionRef.current = null;
    setUser(null);
    setSession(null);
    setProfile(null);
    setIsDemoMode(false);
    setRecoveryUser(null);
    clearClearedRecovery();
    setIsLoading(true);
    return request;
  };

  const staleActionError = () => new LocalizedError('errors.sessionChanged');

  const fetchProfile = useCallback(async (
    userId: string,
    email: string,
    options: ProfileFetchOptions = {},
  ) => {
    const request = ++profileRequest.current;
    const isCurrent = () => request === profileRequest.current;
    if (!isSupabaseConfigured) return null;

    try {
      // Query authoritative public.profiles. Signup may recover from a missing
      // trigger-created row, but the role is always read from the database.
      let { data, error } = await supabase
        .from('profiles')
        .select('id, first_name, last_name, display_name, email, avatar_url, role')
        .eq('id', userId)
        .maybeSingle();

      if (!isCurrent()) return null;
      if (error) {
        throw new LocalizedError('errors.profileRead');
      }

      if (!data && options.provisionIfMissing) {
        const firstName = options.provisionIfMissing.firstName.trim()
          || (email ? email.split('@')[0] : 'Foydalanuvchi');
        const lastName = options.provisionIfMissing.lastName.trim();
        const displayName = lastName ? `${firstName} ${lastName}` : firstName;

        // The trigger is authoritative for role. This fallback deliberately
        // inserts only self-owned, non-privileged profile columns.
        const { error: provisionError } = await supabase
          .from('profiles')
          .insert({
            id: userId,
            first_name: firstName,
            last_name: lastName,
            display_name: displayName,
            email: email || '',
          });

        if (provisionError) {
          throw new LocalizedError('errors.profileCreate');
        }

        const { data: provisioned, error: readError } = await supabase
          .from('profiles')
          .select('id, first_name, last_name, display_name, email, avatar_url, role')
          .eq('id', userId)
          .maybeSingle();

        if (readError) {
          throw new LocalizedError('errors.profileCreatedRead');
        }
        if (!isCurrent()) return null;
        data = provisioned;
      }

      if (data && data.id === userId && ['student', 'admin'].includes(data.role)) {
        // Authoritative role from public.profiles
        const userRole = data.role as NonNullable<UserProfile['role']>;
        const resolvedFirst = data.first_name || (email ? email.split('@')[0] : 'Foydalanuvchi');
        const userProfile: UserProfile = {
          id: data.id,
          firstName: resolvedFirst,
          lastName: data.last_name || '',
          email: data.email || email,
          avatarUrl: data.avatar_url || '',
          role: userRole,
        };

        setProfile(userProfile);
        return userProfile;
      }

      // Missing/unavailable DB role is not permission to trust signup metadata.
      throw new Error(options.provisionIfMissing
        ? 'Profil serverda yaratildi, ammo authoritative roli o‘qilmadi. Qayta urinib ko‘ring.'
        : 'Profil serverda topilmadi. Qayta urinib ko‘ring.');
    } catch (err) {
      if (!isCurrent()) return null;
      console.warn('Error resolving authenticated profile from Supabase:', err);
      setProfile(null);
      if (options.throwOnError) {
        throw err instanceof Error
          ? err
          : new LocalizedError('errors.profileRead');
      }
      return null;
    } finally {
      if (isCurrent()) setIsLoading(false);
    }
  }, []);

  const refreshProfile = useCallback(async (): Promise<UserProfile | null> => {
    if (isDemoMode) return profile;
    if (!isSupabaseConfigured) return null;

    const revision = authRevision.current;
    const userId = activeUserId.current;
    if (!userId) return null;
    const { data: userData } = await supabase.auth.getUser();
    if (revision !== authRevision.current || userId !== activeUserId.current) return null;
    if (userData.user?.id === userId) {
      return await fetchProfile(userData.user.id, userData.user.email ?? '');
    }
    return null;
  }, [fetchProfile, isDemoMode, profile]);

  useEffect(() => {
    let mounted = true;
    const startupRevision = authRevision.current;
    const isCurrentStartup = () => mounted && startupRevision === authRevision.current;
    try {
      localStorage.removeItem('bilimyol_auth_session');
    } catch { /* Older copies of the profile are never used to sign in. */ }

    function restoreDemo() {
      const demo = readDemoProfile();
      setDemoRuntimeActive(Boolean(demo));
      setProfile(demo);
      setIsDemoMode(Boolean(demo));
      setIsLoading(false);
    }

    async function initAuth() {
      try {
        if (!isSupabaseConfigured) {
          if (isCurrentStartup()) restoreDemo();
          return;
        }

        const { data } = await supabase.auth.getSession();
        if (isCurrentStartup()) {
          activeUserId.current = data.session?.user.id ?? null;
          activeSessionRef.current = data.session;
          setSession(data.session);
          setUser(data.session?.user ?? null);
          if (data.session?.user) {
            const recoveryState = resolveInitialOrEventRecoveryState({
              event: 'INITIAL_SESSION',
              session: data.session,
              storedRecoveryUserId: getStoredRecoveryUserId(),
              clearedToken: getActiveClearedRecovery(),
            });
            setRecoveryUser(recoveryState.recoveryUserId);
            storeDemoProfile(null);
            setDemoRuntimeActive(false);
            await fetchProfile(data.session.user.id, data.session.user.email ?? '');
          } else {
            setRecoveryUser(null);
            clearSessionStores();
            restoreDemo();
          }
        }
      } catch (err) {
        console.warn('Auth initialization error:', err);
        if (isCurrentStartup()) restoreDemo();
      }
    }

    initAuth();

    const syncRecoveryFromStorage = (event: StorageEvent) => {
      if (!mounted) return;
      if (
        event.key !== null &&
        event.key !== RECOVERY_USER_STORAGE_KEY &&
        event.key !== CLEARED_RECOVERY_STORAGE_KEY
      ) {
        return;
      }
      clearedRecoveryRef.current = parseClearedToken(readStorageWithFallback(CLEARED_RECOVERY_STORAGE_KEY));
      if (!activeSessionRef.current?.user) {
        recoveryUserId.current = readStorageWithFallback(RECOVERY_USER_STORAGE_KEY);
        setIsPasswordRecovery(false);
        return;
      }
      const recoveryState = resolveInitialOrEventRecoveryState({
        event: 'STORAGE_SYNC',
        session: activeSessionRef.current,
        storedRecoveryUserId: getStoredRecoveryUserId(),
        clearedToken: getActiveClearedRecovery(),
      });
      recoveryUserId.current = recoveryState.recoveryUserId;
      setIsPasswordRecovery(recoveryState.isPasswordRecovery);
    };

    const hasWindowStorage = typeof window !== 'undefined' && typeof window.addEventListener === 'function';
    if (hasWindowStorage) {
      window.addEventListener('storage', syncRecoveryFromStorage);
    }

    if (isSupabaseConfigured) {
      const { data: authListener } = supabase.auth.onAuthStateChange((event, newSession) => {
        if (!mounted) return;
        if (event === 'INITIAL_SESSION' && startupRevision !== authRevision.current) return;
        if (event === 'INITIAL_SESSION' && !newSession?.user) {
          return; // initAuth restores an explicitly started demo in this tab.
        }
        if (!newSession?.user && isDemoRuntimeActive()) return;
        if (signingOut.current !== null && newSession?.user) return;
        const eventEmail = newSession?.user.email?.toLowerCase();
        const pending = pendingAuth.current;
        const isOwnAuthEvent = Boolean(pending && pending.email === eventEmail);
        if (eventEmail && !isOwnAuthEvent && [...authOperations.current].some(
          ([request, email]) => request !== authAction.current && email === eventEmail
        )) return;
        authRevision.current++;
        if (event === 'SIGNED_OUT' || !newSession?.user) {
          clearAuthState();
          return;
        }

        if (pending && !isOwnAuthEvent) {
          authAction.current++;
          pendingAuth.current = null;
        }
        const changedAccount = activeUserId.current !== newSession.user.id;
        const recoveryState = resolveInitialOrEventRecoveryState({
          event,
          session: newSession,
          storedRecoveryUserId: getStoredRecoveryUserId(),
          clearedToken: event === 'PASSWORD_RECOVERY' ? null : getActiveClearedRecovery(),
        });
        if (recoveryState.clearClearedMarker) {
          clearClearedRecovery();
        }
        if (recoveryState.isPasswordRecovery) {
          setRecoveryUser(recoveryState.recoveryUserId);
        } else {
          setRecoveryUser(null);
        }
        if (changedAccount) {
          profileRequest.current++;
          if (activeUserId.current || isDemoRuntimeActive()) clearSessionStores();
          setProfile(null);
        }
        activeUserId.current = newSession.user.id;
        activeSessionRef.current = newSession;
        storeDemoProfile(null);
        setDemoRuntimeActive(false);
        setSession(newSession);
        setUser(newSession.user);
        setIsDemoMode(false);
        if (isOwnAuthEvent && pending) {
          // The action owns the authoritative read. Do not invalidate its result
          // simply because Supabase emitted SIGNED_IN for that same action.
          pending.userId = newSession.user.id;
          return;
        }
        profileRequest.current++;
        const revision = authRevision.current;
        if (changedAccount || event === 'INITIAL_SESSION') setIsLoading(true);
        // Keep this callback synchronous; DB reads can need the auth session lock.
        queueMicrotask(() => {
          if (mounted && revision === authRevision.current && activeUserId.current === newSession.user.id) {
            void fetchProfile(newSession.user.id, newSession.user.email ?? '');
          }
        });
      });

      return () => {
        mounted = false;
        if (hasWindowStorage) {
          window.removeEventListener('storage', syncRecoveryFromStorage);
        }
        invalidatePendingAuth();
        authListener.subscription.unsubscribe();
      };
    }

    return () => {
      mounted = false;
      if (hasWindowStorage) {
        window.removeEventListener('storage', syncRecoveryFromStorage);
      }
      invalidatePendingAuth();
    };
  }, [clearAuthState, clearClearedRecovery, clearSessionStores, fetchProfile, getActiveClearedRecovery, getStoredRecoveryUserId, invalidatePendingAuth, setRecoveryUser]);

  const signIn = async (email: string, password: string) => {
    if (signingOut.current !== null) return { error: staleActionError() };
    if (!isSupabaseConfigured) return { error: new LocalizedError('errors.unavailable') };

    const request = beginAuthAction(email);
    try {
      const { data: authData, error } = await supabase.auth.signInWithPassword({ email, password });
      if (request !== authAction.current) return { error: staleActionError() };
      if (error || !authData.user || !authData.session) {
        return { error: authError(error, 'errors.login') };
      }
      if (pendingAuth.current?.userId && pendingAuth.current.userId !== authData.user.id) {
        return { error: staleActionError() };
      }
      activeUserId.current = authData.user.id;
      activeSessionRef.current = authData.session;
      setUser(authData.user);
      setSession(authData.session);
      const resolved = await fetchProfile(authData.user.id, authData.user.email ?? email);
      if (request !== authAction.current) return { error: staleActionError() };
      return resolved
        ? { error: null, profile: resolved }
        : { error: new LocalizedError('errors.profileLoad') };
    } catch (err) {
      return { error: request !== authAction.current ? staleActionError() : err instanceof Error ? err : new LocalizedError('errors.loginFailed') };
    } finally {
      authOperations.current.delete(request);
      if (request === authAction.current) {
        pendingAuth.current = null;
        setIsLoading(false);
      }
    }
  };

  const signUp = async (
    email: string,
    password: string,
    firstName: string,
    lastName: string
  ): Promise<{ error: Error | null; requiresEmailConfirmation?: boolean }> => {
    if (signingOut.current !== null) return { error: staleActionError() };
    if (!isSupabaseConfigured) return { error: new LocalizedError('errors.unavailable') };

    const request = beginAuthAction(email);
    try {
      const signUpOptions: {
        data: { first_name: string; last_name: string };
        emailRedirectTo?: string;
      } = {
        data: {
          first_name: firstName,
          last_name: lastName,
        },
      };
      if (typeof window !== 'undefined') {
        signUpOptions.emailRedirectTo = window.location.origin;
      }

      const { data: signUpData, error } = await supabase.auth.signUp({
        email,
        password,
        options: signUpOptions,
      });

      if (request !== authAction.current) return { error: staleActionError() };
      if (error) return { error: authError(error, 'errors.register') };
      if (!signUpData.user) return { error: new LocalizedError('errors.register') };
      if (!signUpData.session) {
        authRevision.current++;
        profileRequest.current++;
        activeUserId.current = null;
        setUser(null);
        setSession(null);
        setProfile(null);
        return { error: null, requiresEmailConfirmation: true };
      }
      if (pendingAuth.current?.userId && pendingAuth.current.userId !== signUpData.user.id) {
        return { error: staleActionError() };
      }
      activeUserId.current = signUpData.user.id;
      activeSessionRef.current = signUpData.session;
      setUser(signUpData.user);
      setSession(signUpData.session);
      const resolved = await fetchProfile(
        signUpData.user.id,
        signUpData.user.email ?? email,
        {
          provisionIfMissing: { firstName, lastName },
          throwOnError: true,
        },
      );
      if (request !== authAction.current) return { error: staleActionError() };
      return resolved
        ? { error: null }
        : { error: new LocalizedError('errors.profileLoad') };
    } catch (err) {
      return { error: request !== authAction.current ? staleActionError() : err instanceof Error ? err : new LocalizedError('errors.register') };
    } finally {
      authOperations.current.delete(request);
      if (request === authAction.current) {
        pendingAuth.current = null;
        setIsLoading(false);
      }
    }
  };

  const signOut = async (scope: 'local' | 'global' = 'local') => {
    if (!isSupabaseConfigured || isDemoMode) {
      clearAuthState();
      return;
    }
    const request = authAction.current;
    signingOut.current = request;
    try {
      const result = await supabase.auth.signOut({ scope });
      if (result?.error) throw new LocalizedError('auth.logoutFailed');
      if (authAction.current === request) clearAuthState();
    } finally {
      if (signingOut.current === request) signingOut.current = null;
    }
  };

  const resetPassword = async (email: string) => {
    if (!isSupabaseConfigured) {
      return { error: new LocalizedError('errors.demoRecovery') };
    }

    try {
      const { error } = await supabase.auth.resetPasswordForEmail(email, {
        redirectTo: `${window.location.origin}/reset-password`,
      });
      return { error: error ? authError(error, 'errors.recoveryRequest') : null };
    } catch {
      return { error: new LocalizedError('errors.recovery') };
    }
  };

  const resendConfirmation = async (email: string) => {
    if (!isSupabaseConfigured) return { error: new LocalizedError('errors.unavailable') };
    try {
      const { error } = await supabase.auth.resend({
        type: 'signup', email: email.trim(),
        options: { emailRedirectTo: window.location.origin },
      });
      return { error: error ? authError(error, 'errors.auth') : null };
    } catch {
      return { error: new LocalizedError('auth.resendFailed') };
    }
  };

  // Sets the new password on the recovery session Supabase establishes after
  // the emailed link is opened. Without this, the reset email is a dead end.
  const updatePassword = async (newPassword: string) => {
    const recoveryId = getStoredRecoveryUserId();
    if (!isSupabaseConfigured || !recoveryId || recoveryId !== activeUserId.current) {
      return { error: new LocalizedError('errors.recoveryRequired') };
    }
    if (newPassword.trim().length < 6) {
      return { error: new LocalizedError('auth.shortPassword') };
    }
    try {
      const { error } = await supabase.auth.updateUser({ password: newPassword });
      if (error) {
        return { error: new LocalizedError('errors.passwordUpdate') };
      }
      recordClearedRecovery(recoveryId, activeSessionRef.current);
      setRecoveryUser(null);
      return { error: null };
    } catch {
      return { error: new LocalizedError('errors.passwordConnection') };
    }
  };

  const updateProfile = async (data: Partial<UserProfile>) => {
    if (!profile) return { error: new LocalizedError('errors.profileMissing') };
    if (isSupabaseConfigured && !isDemoMode && profile.id !== activeUserId.current) return { error: staleActionError() };

    const updated = {
      ...profile,
      firstName: data.firstName ?? profile.firstName,
      lastName: data.lastName ?? profile.lastName,
      avatarUrl: data.avatarUrl ?? profile.avatarUrl,
    };

    if (isDemoMode) {
      setProfile(updated);
      storeDemoProfile(updated);
      return { error: null };
    }
    if (!isSupabaseConfigured) return { error: new LocalizedError('errors.unavailable') };

    const request = profileRequest.current;
    const action = authAction.current;
    try {
      const { error } = await supabase
        .from('profiles')
        .update({
          first_name: updated.firstName,
          last_name: updated.lastName,
          display_name: updated.lastName ? `${updated.firstName} ${updated.lastName}` : updated.firstName,
          avatar_url: updated.avatarUrl,
          updated_at: new Date().toISOString(),
        })
        .eq('id', profile.id);

      if (error) return { error: new LocalizedError('errors.profileSave') };
      if (request !== profileRequest.current || action !== authAction.current || profile.id !== activeUserId.current) {
        return { error: staleActionError() };
      }
      setProfile(updated);
      return { error: null };
    } catch {
      return { error: new LocalizedError('errors.profileSave') };
    }
  };

  const setDemoUser = () => {
    clearAuthState();
    setDemoRuntimeActive(true);
    setProfile(defaultDemoProfile);
    setIsDemoMode(true);
    storeDemoProfile(defaultDemoProfile);
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        session,
        profile,
        isLoading,
        isDemoMode,
        isPasswordRecovery,
        signIn,
        signUp,
        signOut,
        resetPassword,
        resendConfirmation,
        updatePassword,
        updateProfile,
        refreshProfile,
        setDemoUser,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
