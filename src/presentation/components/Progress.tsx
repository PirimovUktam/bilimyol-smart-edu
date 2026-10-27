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
  indigo: 'bg-brand',
  cyan: 'bg-gradient-to-r from-path to-mint',
  emerald: 'bg-mint',
  amber: 'bg-amber',
  rose: 'bg-coral',
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
        <div className="mb-1 flex items-center justify-between text-xs font-bold text-slatefine">
          <span>{ariaLabel}</span>
          <span className="font-mono-num text-ink">{pct}%</span>
        </div>
      )}
      <div
        className={cn('w-full overflow-hidden rounded-full bg-muted', heights[size])}
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
