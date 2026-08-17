import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { Mail, Lock, ArrowRight, AlertCircle, Sparkles } from 'lucide-react';
import { useAuth } from '../../core/context/AuthContext';
import { BilimYolLogo } from '../../presentation/components/BilimYolLogo';
import { Button } from '../../presentation/components/Button';
import { Card } from '../../presentation/components/Card';

interface LoginViewProps {
  onSuccess: (role?: 'student' | 'parent' | 'teacher' | 'admin') => void;
  onNavigateRegister: () => void;
  onNavigateForgotPassword: () => void;
}

export const LoginView: React.FC<LoginViewProps> = ({
  onSuccess,
  onNavigateRegister,
  onNavigateForgotPassword,
}) => {
  const { signIn, setDemoUser } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg(null);

    if (!email.trim() || !password.trim()) {
      setErrorMsg('Iltimos, email va parolni to‘liq kiriting.');
      return;
    }

    setIsSubmitting(true);
    const { error, profile: loggedProfile } = await signIn(email.trim(), password);
    setIsSubmitting(false);

    if (error) {
      setErrorMsg(error.message || 'Email yoki parol noto‘g‘ri kiritildi. Iltimos, qaytadan urinib ko‘ring.');
    } else {
      onSuccess(loggedProfile?.role);
    }
  };

  const handleQuickDemo = () => {
    setDemoUser();
    onSuccess();
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
            Xush kelibsiz!
          </h1>
          <p className="text-sm text-slate-500 mt-1">
            Shaxsiy ta’lim yo‘lingizni davom ettirish uchun tizimga kiring
          </p>
        </div>

        <Card className="p-7 shadow-xl border-slate-200">
          <form onSubmit={handleLogin} className="space-y-4">
            {errorMsg && (
              <div className="p-3.5 bg-rose-50 border border-rose-200 rounded-xl flex items-start gap-2.5 text-rose-700 text-xs font-semibold">
                <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
                <span>{errorMsg}</span>
              </div>
            )}

            <div>
              <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                Email manzilingiz
              </label>
              <div className="relative">
                <Mail className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="nomingiz@misol.uz"
                  className="w-full pl-10 pr-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-900 focus:bg-white focus:border-blue-600 focus:ring-2 focus:ring-blue-100 outline-none transition-all"
                  required
                />
              </div>
            </div>

            <div>
              <div className="flex items-center justify-between mb-1.5">
                <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider">
                  Parol
                </label>
                <button
                  type="button"
                  onClick={onNavigateForgotPassword}
                  className="text-xs font-bold text-blue-600 hover:text-blue-700"
                >
                  Parolni unutdingizmi?
                </button>
              </div>
              <div className="relative">
                <Lock className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  className="w-full pl-10 pr-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-900 focus:bg-white focus:border-blue-600 focus:ring-2 focus:ring-blue-100 outline-none transition-all"
                  required
                />
              </div>
            </div>

            <Button
              type="submit"
              variant="primary"
              size="lg"
              className="w-full mt-2"
              isLoading={isSubmitting}
              rightIcon={<ArrowRight className="w-4 h-4" />}
            >
              Kirish
            </Button>
          </form>

          <div className="relative my-5">
            <div className="absolute inset-0 flex items-center">
              <div className="w-full border-t border-slate-200" />
            </div>
            <div className="relative flex justify-center text-xs">
              <span className="px-2 bg-white text-slate-400 font-semibold">yoki</span>
            </div>
          </div>

          {/* Quick Access Account */}
          <Button
            type="button"
            variant="outline"
            size="md"
            onClick={handleQuickDemo}
            className="w-full border-dashed text-slate-700 hover:text-blue-600 text-xs font-bold"
            leftIcon={<Sparkles className="w-4 h-4 text-amber-500" />}
          >
            Namuna hisobi bilan kirish
          </Button>

          <div className="mt-5 text-center text-xs text-slate-500">
            Hisobingiz yo‘qmi?{' '}
            <button
              type="button"
              onClick={onNavigateRegister}
              className="font-bold text-blue-600 hover:underline cursor-pointer"
            >
              Ro‘yxatdan o‘tish
            </button>
          </div>
        </Card>
      </motion.div>
    </div>
  );
};
