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
 * Shared shell for auth surfaces (register / forgot / reset).
 * Warm paper canvas with an ink-ruled porcelain form card — matches the login dossier.
 */
export const AuthLayout: React.FC<AuthLayoutProps> = ({
  title,
  subtitle,
  children,
  maxWidth = 'md',
}) => {
  return (
    <div className="min-h-screen w-full bg-canvas text-ink flex items-center justify-center p-4 sm:p-6 relative overflow-hidden lab-grid-bg">
      <motion.div
        initial={{ opacity: 0, y: 14 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3, ease: [0.22, 1, 0.36, 1] }}
        className={`relative z-10 w-full ${maxWidth === 'sm' ? 'max-w-sm' : 'max-w-md'}`}
      >
        <div className="text-center mb-6">
          <div className="flex justify-center mb-3">
            <BilimYolLogo size="lg" />
          </div>
          <span className="editorial-kicker justify-center">
            Avtorizatsiya <span className="sep">//</span> Shaxsiy profil
          </span>
          <h1 className="font-display text-2xl sm:text-3xl font-bold tracking-tight text-ink mt-1.5">
            {title}
          </h1>
          {subtitle && (
            <p className="text-xs sm:text-sm text-slatefine font-medium mt-1.5 max-w-xs mx-auto">
              {subtitle}
            </p>
          )}
        </div>

        <div className="relative bg-paper text-ink rounded-[var(--radius-card)] p-6 sm:p-8 shadow-[var(--shadow-pop)] border border-hairline overflow-hidden">
          <div className="absolute top-0 left-0 right-0 h-1 bg-ink" />
          {children}
        </div>
      </motion.div>
    </div>
  );
};
