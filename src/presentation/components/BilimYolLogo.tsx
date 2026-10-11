import React from 'react';

interface BilimYolLogoProps {
  size?: 'sm' | 'md' | 'lg';
  showSubtitle?: boolean;
  className?: string;
  variant?: 'light' | 'dark';
}

export const BilimYolLogo: React.FC<BilimYolLogoProps> = ({
  size = 'md',
  showSubtitle = true,
  className = '',
  variant = 'light',
}) => {
  const iconSizes = {
    sm: 'w-8 h-8',
    md: 'w-10 h-10',
    lg: 'w-13 h-13',
  };

  const titleSizes = {
    sm: 'text-base sm:text-lg',
    md: 'text-lg sm:text-xl',
    lg: 'text-2xl',
  };

  const isDark = variant === 'dark';

  return (
    <div className={`flex items-center gap-3 select-none ${className}`}>
      {/* Reference 2 Stylized Gradient Emblem */}
      <div
        className={`${iconSizes[size]} rounded-2xl bg-gradient-to-tr from-indigo-600 via-blue-600 to-cyan-400 p-0.5 shadow-lg shadow-indigo-500/25 flex items-center justify-center shrink-0`}
      >
        <div className="w-full h-full bg-slate-950/20 rounded-[14px] flex items-center justify-center backdrop-blur-xs">
          <svg
            viewBox="0 0 32 32"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
            className="w-4/5 h-4/5 drop-shadow"
          >
            {/* Open book base in clean white */}
            <path
              d="M16 25C13 23 8 23 5 25V9C8 7 13 7 16 9C19 7 24 7 27 9V25C24 23 19 23 16 25Z"
              fill="white"
              fillOpacity="0.95"
            />
            {/* Central spine divider */}
            <path d="M16 9V25" stroke="#4F46E5" strokeWidth="1.8" strokeLinecap="round" />
            {/* Glowing sprout / knowledge wings rising up */}
            <path
              d="M16 11C14 7 10 5 8 6C7 8 9 12 16 14C23 12 25 8 24 6C22 5 18 7 16 11Z"
              fill="#38BDF8"
            />
            {/* Golden spark / star at center */}
            <circle cx="16" cy="6" r="2" fill="#FBBF24" />
          </svg>
        </div>
      </div>

      <div className="flex flex-col">
        <div className="flex items-center gap-1.5 leading-tight">
          <span className={`font-black tracking-tight ${isDark ? 'text-white' : 'text-slate-900'} ${titleSizes[size]}`}>
            Bilim<span className="bg-gradient-to-r from-cyan-400 via-blue-400 to-indigo-400 bg-clip-text text-transparent">Yo‘l</span>
          </span>
          <span
            className={`px-1.5 py-0.5 text-[10px] font-extrabold tracking-wider uppercase rounded-md shadow-2xs ${
              isDark
                ? 'bg-cyan-950/80 text-cyan-300 border border-cyan-500/40'
                : 'bg-gradient-to-r from-blue-50 to-indigo-50 text-indigo-700 border border-indigo-200/80'
            }`}
          >
            Smart Edu
          </span>
        </div>
        {showSubtitle && (
          <span className={`text-[11px] font-semibold tracking-tight ${isDark ? 'text-slate-400' : 'text-slate-500'}`}>
            AI yordamida shaxsiylashtirilgan ta’lim
          </span>
        )}
      </div>
    </div>
  );
};
