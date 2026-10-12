import React, { useState } from 'react';
import { motion } from 'framer-motion';
import {
  Mail,
  Lock,
  ArrowRight,
  AlertCircle,
  Sparkles,
  GraduationCap,
  BarChart3,
  Star,
  Users,
  TrendingUp,
  ShieldCheck,
  CheckCircle2,
} from 'lucide-react';
import { useAuth } from '@/core/context/AuthContext';
import { BilimYolLogo } from '@/presentation/components/BilimYolLogo';

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
  const [isSuccess, setIsSuccess] = useState(false);

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
      setIsSuccess(true);
      setTimeout(() => {
        onSuccess(loggedProfile?.role);
      }, 400);
    }
  };

  const handleQuickDemo = () => {
    setIsSuccess(true);
    setDemoUser();
    setTimeout(() => {
      onSuccess();
    }, 300);
  };

  return (
    <div className="min-h-screen w-full bg-[#0a0f2c] text-slate-100 flex items-center justify-center p-4 sm:p-6 lg:p-10 relative overflow-hidden">
      {/* Dynamic Cosmic Gradient Orbs in Background */}
      <div className="absolute top-0 left-1/4 w-[600px] h-[600px] bg-indigo-600/20 rounded-full blur-[140px] pointer-events-none" />
      <div className="absolute bottom-0 right-10 w-[500px] h-[500px] bg-blue-500/20 rounded-full blur-[140px] pointer-events-none" />
      <div className="absolute top-1/2 left-10 w-[400px] h-[400px] bg-cyan-400/15 rounded-full blur-[120px] pointer-events-none" />

      {/* Main Container Card: Reference-Driven Split Experience */}
      <div className="relative z-10 w-full max-w-7xl mx-auto rounded-[36px] bg-gradient-to-br from-slate-900/90 via-[#0f1738]/95 to-[#171e4d]/90 border border-indigo-500/20 shadow-2xl shadow-indigo-950/60 backdrop-blur-2xl overflow-hidden p-6 sm:p-8 lg:p-12">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 lg:gap-12 items-center">
          
          {/* LEFT COLUMN: Hero Brand, Values, 3D Yo'lchi AI Artwork & Social Proof */}
          <div className="lg:col-span-7 flex flex-col justify-between space-y-8">
            {/* Header Brand */}
            <div>
              <div className="flex items-center gap-3 mb-2">
                <BilimYolLogo size="lg" variant="dark" showSubtitle={false} />
              </div>
              <p className="text-xs sm:text-sm font-semibold text-indigo-300/90 tracking-wide pl-1">
                AI yordamida shaxsiylashtirilgan ta’lim platformasi
              </p>
            </div>

            {/* Big Catchy Hero Headline matching Reference */}
            <div className="space-y-3">
              <h1 className="text-3xl sm:text-4xl lg:text-5xl font-black text-white tracking-tight leading-tight">
                Kelajagingni{' '}
                <span className="bg-gradient-to-r from-cyan-300 via-teal-200 to-emerald-300 bg-clip-text text-transparent">
                  bilim bilan yarat!
                </span>
              </h1>
              <p className="text-sm sm:text-base text-indigo-200/90 font-medium max-w-xl leading-relaxed">
                Har bir o‘quvchi uchun individual ta’lim yo‘lini shakllantiruvchi intellektual tizim. O‘rganish jarayonini biz bilan boshlang.
              </p>
            </div>

            {/* 3 Key Feature Badges */}
            <div className="flex flex-wrap items-center gap-2.5 sm:gap-3">
              <div className="flex items-center gap-2 px-3.5 py-2 rounded-2xl bg-white/10 hover:bg-white/15 border border-white/15 backdrop-blur-md transition-colors text-xs font-bold text-white shadow-sm">
                <GraduationCap className="w-4 h-4 text-cyan-300 shrink-0" />
                <span>Shaxsiy ta’lim yo‘li</span>
              </div>
              <div className="flex items-center gap-2 px-3.5 py-2 rounded-2xl bg-white/10 hover:bg-white/15 border border-white/15 backdrop-blur-md transition-colors text-xs font-bold text-white shadow-sm">
                <BarChart3 className="w-4 h-4 text-emerald-300 shrink-0" />
                <span>AI yordamchi Yo‘lchi</span>
              </div>
              <div className="flex items-center gap-2 px-3.5 py-2 rounded-2xl bg-white/10 hover:bg-white/15 border border-white/15 backdrop-blur-md transition-colors text-xs font-bold text-white shadow-sm">
                <Star className="w-4 h-4 text-amber-300 shrink-0" />
                <span>Real natijalar va progress</span>
              </div>
            </div>

            {/* Middle Feature Graphic: 3D Yo'lchi AI & Knowledge Book */}
            <div className="relative rounded-3xl overflow-hidden border border-indigo-400/25 bg-gradient-to-b from-indigo-950/60 to-slate-950/80 p-2 sm:p-3 group shadow-xl">
              <div className="relative w-full h-48 sm:h-64 lg:h-72 rounded-2xl overflow-hidden bg-slate-950">
                <img
                  src="/images/login_hero_yolchi.jpg"
                  alt="Yo'lchi AI & BilimYo'l Smart Edu"
                  className="w-full h-full object-cover object-center group-hover:scale-105 transition-transform duration-700 ease-out"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-slate-950/80 via-transparent to-transparent pointer-events-none" />
                
                {/* Floating pill badge on image */}
                <div className="absolute bottom-3 left-3 right-3 flex items-center justify-between text-xs font-bold">
                  <span className="px-3 py-1 rounded-full bg-slate-900/80 backdrop-blur-md text-cyan-300 border border-cyan-400/30">
                    ✨ Yo‘lchi AI intellektual mentori
                  </span>
                  <span className="hidden sm:inline-block px-3 py-1 rounded-full bg-indigo-600/80 backdrop-blur-md text-white border border-indigo-400/30 text-[11px]">
                    24/7 Shaxsiy repetitor
                  </span>
                </div>
              </div>
            </div>

            {/* Bottom Proof Strip matching Reference */}
            <div className="space-y-3 pt-2 border-t border-indigo-500/20">
              <p className="text-xs italic text-indigo-300 font-semibold tracking-wide">
                “Har bir o‘quvchi uchun yorqin kelajak!”
              </p>

              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div className="p-3 rounded-2xl bg-white/5 border border-white/10 flex items-center gap-3">
                  <div className="w-8 h-8 rounded-xl bg-indigo-500/20 flex items-center justify-center text-indigo-300 shrink-0">
                    <Users className="w-4 h-4" />
                  </div>
                  <div>
                    <div className="text-xs font-extrabold text-white">Minglab</div>
                    <div className="text-[10px] text-slate-400">interaktiv darslar</div>
                  </div>
                </div>

                <div className="p-3 rounded-2xl bg-white/5 border border-white/10 flex items-center gap-3">
                  <div className="w-8 h-8 rounded-xl bg-cyan-500/20 flex items-center justify-center text-cyan-300 shrink-0">
                    <TrendingUp className="w-4 h-4" />
                  </div>
                  <div>
                    <div className="text-xs font-extrabold text-white">Shaxsiylashtirilgan</div>
                    <div className="text-[10px] text-slate-400">o‘quv yo‘li</div>
                  </div>
                </div>

                <div className="p-3 rounded-2xl bg-white/5 border border-white/10 flex items-center gap-3">
                  <div className="w-8 h-8 rounded-xl bg-emerald-500/20 flex items-center justify-center text-emerald-300 shrink-0">
                    <ShieldCheck className="w-4 h-4" />
                  </div>
                  <div>
                    <div className="text-xs font-extrabold text-white">Xavfsiz va ishonchli</div>
                    <div className="text-[10px] text-slate-400">platforma</div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* RIGHT COLUMN: Modern White / Glassmorphic Login Card */}
          <div className="lg:col-span-5 flex justify-center">
            <motion.div
              initial={{ opacity: 0, scale: 0.96 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ duration: 0.3 }}
              className="w-full max-w-md bg-white text-slate-900 rounded-[32px] p-7 sm:p-9 shadow-2xl shadow-indigo-950/50 border border-slate-100"
            >
              {/* Card Top Brand */}
              <div className="text-center mb-6">
                <div className="flex justify-center mb-2.5">
                  <BilimYolLogo size="md" />
                </div>
                <h2 className="text-2xl sm:text-3xl font-black text-slate-900 tracking-tight">
                  Xush kelibsiz!
                </h2>
                <p className="text-xs text-slate-500 font-semibold mt-1 max-w-xs mx-auto">
                  Shaxsiy ta’lim yo‘lingizni davom ettirish uchun tizimga kiring
                </p>
              </div>

              {/* Form Component */}
              <form onSubmit={handleLogin} className="space-y-4">
                {errorMsg && (
                  <motion.div
                    initial={{ opacity: 0, y: -8 }}
                    animate={{ opacity: 1, y: 0 }}
                    className="p-3 bg-rose-50 border border-rose-200 rounded-2xl flex items-start gap-2.5 text-rose-700 text-xs font-semibold"
                  >
                    <AlertCircle className="w-4 h-4 shrink-0 mt-0.5 text-rose-600" />
                    <span>{errorMsg}</span>
                  </motion.div>
                )}

                {isSuccess && (
                  <div className="p-3 bg-emerald-50 border border-emerald-200 rounded-2xl flex items-center gap-2.5 text-emerald-700 text-xs font-bold">
                    <CheckCircle2 className="w-4 h-4 text-emerald-600" />
                    <span>Muvaffaqiyatli kirildi! Sahifa ochilmoqda...</span>
                  </div>
                )}

                {/* Email input field */}
                <div>
                  <label className="block text-[11px] font-black text-slate-700 uppercase tracking-wider mb-1.5">
                    Email manzilingiz
                  </label>
                  <div className="relative">
                    <Mail className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                    <input
                      type="email"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      placeholder="nomingiz@misol.uz"
                      className="w-full pl-10 pr-4 py-3 bg-slate-50 border border-slate-200/90 rounded-2xl text-sm text-slate-900 placeholder:text-slate-400 font-medium focus:bg-white focus:border-indigo-600 focus:ring-4 focus:ring-indigo-100 outline-none transition-all"
                      required
                    />
                  </div>
                </div>

                {/* Password input field */}
                <div>
                  <div className="flex items-center justify-between mb-1.5">
                    <label className="block text-[11px] font-black text-slate-700 uppercase tracking-wider">
                      Parol
                    </label>
                    <button
                      type="button"
                      onClick={onNavigateForgotPassword}
                      className="text-xs font-bold text-indigo-600 hover:text-indigo-800 transition-colors cursor-pointer"
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
                      className="w-full pl-10 pr-4 py-3 bg-slate-50 border border-slate-200/90 rounded-2xl text-sm text-slate-900 placeholder:text-slate-400 font-medium focus:bg-white focus:border-indigo-600 focus:ring-4 focus:ring-indigo-100 outline-none transition-all"
                      required
                    />
                  </div>
                </div>

                {/* Main Submit Button: Electric Blue / Indigo Gradient */}
                <button
                  type="submit"
                  disabled={isSubmitting || isSuccess}
                  className="w-full mt-2 py-3.5 px-6 rounded-2xl bg-gradient-to-r from-blue-600 via-indigo-600 to-indigo-700 hover:from-blue-700 hover:to-indigo-800 text-white font-black text-sm tracking-wide shadow-lg shadow-indigo-600/30 flex items-center justify-center gap-2 hover:scale-[1.01] active:scale-[0.99] transition-all cursor-pointer disabled:opacity-75 disabled:pointer-events-none"
                >
                  {isSubmitting ? (
                    <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                  ) : (
                    <>
                      <span>Kirish</span>
                      <ArrowRight className="w-4 h-4" />
                    </>
                  )}
                </button>
              </form>

              {/* Divider */}
              <div className="relative my-5">
                <div className="absolute inset-0 flex items-center">
                  <div className="w-full border-t border-slate-200" />
                </div>
                <div className="relative flex justify-center text-xs">
                  <span className="px-3 bg-white text-slate-400 font-bold uppercase tracking-wider text-[10px]">
                    yoki
                  </span>
                </div>
              </div>

              {/* Demo Login Button */}
              <button
                type="button"
                onClick={handleQuickDemo}
                className="w-full py-3 px-4 rounded-2xl border border-slate-200 hover:border-indigo-300 bg-white hover:bg-slate-50 text-slate-800 hover:text-indigo-600 text-xs font-black flex items-center justify-center gap-2 shadow-2xs hover:shadow-sm transition-all cursor-pointer"
              >
                <Sparkles className="w-4 h-4 text-amber-500 fill-amber-500" />
                <span>Namuna hisobi bilan kirish</span>
              </button>

              {/* Register Navigation Link */}
              <div className="mt-6 text-center text-xs text-slate-500 font-semibold">
                Hisobingiz yo‘qmi?{' '}
                <button
                  type="button"
                  onClick={onNavigateRegister}
                  className="font-black text-indigo-600 hover:text-indigo-800 hover:underline cursor-pointer transition-colors"
                >
                  Ro‘yxatdan o‘tish
                </button>
              </div>
            </motion.div>
          </div>

        </div>
      </div>
    </div>
  );
};
