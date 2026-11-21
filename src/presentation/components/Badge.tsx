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
    blue: 'bg-brand/15 text-brand-dark border-brand/30',
    indigo: 'bg-brand/15 text-brand-dark border-brand/30',
    teal: 'bg-path/15 text-[#67E8F9] border-path/30',
    amber: 'bg-amber/15 text-[#FCD34D] border-amber/30',
    rose: 'bg-coral/15 text-[#FDA4AF] border-coral/30',
    emerald: 'bg-mint/15 text-[#6EE7B7] border-mint/30',
    purple: 'bg-[#6d28d9]/15 text-[#C4B5FD] border-[#6d28d9]/30',
    slate: 'bg-sand text-graphite border-hairline',
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
