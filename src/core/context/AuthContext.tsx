import React, { createContext, useContext, useEffect, useState, useCallback, useRef } from 'react';
import { User, Session } from '@supabase/supabase-js';
import { supabase, isSupabaseConfigured } from '../config/supabase';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useCourseStore, ACTIVE_COURSE_STORAGE_KEY } from '@/app/store/useCourseStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { useLessonStore } from '@/app/store/useLessonStore';
import { usePlacementStore } from '@/app/store/usePlacementStore';
import { setDemoRuntimeActive } from '@/core/runtime/demoRuntime';

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
  signIn: (email: string, password: string) => Promise<{ error: Error | null; profile?: UserProfile | null }>;
  signUp: (email: string, password: string, firstName: string, lastName: string) => Promise<{ error: Error | null; requiresEmailConfirmation?: boolean }>;
  signOut: () => Promise<void>;
  resetPassword: (email: string) => Promise<{ error: Error | null }>;
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

const isSupportedRole = (role: unknown): role is NonNullable<UserProfile['role']> =>
  role === 'student' || role === 'admin';

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
  const profileRequest = useRef(0);
  const authRevision = useRef(0);
  const authAction = useRef(0);
  const activeUserId = useRef<string | null>(null);
  const pendingAuth = useRef<{ request: number; email: string; userId?: string } | null>(null);
  // Entries live only until their action settles, including canceled SDK calls.
  const authOperations = useRef(new Map<number, string>());
  const signingOut = useRef<number | null>(null);

  const clearSessionStores = useCallback(() => {
    useLearnerStore.getState().clearSession();
    useCourseStore.getState().clearSession();
    useRoadmapStore.getState().clearSession();
    useLessonStore.getState().clearSession();
    usePlacementStore.getState().resetPlacement();
    localStorage.removeItem('bilimyol_auth_session');
    localStorage.removeItem(ACTIVE_COURSE_STORAGE_KEY);
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
    setDemoRuntimeActive(false);
    clearSessionStores();
    setUser(null);
    setSession(null);
    setProfile(null);
    setIsDemoMode(false);
    setIsLoading(false);
  }, [clearSessionStores, invalidatePendingAuth]);

  const beginAuthAction = (email: string) => {
    const request = ++authAction.current;
    authRevision.current++;
    profileRequest.current++;
    setDemoRuntimeActive(false);
    pendingAuth.current = { request, email: email.toLowerCase().trim() };
    authOperations.current.set(request, pendingAuth.current.email);
    // A previous account's data must not render while another login is pending.
    if (activeUserId.current || profile) clearSessionStores();
    activeUserId.current = null;
    setUser(null);
    setSession(null);
    setProfile(null);
    setIsDemoMode(false);
    localStorage.removeItem('bilimyol_auth_session');
    setIsLoading(true);
    return request;
  };

  const staleActionError = () => new Error('Sessiya o‘zgardi. Qayta urinib ko‘ring.');

  const fetchProfile = useCallback(async (
    userId: string,
    email: string,
    options: ProfileFetchOptions = {},
  ) => {
    const request = ++profileRequest.current;
    const isCurrent = () => request === profileRequest.current;
    if (!isSupabaseConfigured) {
      const cached = localStorage.getItem('bilimyol_auth_session');
      if (cached) {
        try {
          const parsed = JSON.parse(cached);
          if (parsed.profile && isSupportedRole(parsed.profile.role)) {
            setProfile(parsed.profile);
            return parsed.profile;
          }
        } catch {}
      }
      setProfile(null);
      return null;
    }

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
        throw new Error('Profilni serverdan o‘qib bo‘lmadi. Qayta urinib ko‘ring.');
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
          throw new Error('Profilni yaratib bo‘lmadi. Qayta urinib ko‘ring.');
        }

        const { data: provisioned, error: readError } = await supabase
          .from('profiles')
          .select('id, first_name, last_name, display_name, email, avatar_url, role')
          .eq('id', userId)
          .maybeSingle();

        if (readError) {
          throw new Error('Yaratilgan profilni serverdan o‘qib bo‘lmadi. Qayta urinib ko‘ring.');
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
        localStorage.setItem('bilimyol_auth_session', JSON.stringify({ profile: userProfile }));
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
      localStorage.removeItem('bilimyol_auth_session');
      if (options.throwOnError) {
        throw err instanceof Error
          ? err
          : new Error('Profilni serverdan o‘qib bo‘lmadi. Qayta urinib ko‘ring.');
      }
      return null;
    } finally {
      if (isCurrent()) setIsLoading(false);
    }
  }, []);

  const refreshProfile = useCallback(async (): Promise<UserProfile | null> => {
    if (!isSupabaseConfigured) {
      const cached = localStorage.getItem('bilimyol_auth_session');
      if (cached) {
        try {
          const parsed = JSON.parse(cached);
          if (parsed.profile && isSupportedRole(parsed.profile.role)) {
            setProfile(parsed.profile);
            return parsed.profile;
          }
        } catch {}
      }
      return profile;
    }

    const revision = authRevision.current;
    const userId = activeUserId.current;
    if (!userId) return null;
    const { data: userData } = await supabase.auth.getUser();
    if (revision !== authRevision.current || userId !== activeUserId.current) return null;
    if (userData.user?.id === userId) {
      return await fetchProfile(userData.user.id, userData.user.email ?? '');
    }
    return null;
  }, [fetchProfile, profile]);

  useEffect(() => {
    let mounted = true;
    const startupRevision = authRevision.current;
    const isCurrentStartup = () => mounted && startupRevision === authRevision.current;

    async function initAuth() {
      try {
        if (!isSupabaseConfigured) {
          if (import.meta.env.PROD) {
            console.error('[CONFIG] Production missing Supabase configuration: VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY are required.');
            if (mounted) {
              setDemoRuntimeActive(false);
              setProfile(null);
              setIsDemoMode(false);
              setIsLoading(false);
            }
            return;
          }

          console.warn('[AUTH] Running in local development fallback mode.');
          setDemoRuntimeActive(false);
          const cached = localStorage.getItem('bilimyol_auth_session');
          if (cached) {
            try {
              const parsed = JSON.parse(cached);
              const isExplicitDemo = Boolean(parsed?.isDemoMode);
              const isDefaultDemo = parsed?.profile?.id === defaultDemoProfile.id;
              if (mounted && parsed?.profile && isSupportedRole(parsed.profile.role) && (!isDefaultDemo || isExplicitDemo)) {
                setDemoRuntimeActive(isExplicitDemo);
                setProfile(parsed.profile);
                setIsDemoMode(isExplicitDemo);
              } else if (mounted) {
                setDemoRuntimeActive(false);
                setProfile(null);
                setIsDemoMode(false);
                localStorage.removeItem('bilimyol_auth_session');
              }
            } catch {
              if (mounted) {
                setDemoRuntimeActive(false);
                setProfile(null);
                setIsDemoMode(false);
              }
            }
          } else {
            if (mounted) {
              setDemoRuntimeActive(false);
              setProfile(null);
              setIsDemoMode(false);
            }
          }
          if (mounted) setIsLoading(false);
          return;
        }

        const { data } = await supabase.auth.getSession();
        if (isCurrentStartup()) {
          activeUserId.current = data.session?.user.id ?? null;
          setSession(data.session);
          setUser(data.session?.user ?? null);
          if (data.session?.user) {
            await fetchProfile(data.session.user.id, data.session.user.email ?? '');
          } else {
            // A configured backend is authoritative for real accounts. An
            // explicit bundled demo session is the only session allowed to
            // run without Supabase auth, and its data plane is local-only.
            const cached = localStorage.getItem('bilimyol_auth_session');
            let cachedDemoProfile: UserProfile | null = null;
            if (cached) {
              try {
                const parsed = JSON.parse(cached);
                if (
                  parsed?.isDemoMode === true &&
                  parsed?.profile?.id === defaultDemoProfile.id &&
                  parsed?.profile?.role === defaultDemoProfile.role
                ) {
                  cachedDemoProfile = parsed.profile;
                }
              } catch {}
            }

            clearSessionStores();
            if (cachedDemoProfile) {
              localStorage.setItem('bilimyol_auth_session', JSON.stringify({ profile: cachedDemoProfile, isDemoMode: true }));
              setDemoRuntimeActive(true);
              setProfile(cachedDemoProfile);
              setIsDemoMode(true);
            } else {
              setDemoRuntimeActive(false);
              setProfile(null);
              setIsDemoMode(false);
            }
            setIsLoading(false);
          }
        }
      } catch (err) {
        console.warn('Auth initialization error:', err);
        if (isCurrentStartup()) {
          setDemoRuntimeActive(false);
          setProfile(null);
          setIsDemoMode(false);
          setIsLoading(false);
        }
      }
    }

    initAuth();

    if (isSupabaseConfigured) {
      const { data: authListener } = supabase.auth.onAuthStateChange((event, newSession) => {
        if (!mounted) return;
        if (event === 'INITIAL_SESSION' && startupRevision !== authRevision.current) return;
        if (event === 'INITIAL_SESSION' && !newSession?.user) {
          const cached = localStorage.getItem('bilimyol_auth_session');
          try {
            const parsed = cached ? JSON.parse(cached) : null;
            if (
              parsed?.isDemoMode === true &&
              parsed?.profile?.id === defaultDemoProfile.id &&
              parsed?.profile?.role === defaultDemoProfile.role
            ) {
              setDemoRuntimeActive(true);
              setSession(null);
              setUser(null);
              setProfile(parsed.profile);
              setIsDemoMode(true);
              setIsLoading(false);
              return;
            }
          } catch {}
        }
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
        if (changedAccount) {
          profileRequest.current++;
          if (activeUserId.current) clearSessionStores();
          setProfile(null);
        }
        activeUserId.current = newSession.user.id;
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
        setIsLoading(true);
        // Keep this callback synchronous; DB reads can need the auth session lock.
        queueMicrotask(() => {
          if (mounted && revision === authRevision.current && activeUserId.current === newSession.user.id) {
            void fetchProfile(newSession.user.id, newSession.user.email ?? '');
          }
        });
      });

      return () => {
        mounted = false;
        invalidatePendingAuth();
        authListener.subscription.unsubscribe();
      };
    }

    return () => {
      mounted = false;
      invalidatePendingAuth();
    };
  }, [clearAuthState, clearSessionStores, fetchProfile, invalidatePendingAuth]);

  const signIn = async (email: string, password: string) => {
    if (signingOut.current !== null) return { error: staleActionError() };
    if (!isSupabaseConfigured) {
      if (import.meta.env.PROD) {
        return {
          error: new Error('Server konfiguratsiyasi topilmadi. Vercel sozlamalarida VITE_SUPABASE_URL va VITE_SUPABASE_ANON_KEY parametrlarini kiriting.'),
        };
      }

      console.warn('[AUTH] Signing in via local development demo mode.');
      const demoProf: UserProfile = {
        id: 'user_' + Date.now(),
        firstName: email.split('@')[0],
        lastName: '',
        email,
        role: email.includes('admin') ? 'admin' : 'student',
      };
      setDemoRuntimeActive(true);
      setProfile(demoProf);
      setIsDemoMode(true);
      localStorage.setItem('bilimyol_auth_session', JSON.stringify({ profile: demoProf, isDemoMode: true }));
      return { error: null, profile: demoProf };
    }

    const request = beginAuthAction(email);
    try {
      const { data: authData, error } = await supabase.auth.signInWithPassword({ email, password });
      if (request !== authAction.current) return { error: staleActionError() };
      if (error || !authData.user || !authData.session) {
        return { error: error ? new Error(error.message) : new Error('Kirishda xatolik yuz berdi.') };
      }
      if (pendingAuth.current?.userId && pendingAuth.current.userId !== authData.user.id) {
        return { error: staleActionError() };
      }
      activeUserId.current = authData.user.id;
      setUser(authData.user);
      setSession(authData.session);
      const resolved = await fetchProfile(authData.user.id, authData.user.email ?? email);
      if (request !== authAction.current) return { error: staleActionError() };
      return resolved
        ? { error: null, profile: resolved }
        : { error: new Error('Profilni serverdan yuklab bo‘lmadi. Qayta urinib ko‘ring.') };
    } catch (err) {
      return { error: request !== authAction.current ? staleActionError() : err instanceof Error ? err : new Error('Kirishda xatolik yuz berdi.') };
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
    if (!isSupabaseConfigured) {
      if (import.meta.env.PROD) {
        return { error: new Error('Server konfiguratsiyasi topilmadi. VITE_SUPABASE_URL va VITE_SUPABASE_ANON_KEY sozlanishi kerak.') };
      }
      const newProf: UserProfile = {
        id: 'user_' + Date.now(),
        firstName,
        lastName,
        email,
        role: 'student',
      };
      setDemoRuntimeActive(true);
      setProfile(newProf);
      setIsDemoMode(true);
      localStorage.setItem('bilimyol_auth_session', JSON.stringify({ profile: newProf, isDemoMode: true }));
      return { error: null };
    }

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
      if (error) return { error: new Error(error.message) };
      if (!signUpData.user) return { error: new Error('Hisob yaratishda xatolik yuz berdi.') };
      if (!signUpData.session) {
        authRevision.current++;
        profileRequest.current++;
        activeUserId.current = null;
        setUser(null);
        setSession(null);
        setProfile(null);
        localStorage.removeItem('bilimyol_auth_session');
        return { error: null, requiresEmailConfirmation: true };
      }
      if (pendingAuth.current?.userId && pendingAuth.current.userId !== signUpData.user.id) {
        return { error: staleActionError() };
      }
      activeUserId.current = signUpData.user.id;
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
        : { error: new Error('Profilni serverdan yuklab bo‘lmadi. Qayta urinib ko‘ring.') };
    } catch (err) {
      return { error: request !== authAction.current ? staleActionError() : err instanceof Error ? err : new Error('Hisob yaratishda xatolik yuz berdi.') };
    } finally {
      authOperations.current.delete(request);
      if (request === authAction.current) {
        pendingAuth.current = null;
        setIsLoading(false);
      }
    }
  };

  const signOut = async () => {
    clearAuthState();
    const request = authAction.current;
    signingOut.current = request;
    try {
      if (isSupabaseConfigured) {
        await supabase.auth.signOut();
      }
    } finally {
      if (signingOut.current === request) signingOut.current = null;
    }
  };

  const resetPassword = async (email: string) => {
    if (!isSupabaseConfigured) {
      return { error: null };
    }

    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/reset-password`,
    });

    return { error: error ? new Error(error.message) : null };
  };

  const updateProfile = async (data: Partial<UserProfile>) => {
    if (!profile) return { error: new Error('Profil topilmadi') };
    if (isSupabaseConfigured && profile.id !== activeUserId.current) return { error: staleActionError() };

    const updated = {
      ...profile,
      firstName: data.firstName ?? profile.firstName,
      lastName: data.lastName ?? profile.lastName,
      avatarUrl: data.avatarUrl ?? profile.avatarUrl,
    };

    if (!isSupabaseConfigured) {
      setProfile(updated);
      localStorage.setItem('bilimyol_auth_session', JSON.stringify({ profile: updated, isDemoMode }));
      return { error: null };
    }

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

      if (error) return { error: new Error(error.message) };
      if (request !== profileRequest.current || action !== authAction.current || profile.id !== activeUserId.current) {
        return { error: staleActionError() };
      }
      setProfile(updated);
      localStorage.setItem('bilimyol_auth_session', JSON.stringify({ profile: updated, isDemoMode }));
      return { error: null };
    } catch {
      return { error: new Error('Profil serverda saqlanmadi. Qayta urinib ko‘ring.') };
    }
  };

  const setDemoUser = () => {
    clearAuthState();
    setDemoRuntimeActive(true);
    setProfile(defaultDemoProfile);
    setIsDemoMode(true);
    localStorage.setItem('bilimyol_auth_session', JSON.stringify({ profile: defaultDemoProfile, isDemoMode: true }));
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        session,
        profile,
        isLoading,
        isDemoMode,
        signIn,
        signUp,
        signOut,
        resetPassword,
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
