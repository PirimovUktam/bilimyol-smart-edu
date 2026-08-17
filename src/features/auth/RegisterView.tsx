import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { Mail, Lock, User, ArrowRight, AlertCircle, CheckCircle2, GraduationCap, Users, BookOpen, KeyRound } from 'lucide-react';
import { useAuth } from '../../core/context/AuthContext';
import { useMonitoringStore } from '../../app/store/useMonitoringStore';
import { BilimYolLogo } from '../../presentation/components/BilimYolLogo';
import { Button } from '../../presentation/components/Button';
import { Card } from '../../presentation/components/Card';

interface RegisterViewProps {
  onSuccess: () => void;
  onNavigateLogin: () => void;
}

export const RegisterView: React.FC<RegisterViewProps> = ({
  onSuccess,
  onNavigateLogin,
}) => {
  const { signUp } = useAuth();
  const { redeemTeacherInvitationCode } = useMonitoringStore();

  const [role, setRole] = useState<'student' | 'parent' | 'teacher'>('student');
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [teacherCode, setTeacherCode] = useState('');
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);
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

    if (role === 'teacher' && !teacherCode.trim()) {
      setErrorMsg('O‘qituvchi sifatida ro‘yxatdan o‘tish uchun tasdiqlash kodini kiritish majburiy.');
      return;
    }

    setIsSubmitting(true);
    try {
      // 1. Initial secure registration (Parent or Student)
      const { error } = await signUp(
        email.trim(),
        password,
        firstName.trim(),
        lastName.trim(),
        role === 'parent' ? 'parent' : 'student'
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

      // 2. If Teacher, perform server-side token validation & role upgrade
      if (role === 'teacher') {
        const teacherRes = await redeemTeacherInvitationCode(teacherCode.trim());
        if (!teacherRes.success) {
          setErrorMsg(teacherRes.message || 'O‘qituvchi tasdiqlash kodi noto‘g‘ri yoki muddati o‘tgan.');
          setIsSubmitting(false);
          return;
        }
        setSuccessMsg(`Hisob tasdiqlandi (${teacherRes.schoolName || 'O‘qituvchi'}). Yo‘naltirilmoqda...`);
      } else {
        setSuccessMsg('Hisob muvaffaqiyatli yaratildi! Tizimga yo‘naltirilmoqda...');
      }

      setTimeout(() => {
        onSuccess();
      }, 1000);
    } catch (err: unknown) {
      console.error('[AUTH] Unexpected registration catch:', err);
      setErrorMsg(err instanceof Error ? err.message : 'Ro‘yxatdan o‘tishda kutilmagan xatolik.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="min-h-[calc(100vh-140px)] flex items-center justify-center px-4 py-8">
      <motion.div
        initial={{ opacity: 0, y: 15 }}
        animate={{ opacity: 1, y: 0 }}
        className="max-w-md w-full"
      >
        <div className="text-center mb-6">
          <div className="flex justify-center mb-3">
            <BilimYolLogo size="lg" />
          </div>
          <h1 className="text-2xl font-extrabold text-slate-900">
            Hisob yaratish
          </h1>
          <p className="text-sm text-slate-500 mt-1">
            BilimYo‘l platformasida hisob turini tanlang va boshlang
          </p>
        </div>

        <Card className="p-7 shadow-xl border-slate-200">
          <form onSubmit={handleRegister} className="space-y-4">
            {errorMsg && (
              <div className="p-3.5 bg-rose-50 border border-rose-200 rounded-xl flex items-start gap-2.5 text-rose-700 text-xs font-semibold">
                <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
                <span>{errorMsg}</span>
              </div>
            )}

            {successMsg && (
              <div className="p-3.5 bg-emerald-50 border border-emerald-200 rounded-xl flex items-start gap-2.5 text-emerald-700 text-xs font-semibold">
                <CheckCircle2 className="w-4 h-4 shrink-0 mt-0.5" />
                <span>{successMsg}</span>
              </div>
            )}

            {/* Role Selection */}
            <div>
              <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-2">
                Hisob turi *
              </label>
              <div className="grid grid-cols-3 gap-2">
                <button
                  type="button"
                  onClick={() => setRole('student')}
                  className={`p-2.5 rounded-xl border flex flex-col items-center gap-1.5 transition-all text-xs font-semibold cursor-pointer ${
                    role === 'student'
                      ? 'bg-blue-50 border-blue-600 text-blue-700 shadow-sm ring-1 ring-blue-600'
                      : 'bg-slate-50 border-slate-200 text-slate-600 hover:bg-slate-100'
                  }`}
                >
                  <BookOpen className="w-4 h-4" />
                  <span>O‘quvchi</span>
                </button>

                <button
                  type="button"
                  onClick={() => setRole('parent')}
                  className={`p-2.5 rounded-xl border flex flex-col items-center gap-1.5 transition-all text-xs font-semibold cursor-pointer ${
                    role === 'parent'
                      ? 'bg-emerald-50 border-emerald-600 text-emerald-700 shadow-sm ring-1 ring-emerald-600'
                      : 'bg-slate-50 border-slate-200 text-slate-600 hover:bg-slate-100'
                  }`}
                >
                  <Users className="w-4 h-4" />
                  <span>Ota-ona</span>
                </button>

                <button
                  type="button"
                  onClick={() => setRole('teacher')}
                  className={`p-2.5 rounded-xl border flex flex-col items-center gap-1.5 transition-all text-xs font-semibold cursor-pointer ${
                    role === 'teacher'
                      ? 'bg-indigo-50 border-indigo-600 text-indigo-700 shadow-sm ring-1 ring-indigo-600'
                      : 'bg-slate-50 border-slate-200 text-slate-600 hover:bg-slate-100'
                  }`}
                >
                  <GraduationCap className="w-4 h-4" />
                  <span>O‘qituvchi</span>
                </button>
              </div>
            </div>

            {/* Teacher Verification Code field if role is teacher */}
            {role === 'teacher' && (
              <motion.div
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: 'auto' }}
                className="p-3.5 bg-indigo-50/70 border border-indigo-200 rounded-xl space-y-2"
              >
                <div className="flex items-center gap-2 text-indigo-900 text-xs font-bold">
                  <KeyRound className="w-4 h-4 text-indigo-600" />
                  <span>O‘qituvchi Tasdiqlash Kodi *</span>
                </div>
                <input
                  type="text"
                  placeholder="Masalan: USTOZ-2026-ALPHA"
                  value={teacherCode}
                  onChange={(e) => setTeacherCode(e.target.value.toUpperCase())}
                  className="w-full px-3 py-2 bg-white border border-indigo-300 rounded-lg text-xs font-mono uppercase text-indigo-950 focus:ring-2 focus:ring-indigo-500 outline-none"
                  required
                />
                <p className="text-[11px] text-indigo-700">
                  Maktab ma’muriyati yoki BilimYo‘l markazi tomonidan berilgan maxsus o‘qituvchi kodini kiriting.
                </p>
              </motion.div>
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
        </Card>
      </motion.div>
    </div>
  );
};
