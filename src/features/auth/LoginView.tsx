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
import { canUseHostedDemoMode } from '@/core/utils/authGuards';
import { BilimYolLogo } from '@/presentation/components/BilimYolLogo';

interface LoginViewProps {
  onSuccess: (role?: 'student' | 'admin') => void;
  onNavigateRegister: () => void;
  onNavigateForgotPassword: () => void;
}

export const LoginView: React.FC<LoginViewProps> = ({
  onSuccess,
  onNavigateRegister,
  onNavigateForgotPassword,
}) => {
  const { signIn, setDemoUser } = useAuth();
  const demoAvailable = canUseHostedDemoMode();
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
    if (!demoAvailable) return;
    setIsSuccess(true);
    setDemoUser();
    setTimeout(() => {
      onSuccess();
    }, 300);
  };

  const inputClass =
    'w-full pl-10 pr-4 py-3 bg-canvas border border-hairline rounded-[var(--radius-control)] text-sm text-ink placeholder:text-faint font-medium focus:bg-paper focus:border-ink focus:ring-4 focus:ring-ink/5 outline-none transition-all';

  return (
    <div className="min-h-screen w-full bg-canvas text-ink flex items-center justify-center p-3 sm:p-6 lab-grid-bg">
      {/* Editorial split dossier */}
      <div className="relative z-10 w-full max-w-7xl mx-auto grid grid-cols-1 lg:grid-cols-12 rounded-[var(--radius-panel)] overflow-hidden border border-hairline bg-paper shadow-[var(--shadow-pop)]">
        {/* LEFT: Brand dossier on deep ink */}
        <div className="lg:col-span-7 ink-panel p-7 sm:p-9 lg:p-12 flex flex-col gap-7">
          <div className="flex items-center justify-between gap-4">
            <BilimYolLogo size="lg" variant="dark" showSubtitle={false} />
            <span className="hidden sm:inline-flex items-center gap-1.5 font-mono text-[10px] font-bold uppercase tracking-widest text-white/50">
              <span className="w-1.5 h-1.5 rounded-full bg-lime lab-pulse" />
              NEO-LAB v3.0
            </span>
          </div>

          <div className="space-y-4">
            <p className="font-mono text-[11px] font-bold uppercase tracking-[0.18em] text-white/55">
              Intellektual ta’lim platformasi <span className="text-white/25">//</span> Est. 2026
            </p>
            <h1 className="font-display text-3xl sm:text-4xl lg:text-[3.25rem] font-bold text-white tracking-tight leading-[1.05]">
              Darslik emas —<br />
              <span className="mark-underline text-white">shaxsiy ta’lim yo‘li.</span>
            </h1>
            <p className="text-sm sm:text-base text-white/70 font-medium max-w-xl leading-relaxed">
              Har bir o‘quvchining haqiqiy bilim foizini real vaqtda hisoblovchi,
              xatolarni pedagogik tahlil qiluvchi va yo‘lni qayta quradigan AI tizim.
            </p>
          </div>

          {/* Feature chips */}
          <div className="flex flex-wrap items-center gap-2.5">
            <span className="inline-flex items-center gap-2 px-3 py-1.5 rounded-[var(--radius-chip)] bg-white/5 border border-white/10 text-[11px] font-mono font-bold text-white/85">
              <GraduationCap className="w-4 h-4 text-path" />
              ADAPTIV YO‘LCHI
            </span>
            <span className="inline-flex items-center gap-2 px-3 py-1.5 rounded-[var(--radius-chip)] bg-white/5 border border-white/10 text-[11px] font-mono font-bold text-white/85">
              <BarChart3 className="w-4 h-4 text-mint" />
              REAL-TIME DB
            </span>
            <span className="inline-flex items-center gap-2 px-3 py-1.5 rounded-[var(--radius-chip)] bg-white/5 border border-white/10 text-[11px] font-mono font-bold text-white/85">
              <Star className="w-4 h-4 text-amber" />
              DAVLAT STANDARTLARI
            </span>
          </div>

          {/* Hero artwork */}
          <div className="relative rounded-[var(--radius-card)] overflow-hidden border border-white/10 bg-black/30 group flex-1 min-h-[9rem]">
            <img
              src="/images/login_hero_yolchi.jpg"
              alt="Yo‘lchi AI & BilimYo‘l Smart Edu"
              className="w-full h-full min-h-[9rem] object-cover object-center group-hover:scale-105 transition-transform duration-700 ease-out"
            />
            <div className="absolute inset-0 bg-gradient-to-t from-ink via-ink/20 to-transparent pointer-events-none" />
            <div className="absolute bottom-3 left-3 right-3 flex items-center justify-between gap-2 text-[11px] font-mono font-bold">
              <span className="px-3 py-1 rounded-[var(--radius-chip)] bg-black/50 backdrop-blur-md text-path border border-path/30 inline-flex items-center gap-1.5">
                <Sparkles className="w-3.5 h-3.5" />
                Yo‘lchi AI Shaxsiy Mentori
              </span>
              <span className="hidden sm:inline-block px-2.5 py-1 rounded-[var(--radius-chip)] bg-white/10 backdrop-blur-md text-white/80 border border-white/15 text-[10px]">
                24/7 INTERAKTIV TAHLIL
              </span>
            </div>
          </div>

          {/* Proof strip */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            {[
              { icon: Users, tone: 'text-brand', title: '4 Fan Yo‘nalishi', sub: 'Mat · Eng · Dev · Log', bg: 'bg-brand/15' },
              { icon: TrendingUp, tone: 'text-mint', title: 'Shaxsiy Matritsa', sub: 'Dinamik tahlil', bg: 'bg-mint/15' },
              { icon: ShieldCheck, tone: 'text-amber', title: 'Xavfsiz Kirish', sub: 'Server tekshiruvi', bg: 'bg-amber/15' },
            ].map(({ icon: Icon, tone, title, sub, bg }) => (
              <div key={title} className="p-3 rounded-[var(--radius-control)] bg-white/5 border border-white/10 flex items-center gap-3">
                <span className={`w-8 h-8 rounded-[var(--radius-chip)] ${bg} flex items-center justify-center shrink-0`}>
                  <Icon className={`w-4 h-4 ${tone}`} />
                </span>
                <div className="min-w-0">
                  <div className="font-display text-xs font-bold text-white truncate">{title}</div>
                  <div className="font-mono text-[10px] text-white/50 truncate">{sub}</div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* RIGHT: Form on porcelain paper */}
        <div className="lg:col-span-5 flex items-center justify-center bg-canvas p-6 sm:p-9 lg:p-12">
          <motion.div
            initial={{ opacity: 0, y: 14 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.3, ease: [0.22, 1, 0.36, 1] }}
            className="w-full max-w-sm"
          >
            <div className="mb-6">
              <div className="lg:hidden mb-4">
                <BilimYolLogo size="md" />
              </div>
              <span className="editorial-kicker">
                Tizimga kirish <span className="sep">//</span> Shaxsiy profil
              </span>
              <h2 className="mt-1.5 font-display text-2xl font-bold text-ink tracking-tight">
                Xush kelibsiz!
              </h2>
              <p className="text-xs text-slatefine font-medium mt-1.5">
                Shaxsiy ta’lim yo‘lingizni davom ettirish uchun profilingizga kiring.
              </p>
            </div>

            <form onSubmit={handleLogin} className="space-y-4">
              {errorMsg && (
                <motion.div
                  initial={{ opacity: 0, y: -8 }}
                  animate={{ opacity: 1, y: 0 }}
                  role="alert"
                  className="p-3 bg-coral/5 border border-coral/25 rounded-[var(--radius-control)] flex items-start gap-2.5 text-[#a51c1c] text-xs font-medium"
                >
                  <AlertCircle className="w-4 h-4 shrink-0 mt-0.5 text-coral" />
                  <span>{errorMsg}</span>
                </motion.div>
              )}

              {isSuccess && (
                <div className="p-3 bg-mint/10 border border-mint/25 rounded-[var(--radius-control)] flex items-center gap-2.5 text-[#046b4a] text-xs font-bold font-mono">
                  <CheckCircle2 className="w-4 h-4 text-mint" />
                  <span>TASDIQLANDI! SAHIFA OCHILMOQDA...</span>
                </div>
              )}

              <div>
                <label htmlFor="login-email" className="block font-mono text-[10px] font-bold text-slatefine uppercase tracking-wider mb-1.5">
                  Email manzilingiz
                </label>
                <div className="relative">
                  <Mail className="w-4 h-4 text-faint absolute left-3.5 top-1/2 -translate-y-1/2" />
                  <input
                    id="login-email"
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="talaba@bilimyol.uz"
                    className={inputClass}
                    required
                  />
                </div>
              </div>

              <div>
                <div className="flex items-center justify-between mb-1.5">
                  <label htmlFor="login-password" className="block font-mono text-[10px] font-bold text-slatefine uppercase tracking-wider">
                    Parol
                  </label>
                  <button
                    type="button"
                    onClick={onNavigateForgotPassword}
                    className="font-mono text-[11px] font-bold text-brand-dark hover:text-ink transition-colors cursor-pointer"
                  >
                    Unutdingizmi?
                  </button>
                </div>
                <div className="relative">
                  <Lock className="w-4 h-4 text-faint absolute left-3.5 top-1/2 -translate-y-1/2" />
                  <input
                    id="login-password"
                    type="password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="••••••••"
                    className={inputClass}
                    required
                  />
                </div>
              </div>

              <button
                type="submit"
                disabled={isSubmitting || isSuccess}
                className="w-full mt-1 py-3 px-6 rounded-[var(--radius-control)] bg-ink hover:bg-graphite text-white font-bold text-sm tracking-wide shadow-md flex items-center justify-center gap-2 cursor-pointer disabled:opacity-70 disabled:pointer-events-none transition-all active:scale-[0.99]"
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

            <div className="relative my-5">
              <div className="absolute inset-0 flex items-center">
                <div className="w-full border-t border-hairline" />
              </div>
              <div className="relative flex justify-center text-xs">
                <span className="px-3 bg-canvas text-faint font-mono font-bold uppercase tracking-wider text-[10px]">
                  yoki
                </span>
              </div>
            </div>

            <button
              type="button"
              onClick={handleQuickDemo}
              disabled={!demoAvailable || isSuccess}
              aria-describedby="demo-login-explanation"
              className="w-full py-2.5 px-4 rounded-[var(--radius-control)] border border-hairline hover:border-ink bg-paper hover:bg-canvas text-ink text-xs font-mono font-bold flex items-center justify-center gap-2 shadow-2xs transition-all cursor-pointer disabled:cursor-not-allowed disabled:opacity-60"
            >
              <Sparkles className="w-4 h-4 text-amber fill-amber" />
              <span>Namuna hisobi bilan kirish</span>
            </button>
            <p id="demo-login-explanation" className="mt-2 text-center font-mono text-[10px] text-faint">
              Xavfsiz namuna rejimi: ma’lumotlar lokal xotirada saqlanadi.
            </p>

            <div className="mt-6 text-center text-xs text-slatefine font-medium">
              Hisobingiz yo‘qmi?{' '}
              <button
                type="button"
                onClick={onNavigateRegister}
                className="font-bold text-ink hover:text-brand-dark hover:underline cursor-pointer transition-colors"
              >
                Ro‘yxatdan o‘tish
              </button>
            </div>
          </motion.div>
        </div>
      </div>
    </div>
  );
};
