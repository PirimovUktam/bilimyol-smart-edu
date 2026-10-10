import React, { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { Sparkles, CheckCircle2, Loader2, Target, Lightbulb, Zap } from 'lucide-react';
import { Card } from '@/presentation/components/Card';

interface AILessonGeneratingCardProps {
  topic?: string;
  courseTitle?: string;
}

export const AILessonGeneratingCard: React.FC<AILessonGeneratingCardProps> = ({
  topic = 'Chiziqli tenglamalar',
  courseTitle = 'Matematika',
}) => {
  const [completedSteps, setCompletedSteps] = useState<number>(1);
  const [progress, setProgress] = useState<number>(25);

  useEffect(() => {
    const timer1 = setTimeout(() => {
      setCompletedSteps(2);
      setProgress(50);
    }, 400);

    const timer2 = setTimeout(() => {
      setCompletedSteps(3);
      setProgress(75);
    }, 900);

    const timer3 = setTimeout(() => {
      setCompletedSteps(4);
      setProgress(85);
    }, 1400);

    return () => {
      clearTimeout(timer1);
      clearTimeout(timer2);
      clearTimeout(timer3);
    };
  }, []);

  const checklist = [
    { id: 1, label: 'O‘quvchi profilini tahlil qilish' },
    { id: 2, label: 'Zaif mavzularni aniqlash' },
    { id: 3, label: 'Individual dars tuzish' },
    { id: 4, label: 'Misollar va savollarni tayyorlash' },
  ];

  return (
    <div className="min-h-[70vh] flex items-center justify-center px-4 py-8">
      <motion.div
        initial={{ opacity: 0, scale: 0.96 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ duration: 0.3 }}
        className="max-w-md w-full"
      >
        <Card className="p-8 shadow-2xl border-slate-200/90 bg-white relative overflow-hidden space-y-6">
          {/* Subtle gradient accent header */}
          <div className="absolute top-0 left-0 right-0 h-1.5 bg-gradient-to-r from-blue-600 via-indigo-500 to-teal-400" />

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

          {/* 4-Step Checklist matching Infographic 2 Step 7 */}
          <div className="space-y-3 py-2">
            {checklist.map((item) => {
              const isDone = completedSteps >= item.id;
              const isCurrent = completedSteps === item.id - 1;
              return (
                <motion.div
                  key={item.id}
                  initial={{ opacity: 0, x: -10 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: item.id * 0.1 }}
                  className={`flex items-center gap-3 p-3 rounded-2xl transition-all ${
                    isDone
                      ? 'bg-emerald-50/80 border border-emerald-200 text-emerald-900 font-bold text-sm'
                      : isCurrent
                      ? 'bg-blue-50/80 border border-blue-200 text-blue-900 font-semibold text-sm'
                      : 'text-slate-400 font-medium text-sm'
                  }`}
                >
                  {isDone ? (
                    <CheckCircle2 className="w-5 h-5 text-emerald-600 shrink-0" />
                  ) : isCurrent ? (
                    <Loader2 className="w-5 h-5 text-blue-600 shrink-0 animate-spin" />
                  ) : (
                    <div className="w-5 h-5 rounded-full border-2 border-slate-300 shrink-0" />
                  )}
                  <span>{item.label}</span>
                </motion.div>
              );
            })}
          </div>

          {/* Progress bar and 85% label */}
          <div className="space-y-2">
            <div className="flex items-center justify-between text-xs font-bold text-slate-600">
              <span>Tayyorgarlik darajasi</span>
              <span className="text-blue-600 font-extrabold">{progress}%</span>
            </div>
            <div className="h-2.5 w-full bg-slate-100 rounded-full overflow-hidden p-0.5 border border-slate-200">
              <motion.div
                className="h-full bg-gradient-to-r from-blue-600 to-indigo-600 rounded-full"
                initial={{ width: '25%' }}
                animate={{ width: `${progress}%` }}
                transition={{ duration: 0.4 }}
              />
            </div>
            <p className="text-[11px] text-slate-500 text-center italic pt-1">
              AI (Gemini 3.6 Flash) yordamida shaxsingiz uchun maxsus dars yaratilmoqda...
            </p>
          </div>

          {/* Bottom Value Badges matching Infographic 2 */}
          <div className="pt-4 border-t border-slate-100 grid grid-cols-1 gap-2 text-xs font-semibold text-slate-700">
            <div className="flex items-center gap-2">
              <Target className="w-4 h-4 text-emerald-600 shrink-0" />
              <span>O‘quvchining darajasiga mos</span>
            </div>
            <div className="flex items-center gap-2">
              <Lightbulb className="w-4 h-4 text-amber-500 shrink-0" />
              <span>Real hayotiy misollar bilan</span>
            </div>
            <div className="flex items-center gap-2">
              <Zap className="w-4 h-4 text-blue-600 shrink-0" />
              <span>Interaktiv va tushunarli formatda</span>
            </div>
          </div>
        </Card>
      </motion.div>
    </div>
  );
};
