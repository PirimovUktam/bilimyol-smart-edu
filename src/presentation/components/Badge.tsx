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
    blue: 'bg-brand/8 text-brand-dark border-brand/20',
    indigo: 'bg-brand/8 text-brand-dark border-brand/20',
    teal: 'bg-path/10 text-[#086c93] border-path/25',
    amber: 'bg-amber/12 text-[#8a5a00] border-amber/30',
    rose: 'bg-coral/10 text-[#a51c1c] border-coral/25',
    emerald: 'bg-mint/10 text-[#046b4a] border-mint/25',
    purple: 'bg-[#6d28d9]/10 text-[#5b21b6] border-[#6d28d9]/25',
    slate: 'bg-sand text-graphite border-hairline',
  };

  const sizeStyles = {
    sm: 'px-2 py-0.5 text-[10px] gap-1 font-bold tracking-wide uppercase',
    md: 'px-2.5 py-1 text-xs gap-1.5 font-bold tracking-wide',
  };

  return (
    <span
      className={`inline-flex items-center rounded-md border select-none transition-colors ${variantStyles[variant]} ${sizeStyles[size]} ${className}`}
    >
      {icon}
      {children}
    </span>
  );
};
