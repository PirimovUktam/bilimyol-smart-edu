import React from 'react';

interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  variant?: 'default' | 'glass' | 'interactive' | 'active';
  padding?: 'none' | 'sm' | 'md' | 'lg';
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
  };

  const variantStyles = {
    default: 'bg-white border border-slate-200/80 shadow-sm rounded-2xl',
    glass: 'bg-white/80 backdrop-blur-md border border-slate-200/80 shadow-md rounded-2xl',
    interactive:
      'bg-white border border-slate-200 hover:border-blue-300 hover:shadow-md transition-all duration-200 rounded-2xl cursor-pointer',
    active:
      'bg-blue-50/50 border-2 border-blue-500 shadow-md shadow-blue-500/10 rounded-2xl',
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
