import React, { useState } from 'react';
import { Mail, Lock, User, ArrowRight, AlertCircle, CheckCircle2 } from 'lucide-react';
import { useAuth } from '../../core/context/AuthContext';
import { Button } from '../../presentation/components/Button';
import { AuthLayout } from './AuthLayout';

interface RegisterViewProps {
  onSuccess: () => void;
  onNavigateLogin: () => void;
}

export const RegisterView: React.FC<RegisterViewProps> = ({
  onSuccess,
  onNavigateLogin,
}) => {
  const { signUp, refreshProfile } = useAuth();

  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);
  const [confirmationEmail, setConfirmationEmail] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg(null);
    setSuccessMsg(null);

    if (!firstName.trim() || !email.trim() || !password.trim()) {
      setErrorMsg('Iltimos, barcha majburiy maydonlarni to‘ldiring.');
      return;
    }

    if (password.length < 6) {
      setErrorMsg('Parol kamida 6 ta belgidan iborat bo‘lishi lozim.');
      return;
    }

    if (password !== confirmPassword) {
      setErrorMsg('Kiritilgan parollar bir-biriga mos kelmadi.');
      return;
    }

    setIsSubmitting(true);
    try {
      // The server provisions the initial role; form metadata is not authority.
      const { error, requiresEmailConfirmation } = await signUp(
        email.trim(),
        password,
        firstName.trim(),
        lastName.trim()
      );

      if (error) {
        console.error('[AUTH] Registration error:', error);
        let userFacingError = error.message || 'Ro‘yxatdan o‘tishda xatolik yuz berdi.';
        if (userFacingError.includes('Database error saving new user') || userFacingError.includes('unexpected_failure')) {
          userFacingError = 'Akkount yaratishda muammo yuz berdi. Iltimos, ma’lumotlarni tekshirib qaytadan urinib ko‘ring.';
        } else if (userFacingError.includes('User already registered')) {
          userFacingError = 'Ushbu email bilan foydalanuvchi allaqachon mavjud. Kirish sahifasiga o‘ting.';
        }
        setErrorMsg(userFacingError);
        setIsSubmitting(false);
        return;
      }

      if (requiresEmailConfirmation) {
        setConfirmationEmail(email.trim());
        return;
      }

      const refreshed = await refreshProfile();
      if (!refreshed) {
        setErrorMsg('Profilni serverdan yuklab bo‘lmadi. Qayta tizimga kiring.');
        return;
      }
      setSuccessMsg('Hisob muvaffaqiyatli yaratildi! Tizimga yo‘naltirilmoqda...');

      onSuccess();
    } catch (err: unknown) {
      console.error('[AUTH] Unexpected registration catch:', err);
      setErrorMsg(err instanceof Error ? err.message : 'Ro‘yxatdan o‘tishda kutilmagan xatolik.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <AuthLayout
      title="Hisob yaratish"
      subtitle="BilimYo‘l platformasida o‘quvchi hisobingizni yarating"
    >
      {confirmationEmail ? (
            <div role="status" className="space-y-3 text-center py-2">
              <Mail className="w-10 h-10 mx-auto text-blue-600" />
              <h2 className="text-lg font-bold text-slate-900">Email manzilingizni tasdiqlang</h2>
              <p className="text-sm text-slate-600">
                <strong>{confirmationEmail}</strong> manziliga tasdiqlash havolasi yuborildi.
                Emaildagi havolani oching, so‘ng tizimga kiring.
              </p>
            </div>
          ) : (
          <form onSubmit={handleRegister} className="space-y-4">
            {errorMsg && (
              <div className="p-3.5 bg-coral/5 border border-coral/25 rounded-xl flex items-start gap-2.5 text-coral text-xs font-semibold">
                <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
                <span>{errorMsg}</span>
              </div>
            )}

            {successMsg && (
              <div className="p-3.5 bg-mint/10 border border-mint/25 rounded-xl flex items-start gap-2.5 text-mint text-xs font-semibold">
                <CheckCircle2 className="w-4 h-4 shrink-0 mt-0.5" />
                <span>{successMsg}</span>
              </div>
            )}

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
                  Ismingiz *
                </label>
                <div className="relative">
                  <User className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
                  <input
                    type="text"
                    value={firstName}
                    onChange={(e) => setFirstName(e.target.value)}
                    placeholder="Ismingiz"
                    className="w-full pl-9 pr-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-900 focus:bg-white focus:border-blue-600 focus:ring-2 focus:ring-blue-100 outline-none transition-all"
                    required
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
                  Familiyangiz
                </label>
                <input
                  type="text"
                  value={lastName}
                  onChange={(e) => setLastName(e.target.value)}
                  placeholder="Familiyangiz"
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-900 focus:bg-white focus:border-blue-600 focus:ring-2 focus:ring-blue-100 outline-none transition-all"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
                Email manzilingiz *
              </label>
              <div className="relative">
                <Mail className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="nomingiz@misol.uz"
                  className="w-full pl-10 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-900 focus:bg-white focus:border-blue-600 focus:ring-2 focus:ring-blue-100 outline-none transition-all"
                  required
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
                Parol *
              </label>
              <div className="relative">
                <Lock className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Kamida 6 belgi"
                  className="w-full pl-10 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-900 focus:bg-white focus:border-blue-600 focus:ring-2 focus:ring-blue-100 outline-none transition-all"
                  required
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
                Parolni takrorlang *
              </label>
              <div className="relative">
                <Lock className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                <input
                  type="password"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  placeholder="Parolni qayta kiriting"
                  className="w-full pl-10 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-900 focus:bg-white focus:border-blue-600 focus:ring-2 focus:ring-blue-100 outline-none transition-all"
                  required
                />
              </div>
            </div>

            <Button
              type="submit"
              variant="primary"
              className="w-full mt-2"
              isLoading={isSubmitting}
            >
              <span>Ro‘yxatdan o‘tish</span>
              <ArrowRight className="w-4 h-4 ml-1.5" />
            </Button>
          </form>
          )}

          <div className="mt-6 pt-5 border-t border-slate-100 text-center">
            <p className="text-xs text-slate-500">
              Hisobingiz bormi?{' '}
              <button
                type="button"
                onClick={onNavigateLogin}
                className="font-bold text-blue-600 hover:text-blue-700 transition-colors cursor-pointer"
              >
                Kirish
              </button>
            </p>
          </div>
    </AuthLayout>
  );
};
