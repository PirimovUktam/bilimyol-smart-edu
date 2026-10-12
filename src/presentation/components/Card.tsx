import React from 'react';
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  variant?:
    | 'default'
    | 'glass'
    | 'interactive'
    | 'active'
    | 'hero'
    | 'coral'
    | 'sciFi'
    | 'cosmic'
    | 'cosmicGlow'
    | 'neonCyan'
    | 'neonPurple'
    | 'neonEmerald'
    | 'neonAmber';
  padding?: 'none' | 'sm' | 'md' | 'lg' | 'xl';
}

export const Card: React.FC<CardProps> = ({
  children,
  variant = 'default',
  padding = 'md',
  className = '',
  ...props
}) => {
  const paddingStyles = {
    none: 'p-0',
    sm: 'p-4',
    md: 'p-6',
    lg: 'p-8',
    xl: 'p-10',
  };

  const variantStyles = {
    default: 'bg-slate-900/80 border border-white/10 text-slate-100 shadow-xl backdrop-blur-xl rounded-3xl',
    glass: 'glass-cosmic rounded-3xl text-slate-100',
    interactive:
      'bg-slate-900/80 border border-white/10 hover:border-cyan-500/50 hover:shadow-[0_0_30px_rgba(6,182,212,0.2)] hover:-translate-y-1 transition-all duration-300 rounded-3xl cursor-pointer text-slate-100',
    active:
      'bg-indigo-950/60 border-2 border-indigo-500 shadow-[0_0_30px_rgba(99,102,241,0.25)] rounded-3xl text-slate-100',
    hero:
      'hero-gradient-card text-white rounded-3xl relative overflow-hidden',
    coral:
      'coral-gradient-card rounded-3xl shadow-lg relative overflow-hidden text-white',
    sciFi:
      'sci-fi-glow-card text-white rounded-3xl shadow-xl relative overflow-hidden',
    cosmic:
      'bg-slate-900/85 border border-white/10 backdrop-blur-2xl shadow-2xl rounded-3xl text-slate-100',
    cosmicGlow:
      'glass-cosmic-glow rounded-3xl text-slate-100',
    neonCyan:
      'bg-slate-900/85 border-2 border-cyan-500/40 shadow-[0_0_30px_rgba(6,182,212,0.18)] rounded-3xl text-slate-100',
    neonPurple:
      'bg-slate-900/85 border-2 border-purple-500/40 shadow-[0_0_30px_rgba(168,85,247,0.18)] rounded-3xl text-slate-100',
    neonEmerald:
      'bg-slate-900/85 border-2 border-emerald-500/40 shadow-[0_0_30px_rgba(16,185,129,0.18)] rounded-3xl text-slate-100',
    neonAmber:
      'bg-slate-900/85 border-2 border-amber-500/40 shadow-[0_0_30px_rgba(245,158,11,0.18)] rounded-3xl text-slate-100',
  };

  return (
    <div
      className={cn(variantStyles[variant], paddingStyles[padding], className)}
      {...props}
    >
      {children}
    </div>
  );
};
