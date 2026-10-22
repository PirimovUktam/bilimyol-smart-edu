import React from 'react';
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

interface ProgressProps {
  value: number; // 0–100
  tone?: 'indigo' | 'cyan' | 'emerald' | 'amber' | 'rose';
  size?: 'sm' | 'md';
  className?: string;
  showLabel?: boolean;
  ariaLabel?: string;
}

const toneStyles = {
  indigo: 'bg-indigo-600',
  cyan: 'bg-gradient-to-r from-cyan-400 to-teal-500',
  emerald: 'bg-emerald-500',
  amber: 'bg-amber-500',
  rose: 'bg-rose-500',
};

const heights = { sm: 'h-1.5', md: 'h-2.5' };

/** Accessible progress bar (0–100) used across dashboard / progress / roadmap. */
export const Progress: React.FC<ProgressProps> = ({
  value,
  tone = 'indigo',
  size = 'md',
  className,
  showLabel = false,
  ariaLabel = 'Jarayon',
}) => {
  const pct = Math.max(0, Math.min(100, Math.round(value)));
  return (
    <div className={cn('w-full', className)}>
      {showLabel && (
        <div className="mb-1 flex items-center justify-between text-xs font-bold text-slate-500">
          <span>{ariaLabel}</span>
          <span className="text-slate-900">{pct}%</span>
        </div>
      )}
      <div
        className={cn('w-full overflow-hidden rounded-full bg-slate-100', heights[size])}
        role="progressbar"
        aria-label={ariaLabel}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={pct}
      >
        <div
          className={cn('h-full rounded-full transition-[width] duration-500 ease-out motion-reduce:transition-none', toneStyles[tone])}
          style={{ width: `${pct}%` }}
        />
      </div>
    </div>
  );
};
