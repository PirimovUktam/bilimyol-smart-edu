import React from 'react';

interface BilimYolLogoProps {
  size?: 'sm' | 'md' | 'lg';
  showSubtitle?: boolean;
  className?: string;
  variant?: 'light' | 'dark' | 'auto';
  textColor?: string;
}

export const BilimYolLogo: React.FC<BilimYolLogoProps> = ({
  size = 'md',
  showSubtitle = true,
  className = '',
  variant = 'light',
  textColor,
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

  // Universal text color resolution:
  // 1. Explicit textColor prop if provided
  // 2. White for dark variant
  // 3. Adaptive for auto variant
  // 4. Slate-900 for light variant
  const resolvedTextColor = textColor
    ? textColor
    : variant === 'dark'
    ? 'text-white'
    : variant === 'auto'
    ? 'text-slate-900 dark:text-white'
    : 'text-slate-900';

  return (
    <div className={`flex items-center gap-3 select-none ${className}`}>
      {/* Reference 2 Stylized Gradient Emblem */}
      <div
        className={`${iconSizes[size]} rounded-2xl bg-gradient-to-tr from-brand to-path p-0.5 shadow-lg shadow-brand/25 flex items-center justify-center shrink-0`}
      >
        <div className="w-full h-full bg-ink/20 rounded-[14px] flex items-center justify-center backdrop-blur-xs">
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
            <path d="M16 9V25" stroke="#3550D6" strokeWidth="1.8" strokeLinecap="round" />
            {/* Glowing sprout / knowledge wings rising up */}
            <path
              d="M16 11C14 7 10 5 8 6C7 8 9 12 16 14C23 12 25 8 24 6C22 5 18 7 16 11Z"
              fill="#0D9AD6"
            />
            {/* Golden spark / star at center */}
            <circle cx="16" cy="6" r="2" fill="#F59F00" />
          </svg>
        </div>
      </div>

      <div className="flex flex-col">
        <div className="flex items-center gap-1.5 leading-tight">
          <span className={`font-black tracking-tight ${resolvedTextColor} ${titleSizes[size]}`}>
            Bilim<span className="bg-gradient-to-r from-path to-brand bg-clip-text text-transparent">Yo‘l</span>
          </span>
          <span
            className={`px-1.5 py-0.5 text-[10px] font-extrabold tracking-wider uppercase rounded-md shadow-2xs ${
              isDark
                ? 'bg-white/10 text-path border border-path/40'
                : 'bg-brand/8 text-brand-dark border border-brand/20'
            }`}
          >
            Smart Edu
          </span>
        </div>
        {showSubtitle && (
          <span className={`text-[11px] font-semibold tracking-tight ${isDark ? 'text-white/60' : 'text-slatefine'}`}>
            AI yordamida shaxsiylashtirilgan ta’lim
          </span>
        )}
      </div>
    </div>
  );
};
