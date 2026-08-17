import React, { createContext, useContext, useEffect, useState, useCallback } from 'react';
import { User, Session } from '@supabase/supabase-js';
import { supabase, isSupabaseConfigured } from '../config/supabase';

export interface UserProfile {
  id: string;
  firstName: string;
  lastName: string;
  email: string;
  avatarUrl?: string;
  role?: 'student' | 'parent' | 'teacher';
}

interface AuthContextType {
  user: User | null;
  session: Session | null;
  profile: UserProfile | null;
  isLoading: boolean;
  isDemoMode: boolean;
  signIn: (email: string, password: string) => Promise<{ error: Error | null }>;
  signUp: (email: string, password: string, firstName: string, lastName: string, role?: 'student' | 'parent' | 'teacher') => Promise<{ error: Error | null }>;
  signOut: () => Promise<void>;
  resetPassword: (email: string) => Promise<{ error: Error | null }>;
  updateProfile: (data: Partial<UserProfile>) => Promise<{ error: Error | null }>;
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
  const [isDemoMode, setIsDemoMode] = useState<boolean>(!isSupabaseConfigured);

  const fetchProfile = useCallback(async (userId: string, email: string) => {
    try {
      const { data } = await supabase
        .from('profiles')
        .select('id, first_name, last_name, display_name, email, avatar_url, role')
        .eq('id', userId)
        .maybeSingle();

      const userRole = (data?.role as 'student' | 'parent' | 'teacher') || 'student';

      if (data && data.first_name && data.first_name !== 'Foydalanuvchi') {
        setProfile({
          id: data.id,
          firstName: data.first_name,
          lastName: data.last_name || '',
          email: data.email || email,
          avatarUrl: data.avatar_url || '',
          role: userRole,
        });
      } else {
        // Check user_metadata if profile row is missing or default
        const { data: userData } = await supabase.auth.getUser();
        const metaFirst = (userData.user?.user_metadata?.first_name || '').trim();
        const metaLast = (userData.user?.user_metadata?.last_name || '').trim();
        const metaRole = (userData.user?.user_metadata?.role as 'student' | 'parent' | 'teacher') || userRole;
        const resolvedFirst = data?.first_name || metaFirst || (email ? email.split('@')[0] : 'Foydalanuvchi');
        const resolvedLast = data?.last_name || metaLast || '';
        const resolvedDisplay = resolvedLast ? `${resolvedFirst} ${resolvedLast}` : resolvedFirst;

        // Auto-provision public.profiles row
        await supabase
          .from('profiles')
          .upsert({
            id: userId,
            first_name: resolvedFirst,
            last_name: resolvedLast,
            display_name: resolvedDisplay,
            email: email || userData.user?.email || '',
            avatar_url: data?.avatar_url || userData.user?.user_metadata?.avatar_url || null,
            role: metaRole,
            updated_at: new Date().toISOString(),
          });

        setProfile({
          id: userId,
          firstName: resolvedFirst,
          lastName: resolvedLast,
          email: email || userData.user?.email || '',
          avatarUrl: data?.avatar_url || '',
          role: metaRole,
        });
      }
    } catch (err) {
      console.warn('Error resolving authenticated profile from Supabase:', err);
      setProfile({
        id: userId,
        firstName: email ? email.split('@')[0] : 'Foydalanuvchi',
        lastName: '',
        email,
        role: 'student',
      });
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    let mounted = true;

    async function initAuth() {
      try {
        if (!isSupabaseConfigured) {
          const cached = localStorage.getItem('bilimyol_auth_session');
          if (cached) {
            const parsed = JSON.parse(cached);
            if (mounted) {
              setProfile(parsed.profile);
              setIsDemoMode(true);
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
        console.warn('Auth initialization error, using local fallback:', err);
        if (mounted) {
          setProfile(defaultDemoProfile);
          setIsDemoMode(true);
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
      const demoProf: UserProfile = {
        id: 'user_' + Date.now(),
        firstName: email.split('@')[0],
        lastName: '',
        email,
      };
      setProfile(demoProf);
      setIsDemoMode(true);
      localStorage.setItem('bilimyol_auth_session', JSON.stringify({ profile: demoProf }));
      return { error: null };
    }

    setIsLoading(true);
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    setIsLoading(false);
    return { error: error ? new Error(error.message) : null };
  };

  const signUp = async (
    email: string,
    password: string,
    firstName: string,
    lastName: string,
    role: 'student' | 'parent' | 'teacher' = 'student'
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
      const displayName = lastName ? `${firstName} ${lastName}` : firstName;
      // Proactively ensure public.profiles record exists immediately
      try {
        await supabase.from('profiles').upsert({
          id: signUpData.user.id,
          first_name: firstName,
          last_name: lastName,
          display_name: displayName,
          email,
          role,
          updated_at: new Date().toISOString(),
        });
      } catch (err) {
        console.warn('Could not pre-insert public.profiles, trigger will handle it:', err);
      }

      setProfile({
        id: signUpData.user.id,
        firstName,
        lastName,
        email,
        role,
      });
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
  };

  const resetPassword = async (email: string) => {
    if (!isSupabaseConfigured) {
      return { error: null };
    }
    const { error } = await supabase.auth.resetPasswordForEmail(email);
    return { error: error ? new Error(error.message) : null };
  };

  const updateProfile = async (data: Partial<UserProfile>) => {
    if (!profile) return { error: new Error('Foydalanuvchi topilmadi') };

    const updated = { ...profile, ...data };
    setProfile(updated);

    if (isSupabaseConfigured && user) {
      const displayName = updated.lastName ? `${updated.firstName} ${updated.lastName}` : updated.firstName;
      const { error } = await supabase
        .from('profiles')
        .upsert({
          id: user.id,
          first_name: updated.firstName,
          last_name: updated.lastName,
          display_name: displayName,
          avatar_url: updated.avatarUrl,
          updated_at: new Date().toISOString(),
        });

      if (error) return { error: new Error(error.message) };
    } else {
      localStorage.setItem('bilimyol_auth_session', JSON.stringify({ profile: updated }));
    }

    return { error: null };
  };

  const setDemoUser = () => {
    setProfile(defaultDemoProfile);
    setIsDemoMode(true);
    localStorage.setItem('bilimyol_auth_session', JSON.stringify({ profile: defaultDemoProfile }));
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
