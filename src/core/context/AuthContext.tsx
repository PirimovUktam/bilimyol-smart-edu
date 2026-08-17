import React, { createContext, useContext, useEffect, useState, useCallback } from 'react';
import { User, Session } from '@supabase/supabase-js';
import { supabase, isSupabaseConfigured } from '../config/supabase';
import { useMonitoringStore } from '@/app/store/useMonitoringStore';

export interface UserProfile {
  id: string;
  firstName: string;
  lastName: string;
  email: string;
  avatarUrl?: string;
  role?: 'student' | 'parent' | 'teacher' | 'admin';
}

interface AuthContextType {
  user: User | null;
  session: Session | null;
  profile: UserProfile | null;
  isLoading: boolean;
  isDemoMode: boolean;
  signIn: (email: string, password: string) => Promise<{ error: Error | null; profile?: UserProfile | null }>;
  signUp: (email: string, password: string, firstName: string, lastName: string, role?: 'student' | 'parent' | 'teacher' | 'admin') => Promise<{ error: Error | null }>;
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

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [isDemoMode, setIsDemoMode] = useState<boolean>(false);

  const fetchProfile = useCallback(async (userId: string, email: string) => {
    if (!isSupabaseConfigured) {
      const cached = localStorage.getItem('bilimyol_auth_session');
      if (cached) {
        try {
          const parsed = JSON.parse(cached);
          if (parsed.profile) {
            setProfile(parsed.profile);
            useMonitoringStore.setState({ currentRole: (parsed.profile.role as any) || 'student' });
            return parsed.profile;
          }
        } catch {}
      }
      setProfile(defaultDemoProfile);
      return defaultDemoProfile;
    }

    try {
      // Query authoritative public.profiles
      const { data, error } = await supabase
        .from('profiles')
        .select('id, first_name, last_name, display_name, email, avatar_url, role')
        .eq('id', userId)
        .maybeSingle();

      if (error) {
        console.warn('Error querying public.profiles in AuthContext:', error);
      }

      if (data) {
        // Authoritative role from public.profiles
        const userRole = (data.role as UserProfile['role']) || 'student';
        const resolvedFirst = data.first_name || (email ? email.split('@')[0] : 'Foydalanuvchi');
        const userProfile: UserProfile = {
          id: data.id,
          firstName: resolvedFirst,
          lastName: data.last_name || '',
          email: data.email || email,
          avatarUrl: data.avatar_url || '',
          role: userRole,
        };

        console.log('[AUTH] Loaded authoritative public.profiles record:', {
          userId,
          email,
          databaseRole: data.role,
          resolvedRole: userRole,
        });

        setProfile(userProfile);
        localStorage.setItem('bilimyol_auth_session', JSON.stringify({ profile: userProfile }));
        useMonitoringStore.setState({ currentRole: userRole as any });
        return userProfile;
      }

      // If no row exists yet in public.profiles (e.g. fresh signup before trigger)
      const { data: userData } = await supabase.auth.getUser();
      const metaFirst = (userData.user?.user_metadata?.first_name || '').trim();
      const metaLast = (userData.user?.user_metadata?.last_name || '').trim();
      const metaRole = (userData.user?.user_metadata?.role as UserProfile['role']) || 'student';
      const resolvedFirst = metaFirst || (email ? email.split('@')[0] : 'Foydalanuvchi');
      const resolvedLast = metaLast || '';

      const userProfile: UserProfile = {
        id: userId,
        firstName: resolvedFirst,
        lastName: resolvedLast,
        email: email || userData.user?.email || '',
        avatarUrl: userData.user?.user_metadata?.avatar_url || '',
        role: metaRole,
      };

      setProfile(userProfile);
      localStorage.setItem('bilimyol_auth_session', JSON.stringify({ profile: userProfile }));
      useMonitoringStore.setState({ currentRole: metaRole as any });
      return userProfile;
    } catch (err) {
      console.warn('Error resolving authenticated profile from Supabase:', err);
      const fallback: UserProfile = {
        id: userId,
        firstName: email ? email.split('@')[0] : 'Foydalanuvchi',
        lastName: '',
        email,
        role: 'student',
      };
      setProfile(fallback);
      return fallback;
    } finally {
      setIsLoading(false);
    }
  }, []);

  const refreshProfile = useCallback(async (): Promise<UserProfile | null> => {
    if (!isSupabaseConfigured) {
      const cached = localStorage.getItem('bilimyol_auth_session');
      if (cached) {
        try {
          const parsed = JSON.parse(cached);
          if (parsed.profile) {
            setProfile(parsed.profile);
            useMonitoringStore.setState({ currentRole: (parsed.profile.role as any) || 'student' });
            return parsed.profile;
          }
        } catch {}
      }
      return profile;
    }

    const { data: userData } = await supabase.auth.getUser();
    if (userData.user) {
      return await fetchProfile(userData.user.id, userData.user.email ?? '');
    }
    return null;
  }, [fetchProfile, profile]);

