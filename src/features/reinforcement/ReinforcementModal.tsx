import React, { useState } from 'react';
import { motion } from 'framer-motion';
import confetti from 'canvas-confetti';
import { CheckCircle2, Award, ArrowRight, Unlock, Zap, X } from 'lucide-react';
import { Question } from '@/domain/entities/Question';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';
import { sounds } from '@/core/utils/soundEffects';

interface ReinforcementModalProps {
  isOpen: boolean;
  question: Question;
  courseId: string;
  skillId: string;
  onSuccess: () => void;
  onClose: () => void;
}

export const ReinforcementModal: React.FC<ReinforcementModalProps> = ({
  isOpen,
  question,
  courseId,
  skillId,
  onSuccess,
  onClose,
}) => {
  const { completeReinforcement, isUpdating } = useRoadmapStore();

  const [selectedIdx, setSelectedIdx] = useState<number | null>(null);
  const [feedbackState, setFeedbackState] = useState<'answering' | 'success' | 'incorrect'>('answering');
  const [scoreTransition, setScoreTransition] = useState<{ oldScore: number; newScore: number } | null>(null);

  if (!isOpen) return null;

  const isMath = courseId === 'course_math_01';

  const handleSubmit = async () => {
    if (selectedIdx === null || isUpdating) return;

    const reinforcementNodeId = isMath ? 'reinf_node_math_func' : 'reinf_node_eng_list';

    const result = await completeReinforcement(
      courseId,
      skillId,
      reinforcementNodeId,
      question,
      selectedIdx
    );

    if (result.isCorrect) {
      sounds.playSuccess();
      setTimeout(() => sounds.playUnlock(), 300);

      // Trigger Confetti
      confetti({
        particleCount: 80,
        spread: 70,
        origin: { y: 0.6 },
      });

      setScoreTransition({ oldScore: result.oldScore, newScore: result.newScore });
      setFeedbackState('success');
    } else {
      sounds.playMistake();
      setFeedbackState('incorrect');
    }
  };

  return (
    <div className="fixed inset-0 z-50 bg-slate-900/70 backdrop-blur-xs flex items-center justify-center p-4">
      <motion.div
        initial={{ opacity: 0, scale: 0.95, y: 20 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        exit={{ opacity: 0, scale: 0.95, y: 20 }}
        transition={{ duration: 0.25 }}
        className="max-w-2xl w-full"
      >
        <Card className="p-7 sm:p-9 shadow-2xl border-2 border-teal-500 bg-white relative overflow-hidden">
          {feedbackState !== 'success' ? (
            <div className="space-y-6">
              {/* Header */}
              <div className="flex items-start justify-between gap-4">
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 rounded-2xl bg-teal-100 text-teal-700 flex items-center justify-center shrink-0">
                    <Zap className="w-6 h-6" />
                  </div>
                  <div>
                    <span className="text-xs font-bold text-teal-600 uppercase tracking-wider block">
                      Mustahkamlash Mashqi
                    </span>
                    <h3 className="text-xl font-bold text-slate-900">
                      Tushunchani amalda qo‘llang
                    </h3>
                  </div>
                </div>

                <button
                  onClick={onClose}
                  className="p-2 rounded-xl text-slate-400 hover:text-slate-600 hover:bg-slate-100 transition-colors cursor-pointer"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              {/* Question */}
              <div className="p-5 rounded-2xl bg-slate-50 border border-slate-200/80 space-y-3">
                <h4 className="text-base sm:text-lg font-bold text-slate-900">
                  {question.text}
                </h4>
                {question.formulaLatex && (
                  <div className="p-3 bg-white rounded-xl border border-slate-200 text-center font-mono font-bold text-blue-700 text-base">
                    {question.formulaLatex}
                  </div>
                )}
              </div>

              {/* Options */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                {question.options.map((opt, idx) => {
                  const isSelected = selectedIdx === idx;
                  return (
                    <button
                      key={idx}
                      type="button"
                      onClick={() => {
                        setSelectedIdx(idx);
                        setFeedbackState('answering');
                      }}
                      disabled={isUpdating}
                      className={`p-4 rounded-xl border-2 text-left font-bold text-sm transition-all cursor-pointer flex items-center justify-between ${
                        isSelected
                          ? 'border-teal-600 bg-teal-50 text-teal-900 shadow-xs'
                          : 'border-slate-200 hover:border-slate-300 hover:bg-slate-50 text-slate-800'
                      }`}
                    >
                      <span>{opt}</span>
                      {isSelected && <CheckCircle2 className="w-4 h-4 text-teal-600" />}
                    </button>
                  );
                })}
              </div>

              {feedbackState === 'incorrect' && (
                <div className="p-3 bg-rose-50 border border-rose-200 rounded-xl text-xs text-rose-700 font-medium">
                  Javob to‘g‘ri emas. E'tibor bering: avval ko‘paytirish, so‘ng qo‘shish bajariladi.
                </div>
              )}

              {/* Action Buttons */}
              <div className="pt-4 border-t border-slate-100 flex items-center justify-between">
                <Button variant="ghost" size="md" onClick={onClose} className="text-slate-500">
                  Bekor qilish
                </Button>

                <Button
                  variant="secondary"
                  size="lg"
                  disabled={selectedIdx === null || isUpdating}
                  isLoading={isUpdating}
                  onClick={handleSubmit}
                  rightIcon={<ArrowRight className="w-5 h-5" />}
                >
                  Javobni Tekshirish
                </Button>
              </div>
            </div>
          ) : (
            /* Success & Score Update Screen */
            <motion.div
              initial={{ opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              className="text-center space-y-6 py-4"
            >
              <div className="w-16 h-16 rounded-full bg-emerald-100 text-emerald-600 flex items-center justify-center mx-auto shadow-lg shadow-emerald-500/20">
                <CheckCircle2 className="w-9 h-9 stroke-[2.5]" />
              </div>

              <div className="space-y-1">
                <span className="px-3 py-1 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-200 text-xs font-extrabold uppercase tracking-wider">
                  Muvaffaqiyatli Mustahkamlandi!
                </span>
                <h3 className="text-2xl font-black text-slate-900 mt-2">
                  Ajoyib Natija!
                </h3>
                <p className="text-xs sm:text-sm text-slate-600 max-w-md mx-auto">
                  Siz xatoni to‘g‘riladingiz va tushunchani amalda qo‘llay oldingiz.
                </p>
              </div>

              {/* Score Transition Banner */}
              <div className="p-6 bg-slate-900 rounded-2xl text-white space-y-4 max-w-md mx-auto shadow-xl">
                <div className="flex items-center justify-between">
                  <span className="text-xs text-slate-400 font-medium">Ko‘nikma o‘zlashtirish darajasi:</span>
                  <span className="text-xs font-bold px-2 py-0.5 rounded bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
                    +22% O‘SISH
                  </span>
                </div>

                <div className="flex items-center justify-center gap-6">
                  <div className="text-center">
                    <span className="text-xs text-slate-400 block mb-1">Oldingi:</span>
                    <span className="text-2xl font-bold text-rose-400 line-through">
                      {scoreTransition?.oldScore}%
                    </span>
                  </div>

                  <ArrowRight className="w-6 h-6 text-teal-400 animate-pulse" />

                  <div className="text-center">
                    <span className="text-xs text-slate-400 block mb-1">Yangi:</span>
                    <span className="text-3xl sm:text-4xl font-black text-teal-400">
                      {scoreTransition?.newScore}%
                    </span>
                  </div>
                </div>

                <div className="pt-3 border-t border-slate-800 flex items-center justify-between text-xs text-slate-300">
                  <span className="flex items-center gap-1.5 text-amber-300 font-bold">
                    <Award className="w-4 h-4" /> +30 XP mukofoti
                  </span>
                  <span className="flex items-center gap-1.5 text-teal-300 font-bold">
                    <Unlock className="w-4 h-4" /> Keyingi mavzu ochildi
                  </span>
                </div>
              </div>

              <div className="pt-4">
                <Button
                  variant="primary"
                  size="lg"
                  onClick={onSuccess}
                  rightIcon={<ArrowRight className="w-5 h-5" />}
                  className="w-full sm:w-auto px-8"
                >
                  Dashboardga O‘tish
                </Button>
              </div>
            </motion.div>
          )}
        </Card>
      </motion.div>
    </div>
  );
};
