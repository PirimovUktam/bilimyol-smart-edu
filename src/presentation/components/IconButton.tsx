import type { ButtonHTMLAttributes, ReactNode } from 'react';

interface IconButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  label: string;
  children: ReactNode;
}

export function IconButton({ label, children, className = '', ...props }: IconButtonProps) {
  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      className={'inline-grid size-11 shrink-0 cursor-pointer place-items-center rounded-control text-slatefine hover:bg-sand hover:text-brand-dark disabled:opacity-50 ' + className}
      {...props}
    >
      {children}
    </button>
  );
}
