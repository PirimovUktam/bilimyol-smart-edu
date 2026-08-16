import React, { useState, useEffect } from 'react';
import { Play, Pause, Volume2, RotateCcw } from 'lucide-react';
import { sounds } from '@/core/utils/soundEffects';

interface AudioSimWaveProps {
  transcript: string;
  speakerName: string;
}

export const AudioSimWave: React.FC<AudioSimWaveProps> = ({ transcript, speakerName }) => {
  const [isPlaying, setIsPlaying] = useState(false);
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    let interval: ReturnType<typeof setInterval>;
    if (isPlaying) {
      interval = setInterval(() => {
        setProgress((prev) => {
          if (prev >= 100) {
            setIsPlaying(false);
            return 0;
          }
          return prev + 2;
        });
      }, 100);
    }
    return () => clearInterval(interval);
  }, [isPlaying]);

  const togglePlay = () => {
    if (!isPlaying) {
      sounds.playSuccess();
      setIsPlaying(true);
    } else {
      setIsPlaying(false);
    }
  };

  const handleReplay = () => {
    setProgress(0);
    setIsPlaying(true);
    sounds.playSuccess();
  };

  return (
    <div className="bg-slate-900 text-white rounded-2xl p-6 border border-slate-800 space-y-5">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-teal-500/20 text-teal-400 border border-teal-500/30 flex items-center justify-center">
            <Volume2 className="w-5 h-5" />
          </div>
          <div>
            <span className="text-xs font-bold text-teal-400 uppercase tracking-wider block">
              Audio Simulyator
            </span>
            <h4 className="text-sm font-bold text-white">{speakerName}</h4>
          </div>
        </div>

        <span className="text-xs font-mono px-2.5 py-1 rounded bg-slate-800 text-slate-300 border border-slate-700">
          00:{progress < 50 ? '03' : '06'} / 00:08
        </span>
      </div>

      {/* Simulated Waveform bars */}
      <div className="h-16 bg-slate-950 rounded-xl p-3 flex items-center justify-center gap-1.5 border border-slate-800/80 overflow-hidden">
        {Array.from({ length: 32 }).map((_, i) => {
          const isActive = (i / 32) * 100 <= progress;
          const randomHeight = isPlaying
            ? Math.max(20, Math.sin(i + progress / 5) * 80 + 30)
            : ((i % 5) + 2) * 15;

          return (
            <div
              key={i}
              className={`w-1.5 rounded-full transition-all duration-100 ${
                isActive
                  ? 'bg-teal-400 shadow-sm shadow-teal-400/50'
                  : 'bg-slate-700/60'
              }`}
              style={{ height: `${randomHeight}%` }}
            />
          );
        })}
      </div>

      {/* Player Controls */}
      <div className="flex items-center justify-between pt-1">
        <div className="flex items-center gap-3">
          <button
            onClick={togglePlay}
            className="w-11 h-11 rounded-xl bg-teal-500 hover:bg-teal-600 text-slate-950 font-bold flex items-center justify-center shadow-lg shadow-teal-500/20 transition-all cursor-pointer"
          >
            {isPlaying ? <Pause className="w-5 h-5 fill-current" /> : <Play className="w-5 h-5 fill-current translate-x-0.5" />}
          </button>
          <button
            onClick={handleReplay}
            className="p-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-colors cursor-pointer"
            title="Boshidan tinglash"
          >
            <RotateCcw className="w-4 h-4" />
          </button>
        </div>

        <div className="text-xs text-slate-400">
          {isPlaying ? 'Tinglanmoqda...' : 'Tinglash uchun "Play"ni bosing'}
        </div>
      </div>

      {/* Transcript with highlighting */}
      <div className="p-4 bg-slate-800/80 rounded-xl border border-slate-700/80 space-y-2">
        <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider block">
          Matn transkripsiyasi:
        </span>
        <p className="text-sm font-medium text-slate-200 leading-relaxed italic">
          "{transcript}"
        </p>
      </div>
    </div>
  );
};
