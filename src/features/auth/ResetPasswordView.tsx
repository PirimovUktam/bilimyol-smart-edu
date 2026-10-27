import React, { useEffect, useState } from 'react';
import { Lock, ArrowLeft, ArrowRight, CheckCircle2, AlertCircle, ShieldCheck } from 'lucide-react';
import { useAuth } from '../../core/context/AuthContext';
import { supabase, isSupabaseConfigured } from '../../core/config/supabase';
import { Button } from '../../presentation/components/Button';
import { AuthLayout } from './AuthLayout';

interface ResetPasswordViewProps {
  onNavigateLogin: () => void;
}

/**
 * Completes the emailed password-reset flow. Supabase's recovery link lands
 * here with a recovery session (detectSessionInUrl exchanges the token); we
 * verify a session is present, then call updateUser({ password }).
 */
export const ResetPasswordView: React.FC<ResetPasswordViewProps> = ({
  onNavigateLogin,
}) => {
  const { updatePassword, signOut } = useAuth();
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [isDone, setIsDone] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [sessionReady, setSessionReady] = useState<boolean | null>(null);

  // The recovery link carries an access_token; detectSessionInUrl exchanges it
  // for a session. Wait for that session before enabling the form.
  useEffect(() => {
    let mounted = true;
    if (!isSupabaseConfigured) {
      setSessionReady(true);
      return;
    }
    supabase.auth.getSession().then(({ data }) => {
      if (mounted) setSessionReady(Boolean(data.session));
    });
    const { data: sub } = supabase.auth.onAuthStateChange((event, session) => {
      if (!mounted) return;
      if (event === 'PASSWORD_RECOVERY' || session) setSessionReady(Boolean(session));
    });
    return () => {
      mounted = false;
      sub.subscription.unsubscribe();
    };
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg(null);
    if (password.trim().length < 6) {
      setErrorMsg('Parol kamida 6 ta belgidan iborat bo‘lishi lozim.');
      return;
    }
    if (password !== confirmPassword) {
      setErrorMsg('Kiritilgan parollar bir-biriga mos kelmadi.');
      return;
    }
    setIsSubmitting(true);
    const { error } = await updatePassword(password);
    setIsSubmitting(false);
    if (error) {
      setErrorMsg(error.message || 'Parolni yangilab bo‘lmadi. Havola eskirgan bo‘lishi mumkin — qaytadan so‘rang.');
    } else {
      setIsDone(true);
    }
  };

  const expiredOrMissing = sessionReady === false;

  return (
    <AuthLayout
      title="Yangi parol o‘rnating"
      subtitle="Hisobingiz uchun yangi xavfsiz parol kiriting"
    >
          {sessionReady === null && (
            <div className="py-8 text-center">
              <div className="w-8 h-8 border-4 border-brand border-t-transparent rounded-full animate-spin mx-auto" />
              <p className="text-xs text-slate-500 mt-3">Tiklash havolasi tekshirilmoqda...</p>
            </div>
          )}

          {expiredOrMissing && !isDone && (
            <div className="text-center py-4 space-y-4">
              <div className="w-12 h-12 bg-amber-100 rounded-full flex items-center justify-center mx-auto text-amber-600">
                <AlertCircle className="w-6 h-6" />
              </div>
              <div>
                <h3 className="text-base font-bold text-slate-900">Havola eskirgan</h3>
                <p className="text-xs text-slate-600 mt-1">
                  Bu tiklash havolasi ishlatilgan yoki muddati o‘tgan. Iltimos, yangi havola so‘rang.
                </p>
              </div>
              <Button
                variant="primary"
                size="md"
                className="w-full"
                onClick={onNavigateLogin}
                leftIcon={<ArrowLeft className="w-4 h-4" />}
              >
                Kirish sahifasiga qaytish
              </Button>
            </div>
          )}

          {isDone && (
            <div className="text-center py-4 space-y-4">
              <div className="w-12 h-12 bg-mint/10 rounded-full flex items-center justify-center mx-auto text-mint">
                <CheckCircle2 className="w-6 h-6" />
              </div>
              <div>
                <h3 className="text-base font-bold text-slate-900">Parol yangilandi!</h3>
                <p className="text-xs text-slate-600 mt-1">
                  Endi yangi parolingiz bilan tizimga kirishingiz mumkin.
                </p>
              </div>
              <Button
                variant="primary"
                size="md"
                className="w-full"
                onClick={async () => {
                  await signOut();
                  onNavigateLogin();
                }}
                leftIcon={<ArrowRight className="w-4 h-4" />}
              >
                Kirish sahifasiga o‘tish
              </Button>
            </div>
          )}

          {sessionReady === true && !isDone && (
            <form onSubmit={handleSubmit} className="space-y-4">
              {errorMsg && (
                <div className="p-3.5 bg-coral/5 border border-coral/25 rounded-xl flex items-start gap-2.5 text-coral text-xs font-semibold">
                  <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
                  <span>{errorMsg}</span>
                </div>
              )}

              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                  Yangi parol
                </label>
                <div className="relative">
                  <Lock className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                  <input
                    type="password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="Kamida 6 belgi"
                    className="w-full pl-10 pr-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-900 focus:bg-white focus:border-blue-600 focus:ring-2 focus:ring-blue-100 outline-none transition-all"
                    required
                    minLength={6}
                    autoComplete="new-password"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                  Parolni takrorlang
                </label>
                <div className="relative">
                  <Lock className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                  <input
                    type="password"
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    placeholder="Parolni qayta kiriting"
                    className="w-full pl-10 pr-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-900 focus:bg-white focus:border-blue-600 focus:ring-2 focus:ring-blue-100 outline-none transition-all"
                    required
                    minLength={6}
                    autoComplete="new-password"
                  />
                </div>
              </div>

              <div className="p-3 bg-blue-50/70 rounded-xl border border-blue-100 text-xs text-blue-800 flex items-start gap-2">
                <ShieldCheck className="w-4 h-4 text-blue-600 shrink-0 mt-0.5" />
                <span>Kuchli parol tanlang: kamida 6 belgi, harflar va raqamlar aralash.</span>
              </div>

              <Button
                type="submit"
                variant="primary"
                size="lg"
                className="w-full mt-2"
                isLoading={isSubmitting}
                rightIcon={<CheckCircle2 className="w-4 h-4" />}
              >
                Parolni saqlash
              </Button>

              <Button
                type="button"
                variant="ghost"
                size="sm"
                className="w-full text-slate-600 hover:text-slate-900"
                onClick={onNavigateLogin}
                leftIcon={<ArrowLeft className="w-4 h-4" />}
              >
                Bekor qilish
              </Button>
            </form>
          )}
    </AuthLayout>
  );
};
