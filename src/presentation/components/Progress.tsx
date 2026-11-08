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
  indigo: 'bg-gradient-to-r from-[#4F46E5] to-[#0EA5E9]',
  cyan: 'bg-gradient-to-r from-[#0EA5E9] to-[#10B981]',
  emerald: 'bg-gradient-to-r from-[#10B981] to-[#34D399]',
  amber: 'bg-gradient-to-r from-[#F59E0B] to-[#FBBF24]',
  rose: 'bg-gradient-to-r from-[#E11D48] to-[#FB7185]',
};

const heights = { sm: 'h-2', md: 'h-2.5' };

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
        <div className="mb-1.5 flex items-center justify-between text-xs font-bold text-slatefine">
          <span>{ariaLabel}</span>
          <span className="font-mono-num text-ink">{pct}%</span>
        </div>
      )}
      <div
        className={cn('w-full overflow-hidden rounded-full bg-slate-100 ring-1 ring-slate-200/70 inset-shadow-2xs', heights[size])}
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
