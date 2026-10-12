import React from 'react';
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

interface BadgeProps {
  children: React.ReactNode;
  variant?: 'blue' | 'teal' | 'amber' | 'rose' | 'emerald' | 'slate' | 'purple' | 'indigo' | 'cyan';
  size?: 'sm' | 'md';
  icon?: React.ReactNode;
  className?: string;
}

export const Badge: React.FC<BadgeProps> = ({
  children,
  variant = 'blue',
  size = 'md',
  icon,
  className = '',
}) => {
  const variantStyles = {
    blue: 'bg-blue-950/80 text-blue-300 border-blue-500/40 shadow-xs shadow-blue-500/10',
    cyan: 'bg-cyan-950/80 text-cyan-300 border-cyan-500/40 shadow-xs shadow-cyan-500/10',
    teal: 'bg-teal-950/80 text-teal-300 border-teal-500/40 shadow-xs shadow-teal-500/10',
    amber: 'bg-amber-950/80 text-amber-300 border-amber-500/40 shadow-xs shadow-amber-500/10',
    rose: 'bg-rose-950/80 text-rose-300 border-rose-500/40 shadow-xs shadow-rose-500/10',
    emerald: 'bg-emerald-950/80 text-emerald-300 border-emerald-500/40 shadow-xs shadow-emerald-500/10',
    slate: 'bg-slate-800/80 text-slate-300 border-slate-700/80',
    purple: 'bg-purple-950/80 text-purple-300 border-purple-500/40 shadow-xs shadow-purple-500/10',
    indigo: 'bg-indigo-950/80 text-indigo-300 border-indigo-500/40 shadow-xs shadow-indigo-500/10',
  };

  const sizeStyles = {
    sm: 'px-2 py-0.5 text-[11px] gap-1 font-semibold',
    md: 'px-2.5 py-1 text-xs gap-1.5 font-medium',
  };

  return (
    <span
      className={cn(
        'inline-flex items-center rounded-xl border tracking-wide select-none backdrop-blur-md',
        variantStyles[variant],
        sizeStyles[size],
        className
      )}
    >
      {icon}
      {children}
    </span>
  );
};
