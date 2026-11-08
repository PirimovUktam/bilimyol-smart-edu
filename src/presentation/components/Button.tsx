import React from 'react';
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'outline' | 'ghost' | 'danger' | 'success' | 'gradient' | 'cyan' | 'coral';
  size?: 'sm' | 'md' | 'lg';
  isLoading?: boolean;
  leftIcon?: React.ReactNode;
  rightIcon?: React.ReactNode;
}

export const Button: React.FC<ButtonProps> = ({
  children,
  variant = 'primary',
  size = 'md',
  isLoading = false,
  leftIcon,
  rightIcon,
  className = '',
  disabled,
  ...props
}) => {
  const baseStyles =
    'inline-flex items-center justify-center font-bold tracking-tight rounded-[var(--radius-control)] transition-all duration-200 active:scale-[0.98] disabled:opacity-50 disabled:pointer-events-none disabled:active:scale-100 cursor-pointer';

  const sizeStyles = {
    sm: 'min-h-9 px-3.5 py-1.5 text-xs gap-1.5 pointer-coarse:min-h-11',
    md: 'min-h-11 px-5 py-2.5 text-sm gap-2',
    lg: 'min-h-12 px-6 py-3 text-base gap-2.5',
  };

  const variantStyles = {
    primary:
      'commonBtn bg-gradient-to-r from-[#4F46E5] to-[#4338CA] text-white border border-transparent shadow-[0_8px_20px_-4px_rgba(79,70,229,0.4)] hover:shadow-[0_12px_26px_-4px_rgba(79,70,229,0.52)] hover:-translate-y-0.5',
    secondary:
      'bg-ink hover:bg-graphite text-white shadow-sm border border-ink hover:-translate-y-0.5',
    gradient:
      'commonBtn bg-gradient-to-r from-[#4F46E5] via-[#3B82F6] to-[#0EA5E9] hover:brightness-105 text-white shadow-[0_8px_20px_-4px_rgba(79,70,229,0.45)] border-0 hover:-translate-y-0.5',
    cyan:
      'bg-path hover:bg-secondary-hover text-white shadow-[0_8px_18px_-4px_rgba(14,165,233,0.38)] border-0 hover:-translate-y-0.5',
    coral:
      'bg-coral hover:brightness-95 text-white shadow-[0_8px_18px_-4px_rgba(225,29,72,0.35)] border-0 hover:-translate-y-0.5',
    outline:
      'bg-paper hover:bg-sand/60 text-ink border border-hairline hover:border-brand/40 shadow-2xs hover:-translate-y-0.5',
    ghost:
      'bg-transparent hover:bg-sand/80 text-graphite hover:text-brand-dark',
    danger:
      'bg-coral hover:brightness-95 text-white shadow-[0_8px_18px_-4px_rgba(225,29,72,0.35)]',
    success:
      'bg-mint hover:brightness-95 text-white shadow-[0_8px_18px_-4px_rgba(16,185,129,0.38)] hover:-translate-y-0.5',
  };

  return (
    <button
      type="button"
      className={cn(baseStyles, sizeStyles[size], variantStyles[variant], className)}
      disabled={disabled || isLoading}
      aria-busy={isLoading || undefined}
      {...props}
    >
      {isLoading ? (
        <svg className="animate-spin -ml-1 mr-2 h-4 w-4 text-current" fill="none" viewBox="0 0 24 24">
          <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
          <path
            className="opacity-75"
            fill="currentColor"
            d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
          />
        </svg>
      ) : (
        leftIcon
      )}
      {children}
      {!isLoading && rightIcon}
    </button>
  );
};
