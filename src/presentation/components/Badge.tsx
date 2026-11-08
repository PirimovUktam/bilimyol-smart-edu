import React from 'react';

interface BadgeProps {
  children: React.ReactNode;
  variant?: 'blue' | 'teal' | 'amber' | 'rose' | 'emerald' | 'slate' | 'purple' | 'indigo';
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
    blue: 'bg-brand/10 text-brand border-brand/20',
    indigo: 'bg-brand/10 text-brand border-brand/20',
    teal: 'bg-path/12 text-[#0284C7] border-path/25',
    amber: 'bg-amber/12 text-[#B45309] border-amber/30',
    rose: 'bg-coral/10 text-[#BE123C] border-coral/25',
    emerald: 'bg-mint/12 text-[#059669] border-mint/25',
    purple: 'bg-[#6d28d9]/10 text-[#5b21b6] border-[#6d28d9]/25',
    slate: 'bg-slate-100 text-graphite border-hairline',
  };

  const sizeStyles = {
    sm: 'px-2.5 py-0.5 text-[10px] gap-1 font-bold tracking-wide uppercase',
    md: 'px-3 py-1 text-xs gap-1.5 font-bold tracking-wide',
  };

  return (
    <span
      className={`inline-flex items-center rounded-full border select-none transition-colors ${variantStyles[variant]} ${sizeStyles[size]} ${className}`}
    >
      {icon}
      {children}
    </span>
  );
};
