import React from 'react';

interface BilimYolLogoProps {
  size?: 'sm' | 'md' | 'lg';
  showSubtitle?: boolean;
  className?: string;
}

export const BilimYolLogo: React.FC<BilimYolLogoProps> = ({
  size = 'md',
  showSubtitle = true,
  className = '',
}) => {
  const iconSizes = {
    sm: 'w-7 h-7',
    md: 'w-9 h-9',
    lg: 'w-12 h-12',
  };

  const titleSizes = {
    sm: 'text-lg',
    md: 'text-xl',
    lg: 'text-2xl',
  };

  return (
    <div className={`flex items-center gap-3 select-none ${className}`}>
      <div
        className={`${iconSizes[size]} rounded-2xl bg-gradient-to-br from-blue-600 via-indigo-600 to-teal-500 p-0.5 shadow-md shadow-blue-500/20 flex items-center justify-center`}
      >
        <div className="w-full h-full bg-white/10 rounded-[14px] flex items-center justify-center backdrop-blur-xs">
          <svg
            viewBox="0 0 24 24"
            fill="none"
            stroke="white"
            strokeWidth="2.2"
            strokeLinecap="round"
            strokeLinejoin="round"
            className="w-3/5 h-3/5"
          >
            {/* Path / compass metaphor */}
            <path d="M12 2L2 7l10 5 10-5-10-5z" />
            <path d="M2 17l10 5 10-5" />
            <path d="M2 12l10 5 10-5" />
          </svg>
        </div>
      </div>

      <div className="flex flex-col">
        <div className="flex items-center gap-1.5 leading-tight">
          <span className={`font-extrabold tracking-tight text-slate-900 ${titleSizes[size]}`}>
            Bilim<span className="text-blue-600">Yo‘l</span>
          </span>
          <span className="px-1.5 py-0.5 text-[10px] font-bold tracking-wider uppercase bg-blue-50 text-blue-700 border border-blue-200/80 rounded-md">
            Smart Edu
          </span>
        </div>
        {showSubtitle && (
          <span className="text-[11px] font-medium text-slate-500 tracking-normal">
            Moslashuvchan Ta'lim Platformasi
          </span>
        )}
      </div>
    </div>
  );
};
