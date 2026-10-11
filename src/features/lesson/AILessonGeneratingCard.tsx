import React, { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { Sparkles, AlertCircle, RefreshCw, ArrowLeft, Loader2, Target, Lightbulb, Zap } from 'lucide-react';
import { Card } from '@/presentation/components/Card';
import { Button } from '@/presentation/components/Button';

interface AILessonGeneratingCardProps {
  topic?: string;
  courseTitle?: string;
  error?: string | null;
  onRetry?: () => void;
  onCancel?: () => void;
  timeoutMs?: number;
}

export const AILessonGeneratingCard: React.FC<AILessonGeneratingCardProps> = ({
  topic = 'Dars mavzusi',
  courseTitle = 'Fan',
  error,
  onRetry,
  onCancel,
  timeoutMs = 15000,
}) => {
  const [isTimedOut, setIsTimedOut] = useState(false);

  useEffect(() => {
    if (error) return;

    const timer = setTimeout(() => {
      setIsTimedOut(true);
    }, timeoutMs);

    return () => clearTimeout(timer);
  }, [error, timeoutMs]);

  const hasError = Boolean(error || isTimedOut);
  const displayErrorMessage =
    error ||
    'Darsni shakllantirish uchun serverdan javob kutish vaqti tugadi (Timeout). Iltimos, qayta urinib ko‘ring.';

  const handleRetry = () => {
    setIsTimedOut(false);
    if (onRetry) {
      onRetry();
    }
  };

  return (
    <div className="min-h-[70vh] flex items-center justify-center px-4 py-8">
      <motion.div
        initial={{ opacity: 0, scale: 0.96 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ duration: 0.3 }}
        className="max-w-md w-full"
      >
        <Card className="p-6 sm:p-8 shadow-2xl border-slate-200/90 bg-white relative overflow-hidden space-y-6">
          {/* Subtle gradient accent header */}
          <div
            className={`absolute top-0 left-0 right-0 h-1.5 ${
              hasError
                ? 'bg-rose-500'
                : 'bg-gradient-to-r from-blue-600 via-indigo-500 to-teal-400'
            }`}
          />

          {hasError ? (
            /* Error & Timeout State */
            <div className="space-y-6 text-center pt-2">
              <div className="w-16 h-16 mx-auto rounded-3xl bg-rose-50 text-rose-600 border border-rose-200 flex items-center justify-center shadow-lg shadow-rose-500/10">
                <AlertCircle className="w-8 h-8" />
              </div>

              <div className="space-y-2">
                <h2 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight">
                  Darsni ochishda xatolik
                </h2>
                <p className="text-xs font-semibold text-slate-500">
                  {courseTitle} • <span className="text-slate-700">{topic}</span>
                </p>
                <div className="p-3.5 rounded-2xl bg-rose-50/80 border border-rose-200/90 text-rose-950 text-xs font-medium text-left leading-relaxed">
                  {displayErrorMessage}
                </div>
              </div>

              <div className="flex flex-col sm:flex-row gap-3 pt-2">
                {onRetry && (
                  <Button
                    variant="primary"
                    onClick={handleRetry}
                    leftIcon={<RefreshCw className="w-4 h-4" />}
                    className="flex-1 font-bold justify-center"
                  >
                    Qayta urinish
                  </Button>
                )}
                {onCancel && (
                  <Button
                    variant="outline"
                    onClick={onCancel}
                    leftIcon={<ArrowLeft className="w-4 h-4" />}
                    className="flex-1 font-bold justify-center"
                  >
                    Ortga qaytish
                  </Button>
                )}
              </div>
            </div>
          ) : (
            /* Indeterminate Real Loading State (Never stuck at fake 85%) */
            <div className="space-y-6">
              {/* Top Robot / AI Sparkle Icon */}
              <div className="text-center space-y-3 pt-2">
                <div className="w-16 h-16 mx-auto rounded-3xl bg-gradient-to-tr from-blue-600 via-indigo-600 to-teal-500 text-white flex items-center justify-center shadow-xl shadow-blue-500/25 relative">
                  <Sparkles className="w-8 h-8 animate-pulse text-amber-200" />
                </div>
                <div>
                  <h2 className="text-2xl font-black text-slate-900 tracking-tight">
                    AI dars yaratmoqda...
                  </h2>
                  <p className="text-xs font-semibold text-slate-500 mt-1">
                    {courseTitle} • <span className="text-blue-600 font-bold">{topic}</span>
                  </p>
                </div>
              </div>

              {/* Indeterminate Animated Progress Bar */}
              <div className="space-y-2">
                <div className="flex items-center justify-between text-xs font-bold text-slate-600">
                  <span className="flex items-center gap-1.5 text-blue-600">
                    <Loader2 className="w-3.5 h-3.5 animate-spin" />
                    Yo‘lchi AI tahlili jarayonda...
                  </span>
                  <span className="text-slate-400 font-semibold text-[11px]">Kuting...</span>
                </div>
                <div className="h-2.5 w-full bg-slate-100 rounded-full overflow-hidden relative">
                  <motion.div
                    className="absolute top-0 bottom-0 w-1/3 bg-gradient-to-r from-blue-600 via-indigo-500 to-teal-400 rounded-full"
                    animate={{
                      left: ['-35%', '100%'],
                    }}
                    transition={{
                      repeat: Infinity,
                      duration: 1.6,
                      ease: 'easeInOut',
                    }}
                  />
                </div>
                <p className="text-[11px] text-slate-500 text-center italic pt-1">
                  Bilim darajangizga mos tushuntirish va misollar generatsiya qilinmoqda...
                </p>
              </div>

              {/* Pedagogical Feature Pills */}
              <div className="pt-4 border-t border-slate-100 grid grid-cols-1 gap-2 text-xs font-semibold text-slate-700">
                <div className="flex items-center gap-2">
                  <Target className="w-4 h-4 text-emerald-600 shrink-0" />
                  <span>Siz tanlagan fanga mos interaktiv kontent</span>
                </div>
                <div className="flex items-center gap-2">
                  <Lightbulb className="w-4 h-4 text-amber-500 shrink-0" />
                  <span>Real hayotiy misollar va tushuntirishlar</span>
                </div>
                <div className="flex items-center gap-2">
                  <Zap className="w-4 h-4 text-blue-600 shrink-0" />
                  <span>Dars yakunida o‘zlashtirishni tekshiruvchi test</span>
                </div>
              </div>

              {/* Cancel button so user is never trapped */}
              {onCancel && (
                <div className="pt-2 text-center">
                  <button
                    type="button"
                    onClick={onCancel}
                    className="text-xs text-slate-400 hover:text-slate-700 font-semibold transition-colors cursor-pointer"
                  >
                    Kutishni bekor qilish va ortga qaytish
                  </button>
                </div>
              )}
            </div>
          )}
        </Card>
      </motion.div>
    </div>
  );
};
