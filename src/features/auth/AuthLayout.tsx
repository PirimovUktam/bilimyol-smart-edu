import React from 'react';
import { motion } from 'framer-motion';
import { BilimYolLogo } from '@/presentation/components/BilimYolLogo';

interface AuthLayoutProps {
  title: string;
  subtitle?: string;
  children: React.ReactNode;
  /** Max width of the centered card. */
  maxWidth?: 'sm' | 'md';
}

/**
 * Shared deep-space shell for every auth surface (login/register/forgot/reset).
 * The brand panel is dark indigo; the form sits on a white card so the journey
 * theme (deep-space hero + crisp learning card) is consistent across auth.
 */
export const AuthLayout: React.FC<AuthLayoutProps> = ({
  title,
  subtitle,
  children,
  maxWidth = 'md',
}) => {
  return (
    <div className="min-h-screen w-full bg-[#0a0f2c] text-slate-100 flex items-center justify-center p-4 sm:p-6 relative overflow-hidden">
      {/* Ambient cosmic glow — matches the login journey surface */}
      <div className="absolute top-0 left-1/4 w-[560px] h-[560px] bg-indigo-600/20 rounded-full blur-[140px] pointer-events-none" />
      <div className="absolute bottom-0 right-8 w-[440px] h-[440px] bg-blue-500/20 rounded-full blur-[140px] pointer-events-none" />
      <div className="absolute top-1/2 left-8 w-[360px] h-[360px] bg-cyan-400/15 rounded-full blur-[120px] pointer-events-none" />

      <motion.div
        initial={{ opacity: 0, y: 18 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35, ease: [0.22, 1, 0.36, 1] }}
        className={`relative z-10 w-full ${maxWidth === 'sm' ? 'max-w-sm' : 'max-w-md'}`}
      >
        <div className="text-center mb-6">
          <div className="flex justify-center mb-3">
            <BilimYolLogo size="lg" variant="dark" />
          </div>
          <h1 className="text-2xl sm:text-3xl font-black tracking-tight text-white">
            {title}
          </h1>
          {subtitle && (
            <p className="text-sm text-indigo-200/90 font-medium mt-1.5 max-w-xs mx-auto">
              {subtitle}
            </p>
          )}
        </div>

        <div className="bg-white text-slate-900 rounded-[32px] p-6 sm:p-8 shadow-2xl shadow-indigo-950/50 border border-slate-100">
          {children}
        </div>
      </motion.div>
    </div>
  );
};