  useEffect(() => {
    let mounted = true;

    async function initAuth() {
      try {
        if (!isSupabaseConfigured) {
          if (import.meta.env.PROD) {
            console.error('[CONFIG] Production missing Supabase configuration: VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY are required.');
            if (mounted) {
              setProfile(null);
              setIsDemoMode(false);
              setIsLoading(false);
            }
            return;
          }

          console.warn('[AUTH] Running in local development fallback mode.');
          const cached = localStorage.getItem('bilimyol_auth_session');
          if (cached) {
            const parsed = JSON.parse(cached);
            if (mounted) {
              setProfile(parsed.profile);
              setIsDemoMode(true);
              useMonitoringStore.setState({ currentRole: (parsed?.profile?.role as any) || 'student' });
            }
          } else {
            if (mounted) {
              setProfile(defaultDemoProfile);
              setIsDemoMode(true);
            }
          }
          if (mounted) setIsLoading(false);
          return;
        }

        const { data } = await supabase.auth.getSession();
        if (mounted) {
          setSession(data.session);
          setUser(data.session?.user ?? null);
          if (data.session?.user) {
            await fetchProfile(data.session.user.id, data.session.user.email ?? '');
          } else {
            setIsLoading(false);
          }
        }
      } catch (err) {
        console.warn('Auth initialization error:', err);
        if (mounted) {
          if (import.meta.env.PROD) {
            setProfile(null);
            setIsDemoMode(false);
          } else {
            setProfile(defaultDemoProfile);
            setIsDemoMode(true);
          }
          setIsLoading(false);
        }
      }
    }

    initAuth();

    if (isSupabaseConfigured) {
      const { data: authListener } = supabase.auth.onAuthStateChange(async (_event, newSession) => {
        if (!mounted) return;
        setSession(newSession);
        setUser(newSession?.user ?? null);
        if (newSession?.user) {
          await fetchProfile(newSession.user.id, newSession.user.email ?? '');
        } else {
          setProfile(null);
          setIsLoading(false);
        }
      });

      return () => {
        mounted = false;
        authListener.subscription.unsubscribe();
      };
    }

    return () => {
      mounted = false;
    };
  }, [fetchProfile]);

  const signIn = async (email: string, password: string) => {
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
        role: email.includes('admin') ? 'admin' : email.includes('parent') ? 'parent' : email.includes('teacher') ? 'teacher' : 'student',
      };
      setProfile(demoProf);
      setIsDemoMode(true);
      localStorage.setItem('bilimyol_auth_session', JSON.stringify({ profile: demoProf }));
      useMonitoringStore.setState({ currentRole: demoProf.role as any });
      return { error: null, profile: demoProf };
    }

    setIsLoading(true);
    const { data: authData, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error || !authData.user) {
      setIsLoading(false);
      return { error: error ? new Error(error.message) : new Error('Kirishda xatolik yuz berdi.') };
    }

    const resolved = await fetchProfile(authData.user.id, authData.user.email ?? email);
    setIsLoading(false);
    return { error: null, profile: resolved };
  };

  const signUp = async (
    email: string,
    password: string,
    firstName: string,
    lastName: string,
    role: 'student' | 'parent' | 'teacher' | 'admin' = 'student'
  ) => {
    if (!isSupabaseConfigured) {
      const newProf: UserProfile = {
        id: 'user_' + Date.now(),
        firstName,
        lastName,
        email,
        role,
      };
      setProfile(newProf);
      setIsDemoMode(true);
      localStorage.setItem('bilimyol_auth_session', JSON.stringify({ profile: newProf }));
      useMonitoringStore.setState({ currentRole: role as any });
      return { error: null };
    }

    setIsLoading(true);
    const { data: signUpData, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          first_name: firstName,
          last_name: lastName,
          role,
        },
      },
    });

    if (error) {
      setIsLoading(false);
      return { error: new Error(error.message) };
    }

    if (signUpData.user) {
      const initialProf: UserProfile = {
        id: signUpData.user.id,
        firstName,
        lastName,
        email,
        role,
      };
      setProfile(initialProf);
      localStorage.setItem('bilimyol_auth_session', JSON.stringify({ profile: initialProf }));
      useMonitoringStore.setState({ currentRole: role as any });
    }

    setIsLoading(false);
    return { error: null };
  };

  const signOut = async () => {
    if (isSupabaseConfigured) {
      await supabase.auth.signOut();
    }
    localStorage.removeItem('bilimyol_auth_session');
    setUser(null);
    setSession(null);
    setProfile(null);
    useMonitoringStore.getState().resetAll();
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

    const updated = { ...profile, ...data };
    setProfile(updated);
    localStorage.setItem('bilimyol_auth_session', JSON.stringify({ profile: updated }));

    if (!isSupabaseConfigured) {
      return { error: null };
    }

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

    return { error: error ? new Error(error.message) : null };
  };

  const setDemoUser = () => {
    setProfile(defaultDemoProfile);
    setIsDemoMode(true);
    localStorage.setItem('bilimyol_auth_session', JSON.stringify({ profile: defaultDemoProfile }));
    useMonitoringStore.setState({ currentRole: 'student' });
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
