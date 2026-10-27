import React from 'react';

interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  variant?: 'default' | 'glass' | 'interactive' | 'active' | 'hero' | 'coral' | 'sciFi';
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
    default: 'bg-paper border border-hairline rounded-2xl shadow-[var(--shadow-editorial)] text-ink',
    glass: 'glass-panel rounded-2xl',
    interactive:
      'bg-paper border border-hairline hover:border-brand hover:shadow-[var(--shadow-paper)] hover:-translate-y-0.5 transition-all duration-200 rounded-2xl cursor-pointer motion-reduce:transition-none motion-reduce:hover:translate-y-0',
    active:
      'bg-brand/5 border-2 border-brand shadow-[var(--shadow-raised)] rounded-2xl',
    hero:
      'editorial-ink-hero text-white rounded-3xl relative overflow-hidden',
    coral:
      'bg-coral/5 border border-coral/25 rounded-2xl shadow-2xs relative overflow-hidden',
    sciFi:
      'ink-panel rounded-2xl relative overflow-hidden',
  };

  return (
    <div
      className={`${variantStyles[variant]} ${paddingStyles[padding]} ${className}`}
      {...props}
    >
      {children}
    </div>
  );
};
