import React from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Trophy, TrendingUp, Sparkles, ArrowRight, Play } from 'lucide-react';
import { Button } from '@/presentation/components/Button';

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
      <div className="fixed inset-0 z-50 bg-[#10151f]/75 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
        <motion.div
          initial={{ opacity: 0, scale: 0.96, y: 16 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.96, y: 16 }}
          transition={{ duration: 0.25 }}
          className="max-w-xl w-full my-8"
        >
          <div className="p-7 sm:p-9 shadow-2xl rounded-2xl border border-[#e4ddce] bg-white relative overflow-hidden space-y-6">
            {/* Top architectural accent strip */}
            <div className="absolute top-0 left-0 right-0 h-1.5 bg-[#10151f]" />

            {/* Header: Trophy & Congrats */}
            <div className="text-center space-y-2 pt-1">
              <div className="w-14 h-14 mx-auto rounded-2xl bg-[#10151f] text-white flex items-center justify-center shadow-lg">
                <Trophy className="w-7 h-7 text-amber-400" />
              </div>
              <div className="editorial-kicker justify-center">Modul Yakuni</div>
              <h2 className="text-2xl sm:text-3xl font-display font-extrabold text-[#10151f] tracking-tight">
                Dars Muvaffaqiyatli Yakunlandi
              </h2>
              <p className="font-mono text-xs text-slate-500 uppercase tracking-wider">
                {courseTitle} // {lessonTitle}
              </p>
            </div>

            {/* Score Stats Cards */}
            <div className="grid grid-cols-2 gap-3">
              <div className="p-4 bg-[#fbf9f4] rounded-xl border border-[#e4ddce] text-center space-y-1">
                <span className="font-mono text-[10px] font-bold text-slate-500 uppercase tracking-wider">
                  To‘g‘ri javoblar
                </span>
                <div className="font-mono-num text-2xl sm:text-3xl font-extrabold text-[#10151f]">
                  {correctCount} / {totalCount}
                </div>
              </div>

              <div className="p-4 bg-mint/10 rounded-xl border border-mint/25 text-center space-y-1">
                <span className="font-mono text-[10px] font-bold text-mint uppercase tracking-wider">
                  O‘zlashtirish
                </span>
                <div className="font-mono-num text-2xl sm:text-3xl font-extrabold text-mint">
                  {scorePercentage}%
                </div>
              </div>
            </div>

            {/* Updated Skill Levels */}
            <div className="p-4 bg-[#fbf9f4] rounded-xl border border-[#e4ddce] space-y-3">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <TrendingUp className="w-4 h-4 text-brand" />
                  <span className="font-mono text-xs font-bold text-slate-900 uppercase tracking-wider">
                    Bilim matritsasi yangilandi
                  </span>
                </div>
                <span className="font-mono text-[10px] font-bold text-brand-dark bg-brand/8 border border-brand/25 px-2 py-0.5 rounded">
                  SYNCED
                </span>
              </div>

              <div className="space-y-2">
                {skillProgressList.map((sk, idx) => (
                  <div
                    key={idx}
                    className="flex items-center justify-between p-2.5 bg-white rounded-lg border border-[#e4ddce] text-xs font-bold text-slate-800"
                  >
                    <span>{sk.skillName}</span>
                    <div className="flex items-center gap-2">
                      <span className="font-mono font-bold text-slate-900">{sk.score}%</span>
                      {sk.delta && sk.delta > 0 && (
                        <span className="text-mint text-[10px] font-mono font-bold bg-emerald-100/70 border border-mint/30 px-1.5 py-0.5 rounded">
                          +{sk.delta}%
                        </span>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* AI Recommendation Banner */}
            <div className="p-4 bg-[#10151f] text-white rounded-xl border border-slate-800 flex items-start gap-3">
              <div className="w-8 h-8 rounded-lg bg-brand text-white flex items-center justify-center shrink-0">
                <Sparkles className="w-4 h-4 text-amber-300" />
              </div>
              <div className="space-y-1">
                <span className="font-mono text-[10px] font-bold text-path uppercase tracking-widest block">
                  Yo‘lchi AI Tavsiyasi:
                </span>
                <p className="text-xs sm:text-sm text-slate-200 leading-relaxed font-sans">
                  {aiRecommendation}
                </p>
              </div>
            </div>

            {/* Recommended Next Lessons */}
            <div className="space-y-2">
              <span className="font-mono text-[10px] font-bold text-slate-500 uppercase tracking-wider block">
                Tavsiya etilgan keyingi qadamlar:
              </span>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
                {nextRecommendations.map((rec) => (
                  <div
                    key={rec.id}
                    className="p-3 rounded-xl border border-[#e4ddce] bg-[#fbf9f4] hover:bg-white transition-all flex flex-col justify-between"
                  >
                    <div>
                      <div className="flex items-center justify-between font-mono text-[10px] font-bold text-brand-dark">
                        <span>QADAM #{rec.id}</span>
                        <Play className="w-3 h-3" />
                      </div>
                      <h4 className="font-display text-xs font-bold text-slate-900 mt-1">{rec.title}</h4>
                    </div>
                    <div className="pt-2 font-mono text-[9px] text-slate-500">
                      <span>{rec.duration}</span> • <span>{rec.type}</span>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Action CTA Button */}
            <div className="pt-1">
              <Button
                variant="primary"
                size="lg"
                onClick={onProceedToNext}
                rightIcon={<ArrowRight className="w-5 h-5" />}
                className="w-full text-center justify-center py-3.5 text-sm font-bold"
              >
                Dashboardga qaytish
              </Button>
            </div>
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  );
};
