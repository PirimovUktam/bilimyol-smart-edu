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
    default: 'bg-white border border-slate-200/90 shadow-sm rounded-3xl',
    glass: 'glass-panel rounded-3xl',
    interactive:
      'bg-white border border-slate-200/90 hover:border-indigo-400 hover:shadow-lg hover:-translate-y-0.5 transition-all duration-200 rounded-3xl cursor-pointer',
    active:
      'bg-indigo-50/50 border-2 border-indigo-600 shadow-md shadow-indigo-500/15 rounded-3xl',
    hero:
      'hero-gradient-card text-white rounded-3xl relative overflow-hidden',
    coral:
      'coral-gradient-card rounded-3xl shadow-sm relative overflow-hidden',
    sciFi:
      'sci-fi-glow-card text-white rounded-3xl shadow-xl relative overflow-hidden',
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
