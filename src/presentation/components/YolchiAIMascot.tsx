import React from 'react';

interface YolchiAIMascotProps {
  size?: 'xs' | 'sm' | 'md' | 'lg' | 'xl';
  mood?: 'happy' | 'waving' | 'thinking' | 'explaining' | 'celebrating';
  showSpeechBubble?: boolean;
  speechText?: string;
  className?: string;
  variant?: 'light' | 'dark';
}

export const YolchiAIMascot: React.FC<YolchiAIMascotProps> = ({
  size = 'md',
  mood = 'happy',
  showSpeechBubble = false,
  speechText,
  className = '',
  variant = 'dark',
}) => {
  const sizeMap = {
    xs: 'w-8 h-8',
    sm: 'w-12 h-12',
    md: 'w-20 h-20',
    lg: 'w-28 h-28',
    xl: 'w-36 h-36',
  };

  const pixelDimensions = {
    xs: 32,
    sm: 48,
    md: 80,
    lg: 112,
    xl: 144,
  };

  const dim = pixelDimensions[size];

  return (
    <div className={`relative inline-flex items-center gap-3 select-none ${className}`}>
      {/* 3D-effect Glowing Robot Container */}
      <div className={`relative ${sizeMap[size]} shrink-0 transition-transform duration-300 hover:scale-105`}>
        {/* Ambient Glow */}
        <div className="absolute inset-1 rounded-full bg-gradient-to-tr from-cyan-400/30 via-indigo-500/25 to-purple-500/30 blur-md pointer-events-none" />

        <svg
          viewBox="0 0 120 120"
          width={dim}
          height={dim}
          className="relative z-10 w-full h-full drop-shadow-md"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
        >
          <defs>
            {/* Robot Head Body Gradient */}
            <linearGradient id="robotHeadGrad" x1="20" y1="20" x2="100" y2="100" gradientUnits="userSpaceOnUse">
              <stop offset="0%" stopColor="#FFFFFF" />
              <stop offset="60%" stopColor="#E0E7FF" />
              <stop offset="100%" stopColor="#C7D2FE" />
            </linearGradient>

            {/* Screen Visor Gradient */}
            <linearGradient id="robotVisorGrad" x1="30" y1="35" x2="90" y2="75" gradientUnits="userSpaceOnUse">
              <stop offset="0%" stopColor="#0F172A" />
              <stop offset="50%" stopColor="#1E1B4B" />
              <stop offset="100%" stopColor="#0F172A" />
            </linearGradient>

            {/* Cyan Eye Glow Gradient */}
            <linearGradient id="robotEyeGrad" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stopColor="#38BDF8" />
              <stop offset="100%" stopColor="#06B6D4" />
            </linearGradient>

            {/* Cyan Accent Gradient */}
            <linearGradient id="robotAccentGrad" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stopColor="#06B6D4" />
              <stop offset="50%" stopColor="#3B82F6" />
              <stop offset="100%" stopColor="#8B5CF6" />
            </linearGradient>

            {/* Hover Jet Glow */}
            <radialGradient id="jetGlow" cx="60" cy="112" r="20" gradientUnits="userSpaceOnUse">
              <stop offset="0%" stopColor="#38BDF8" stopOpacity="0.8" />
              <stop offset="60%" stopColor="#6366F1" stopOpacity="0.3" />
              <stop offset="100%" stopColor="#6366F1" stopOpacity="0" />
            </radialGradient>
          </defs>

          {/* Jet Thruster Glow Underneath */}
          <ellipse cx="60" cy="112" rx="20" ry="6" fill="url(#jetGlow)" />
          <ellipse cx="60" cy="108" rx="8" ry="3" fill="#38BDF8" opacity="0.9" />

          {/* Antenna / Crown */}
          <line x1="60" y1="22" x2="60" y2="10" stroke="#818CF8" strokeWidth="4" strokeLinecap="round" />
          <circle cx="60" cy="8" r="6" fill="#38BDF8" />
          <circle cx="60" cy="8" r="3" fill="#FFFFFF" />

          {/* Floating Head Shell */}
          <rect
            x="20"
            y="22"
            width="80"
            height="68"
            rx="30"
            fill="url(#robotHeadGrad)"
            stroke="#A5B4FC"
            strokeWidth="2.5"
          />

          {/* Earphones / Headset Pods */}
          {/* Left Ear */}
          <rect x="12" y="42" width="10" height="26" rx="5" fill="#4F46E5" />
          <circle cx="17" cy="55" r="3" fill="#38BDF8" />

          {/* Right Ear */}
          <rect x="98" y="42" width="10" height="26" rx="5" fill="#4F46E5" />
          <circle cx="103" cy="55" r="3" fill="#38BDF8" />

          {/* Curved Headset Band */}
          <path
            d="M 18 42 C 18 20, 102 20, 102 42"
            stroke="#6366F1"
            strokeWidth="3.5"
            strokeLinecap="round"
            fill="none"
          />

          {/* Face Screen Visor */}
          <rect
            x="28"
            y="32"
            width="64"
            height="46"
            rx="18"
            fill="url(#robotVisorGrad)"
            stroke="#312E81"
            strokeWidth="1.5"
          />

          {/* Cute Glowing Eyes based on Mood */}
          {mood === 'happy' || mood === 'waving' ? (
            <>
              {/* Left Eye: Happy Arc */}
              <path
                d="M 40 52 C 40 44, 52 44, 52 52"
                stroke="url(#robotEyeGrad)"
                strokeWidth="4"
                strokeLinecap="round"
                fill="none"
              />
              {/* Right Eye: Happy Arc */}
              <path
                d="M 68 52 C 68 44, 80 44, 80 52"
                stroke="url(#robotEyeGrad)"
                strokeWidth="4"
                strokeLinecap="round"
                fill="none"
              />
              {/* Cute Cheek Blushes */}
              <circle cx="36" cy="62" r="3" fill="#F43F5E" opacity="0.6" />
              <circle cx="84" cy="62" r="3" fill="#F43F5E" opacity="0.6" />
              {/* Smiling Mouth */}
              <path
                d="M 55 64 Q 60 69 65 64"
                stroke="#38BDF8"
                strokeWidth="2.5"
                strokeLinecap="round"
                fill="none"
              />
            </>
          ) : mood === 'thinking' ? (
            <>
              {/* Left Eye: Curious dot with ring */}
              <circle cx="46" cy="52" r="6" fill="#38BDF8" />
              <circle cx="48" cy="50" r="2.5" fill="#FFFFFF" />
              {/* Right Eye: Curious squint */}
              <circle cx="74" cy="50" r="5" fill="#38BDF8" />
              <circle cx="76" cy="48" r="2" fill="#FFFFFF" />
              {/* Thinking mouth */}
              <ellipse cx="60" cy="65" rx="3" ry="2" fill="#38BDF8" />
            </>
          ) : mood === 'explaining' ? (
            <>
              {/* Left Eye */}
              <ellipse cx="46" cy="50" rx="6" ry="7" fill="#38BDF8" />
              <circle cx="48" cy="48" r="2.5" fill="#FFFFFF" />
              {/* Right Eye */}
              <ellipse cx="74" cy="50" rx="6" ry="7" fill="#38BDF8" />
              <circle cx="76" cy="48" r="2.5" fill="#FFFFFF" />
              {/* Open talking mouth */}
              <path
                d="M 54 62 Q 60 70 66 62 Z"
                fill="#38BDF8"
              />
            </>
          ) : (
            <>
              {/* Celebrating: Star Eyes */}
              <path
                d="M 46 44 L 48 49 L 53 50 L 49 54 L 50 59 L 46 56 L 42 59 L 43 54 L 39 50 L 44 49 Z"
                fill="#38BDF8"
              />
              <path
                d="M 74 44 L 76 49 L 81 50 L 77 54 L 78 59 L 74 56 L 70 59 L 71 54 L 67 50 L 72 49 Z"
                fill="#38BDF8"
              />
              {/* Big Smile */}
              <path
                d="M 52 64 Q 60 73 68 64"
                stroke="#38BDF8"
                strokeWidth="3"
                strokeLinecap="round"
                fill="none"
              />
            </>
          )}

          {/* Floating Body */}
          <path
            d="M 42 90 Q 60 92 78 90 L 74 104 Q 60 108 46 104 Z"
            fill="url(#robotHeadGrad)"
            stroke="#A5B4FC"
            strokeWidth="2"
          />

          {/* Chest Core Indicator */}
          <circle cx="60" cy="98" r="4" fill="#06B6D4" />
          <circle cx="60" cy="98" r="2" fill="#FFFFFF" />

          {/* Arms */}
          {mood === 'waving' ? (
            <>
              {/* Left Arm Resting */}
              <path
                d="M 38 92 C 30 96 30 102 36 104"
                stroke="#818CF8"
                strokeWidth="4"
                strokeLinecap="round"
                fill="none"
              />
              {/* Right Arm Waving Up! */}
              <path
                d="M 82 92 C 92 86 98 76 100 68"
                stroke="#818CF8"
                strokeWidth="4"
                strokeLinecap="round"
                fill="none"
              />
              <circle cx="100" cy="66" r="4" fill="#6366F1" />
            </>
          ) : (
            <>
              {/* Normal Floating Arms */}
              <path
                d="M 38 92 C 28 98 28 104 36 106"
                stroke="#818CF8"
                strokeWidth="4"
                strokeLinecap="round"
                fill="none"
              />
              <circle cx="36" cy="106" r="3.5" fill="#6366F1" />
              <path
                d="M 82 92 C 92 98 92 104 84 106"
                stroke="#818CF8"
                strokeWidth="4"
                strokeLinecap="round"
                fill="none"
              />
              <circle cx="84" cy="106" r="3.5" fill="#6366F1" />
            </>
          )}
        </svg>
      </div>

      {/* Optional Speech Bubble */}
      {showSpeechBubble && speechText && (
        <div
          className={
            variant === 'dark'
              ? 'relative p-3.5 bg-slate-900/90 border border-cyan-500/30 rounded-2xl rounded-tl-xs shadow-lg shadow-cyan-500/10 backdrop-blur-xl max-w-sm'
              : 'relative p-3.5 bg-white border border-indigo-100 rounded-2xl rounded-tl-xs shadow-md shadow-indigo-500/5 max-w-sm'
          }
        >
          <div className="flex items-center gap-1.5 mb-0.5">
            <span
              className={
                variant === 'dark'
                  ? 'text-[11px] font-extrabold text-cyan-300 uppercase tracking-wider'
                  : 'text-[11px] font-extrabold text-indigo-700 uppercase tracking-wider'
              }
            >
              Yo‘lchi AI
            </span>
            <span className="w-1.5 h-1.5 rounded-full bg-cyan-400 animate-pulse" />
          </div>
          <p
            className={
              variant === 'dark'
                ? 'text-xs sm:text-sm font-semibold text-slate-200 leading-snug'
                : 'text-xs sm:text-sm font-semibold text-slate-800 leading-snug'
            }
          >
            {speechText}
          </p>
        </div>
      )}
    </div>
  );
};
