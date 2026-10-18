import React from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Trophy, TrendingUp, Sparkles, ArrowRight, Play } from 'lucide-react';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';

interface SkillProgressItem {
  skillName: string;
  score: number;
  delta?: number;
}

interface LessonCompletionModalProps {
  isOpen: boolean;
  scorePercentage: number;
  correctCount: number;
  totalCount: number;
  courseTitle?: string;
  lessonTitle?: string;
  skillProgressList?: SkillProgressItem[];
  aiRecommendation?: string;
  onProceedToNext: () => void;
}

export const LessonCompletionModal: React.FC<LessonCompletionModalProps> = ({
  isOpen,
  scorePercentage,
  correctCount,
  totalCount,
  courseTitle = 'Tanlangan fan',
  lessonTitle = 'Chiziqli tenglamalar',
  skillProgressList = [],
  aiRecommendation = 'Siz ushbu dars mavzusini yaxshi o‘zlashtirdingiz. Keyingi mavzularni o‘rganishni tavsiya qilamiz.',
  onProceedToNext,
}) => {
  if (!isOpen) return null;

  const nextRecommendations = [
    { id: 1, title: 'Tenglamalar sistemasi', duration: '12 daqiqa', type: 'Nazariya + 5 test' },
    { id: 2, title: 'Matnli masalalar', duration: '15 daqiqa', type: 'Amaliy mashq' },
    { id: 3, title: 'Funksiyalar grafigi', duration: '10 daqiqa', type: 'Nazariya + 3 test' },
  ];

  return (
    <AnimatePresence>
      <div className="fixed inset-0 z-50 bg-slate-900/70 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
        <motion.div
          initial={{ opacity: 0, scale: 0.95, y: 20 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.95, y: 20 }}
          transition={{ duration: 0.3 }}
          className="max-w-2xl w-full my-8"
        >
          <Card className="p-7 sm:p-9 shadow-2xl border-2 border-emerald-500/80 bg-white relative overflow-hidden space-y-6">
            {/* Top decorative gradient bar */}
            <div className="absolute top-0 left-0 right-0 h-2 bg-gradient-to-r from-amber-400 via-emerald-500 to-blue-600" />

            {/* Header: Trophy & Congrats */}
            <div className="text-center space-y-2 pt-2">
              <div className="w-16 h-16 mx-auto rounded-3xl bg-gradient-to-tr from-amber-400 to-amber-500 text-white flex items-center justify-center shadow-xl shadow-amber-400/30">
                <Trophy className="w-8 h-8 text-amber-950" />
              </div>
              <h2 className="text-2xl sm:text-3xl font-black text-slate-900 tracking-tight">
                Dars yakunlandi!
              </h2>
              <p className="text-xs sm:text-sm font-semibold text-slate-500">
                {courseTitle} • {lessonTitle}
              </p>
            </div>

            {/* Score Stats Cards */}
            <div className="grid grid-cols-2 gap-4">
              <div className="p-4 bg-slate-50 rounded-2xl border border-slate-200 text-center space-y-1">
                <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
                  To‘g‘ri javoblar
                </span>
                <div className="text-2xl sm:text-3xl font-black text-slate-900">
                  {correctCount} / {totalCount}
                </div>
              </div>

              <div className="p-4 bg-emerald-50/80 rounded-2xl border border-emerald-200 text-center space-y-1">
                <span className="text-xs font-bold text-emerald-800 uppercase tracking-wider">
                  Natija
                </span>
                <div className="text-2xl sm:text-3xl font-black text-emerald-600">
                  {scorePercentage}%
                </div>
              </div>
            </div>

            {/* Updated Skill Levels matching Infographic 2 Step 10 */}
            <div className="p-5 bg-blue-50/60 rounded-3xl border border-blue-200/80 space-y-3">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <TrendingUp className="w-4 h-4 text-blue-600" />
                  <span className="text-xs font-bold text-slate-900 uppercase tracking-wider">
                    Bilim darajangiz yangilandi!
                  </span>
                </div>
                <span className="text-[11px] font-bold text-blue-700 bg-blue-100/80 px-2 py-0.5 rounded-full">
                  Real-time DB
                </span>
              </div>

              <div className="space-y-2">
                {skillProgressList.map((sk, idx) => (
                  <div
                    key={idx}
                    className="flex items-center justify-between p-2.5 bg-white/90 rounded-xl border border-blue-100 text-xs font-bold text-slate-800"
                  >
                    <span>{sk.skillName}</span>
                    <div className="flex items-center gap-2">
                      <span className="text-slate-900">{sk.score}%</span>
                      {sk.delta && sk.delta > 0 && (
                        <span className="text-emerald-600 text-[11px] flex items-center font-extrabold bg-emerald-50 px-1.5 py-0.5 rounded">
                          ↑ +{sk.delta}%
                        </span>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* AI Recommendation Banner matching Infographic 2 Step 10 */}
            <div className="p-4 bg-gradient-to-r from-indigo-50 to-blue-50 rounded-2xl border border-indigo-200 flex items-start gap-3">
              <div className="w-9 h-9 rounded-xl bg-indigo-600 text-white flex items-center justify-center shrink-0 shadow-md shadow-indigo-600/20">
                <Sparkles className="w-5 h-5 text-amber-200" />
              </div>
              <div className="space-y-0.5">
                <span className="text-xs font-extrabold text-indigo-900 uppercase tracking-wider block">
                  AI Tavsiyasi:
                </span>
                <p className="text-xs sm:text-sm font-semibold text-indigo-950 leading-relaxed">
                  {aiRecommendation}
                </p>
              </div>
            </div>

            {/* Recommended Next Lessons matching Infographic 2 Step 11 */}
            <div className="space-y-2">
              <span className="text-xs font-bold text-slate-500 uppercase tracking-wider block">
                Siz uchun tavsiya etilgan darslar:
              </span>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5">
                {nextRecommendations.map((rec) => (
                  <div
                    key={rec.id}
                    className="p-3 rounded-2xl border border-slate-200 bg-slate-50/70 hover:bg-slate-100/80 transition-all flex flex-col justify-between"
                  >
                    <div>
                      <div className="flex items-center justify-between text-xs font-bold text-blue-600">
                        <span>{rec.id}-qadam</span>
                        <Play className="w-3.5 h-3.5" />
                      </div>
                      <h4 className="text-xs font-bold text-slate-900 mt-1">{rec.title}</h4>
                    </div>
                    <div className="pt-2 text-[10px] text-slate-500 font-medium">
                      <span>{rec.duration}</span> • <span>{rec.type}</span>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Action CTA Button */}
            <div className="pt-2">
              <Button
                variant="primary"
                size="lg"
                onClick={onProceedToNext}
                rightIcon={<ArrowRight className="w-5 h-5" />}
                className="w-full text-center justify-center py-4 text-base font-bold shadow-xl shadow-blue-600/25"
              >
                Dashboardga qaytish
              </Button>
            </div>
          </Card>
        </motion.div>
      </div>
    </AnimatePresence>
  );
};
