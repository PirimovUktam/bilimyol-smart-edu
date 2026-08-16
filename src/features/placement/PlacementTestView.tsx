import React, { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { CheckCircle2, Zap, ArrowRight, ShieldAlert } from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { usePlacementStore } from '@/app/store/usePlacementStore';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';
import { Badge } from '@/presentation/components/Badge';
import { sounds } from '@/core/utils/soundEffects';

interface PlacementTestViewProps {
  onComplete: () => void;
}

export const PlacementTestView: React.FC<PlacementTestViewProps> = ({ onComplete }) => {
  const { activeCourse } = useCourseStore();
  const {
    questions,
    currentQuestionIndex,
    isSubmitting,
    initPlacement,
    submitAnswer,
    hasFinished,
  } = usePlacementStore();

  const [selectedOption, setSelectedOption] = useState<number | null>(null);

  useEffect(() => {
    if (activeCourse) {
      initPlacement(activeCourse.id);
    }
  }, [activeCourse, initPlacement]);

  const currentQ = questions[currentQuestionIndex];
  const progressPercent = questions.length > 0 ? (currentQuestionIndex / questions.length) * 100 : 0;

  const handleSelectOption = (index: number) => {
    if (isSubmitting) return;
    setSelectedOption(index);
  };

  const handleConfirmAnswer = async () => {
    if (selectedOption === null || isSubmitting || !currentQ) return;
    sounds.playSuccess();
    const isDone = await submitAnswer(selectedOption);
    setSelectedOption(null);
    if (isDone) {
      onComplete();
    }
  };

  // Demo shortcut: Auto-complete placement with calibrated weak focus
  const handleAutoCalibrateDemo = async () => {
    if (isSubmitting || questions.length === 0) return;
    // Answer correctly for Q1, Q2, Q4; Miss Q3 & Q5 (Focus skill: Funksiyalar / Listening)
    for (let i = 0; i < questions.length; i++) {
      const q = questions[i];
      const shouldMiss = q.skillId === 'skill_math_functions' || q.skillId === 'skill_eng_listening';
      const pickIndex = shouldMiss ? (q.correctIndex + 1) % q.options.length : q.correctIndex;
      const isDone = await submitAnswer(pickIndex);
      if (isDone) {
        onComplete();
        break;
      }
    }
  };

  if (!currentQ || hasFinished) {
    return (
      <div className="min-h-[60vh] flex items-center justify-center">
        <div className="text-center space-y-3">
          <div className="w-10 h-10 border-4 border-blue-600 border-t-transparent rounded-full animate-spin mx-auto" />
          <p className="text-sm font-semibold text-slate-600">
            {hasFinished ? 'Natijalar hisoblanmoqda...' : 'Placement test tayyorlanmoqda...'}
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-[calc(100vh-120px)] flex flex-col items-center justify-center px-4 py-8">
      <div className="max-w-3xl w-full">
        {/* Header with progress */}
        <div className="mb-6 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <div className="flex items-center gap-2">
              <Badge variant="blue" size="sm">
                Placement Test • {activeCourse?.title}
              </Badge>
              <span className="text-xs font-semibold text-slate-500">
                Savol {currentQuestionIndex + 1} / {questions.length}
              </span>
            </div>
            <h1 className="text-xl font-bold text-slate-900 mt-1">
              Boshlang‘ich bilim darajasini aniqlash
            </h1>
          </div>

          <Button
            variant="outline"
            size="sm"
            onClick={handleAutoCalibrateDemo}
            leftIcon={<Zap className="w-3.5 h-3.5 text-amber-500" />}
            className="text-slate-600 hover:text-blue-600 text-xs border-dashed"
            title="Hakamlar / Demo uchun 1-bosishda kalibrlangan 41% fokus bilan to‘ldirish"
          >
            Tezkor Demo To‘ldirish
          </Button>
        </div>

        {/* Progress bar */}
        <div className="h-2 w-full bg-slate-200 rounded-full overflow-hidden mb-6">
          <motion.div
            className="h-full bg-gradient-to-r from-blue-600 to-teal-500"
            initial={{ width: 0 }}
            animate={{ width: `${progressPercent}%` }}
            transition={{ duration: 0.3 }}
          />
        </div>

        {/* Question Card */}
        <AnimatePresence mode="wait">
          <motion.div
            key={currentQ.id}
            initial={{ opacity: 0, y: 15 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -15 }}
            transition={{ duration: 0.25 }}
          >
            <Card className="p-7 sm:p-9 shadow-xl border-slate-200/90 space-y-6">
              {/* Question Text */}
              <div className="space-y-3">
                <div className="flex items-start gap-3">
                  <span className="w-8 h-8 rounded-xl bg-blue-100 text-blue-700 font-extrabold text-sm flex items-center justify-center shrink-0 mt-0.5">
                    {currentQuestionIndex + 1}
                  </span>
                  <div className="space-y-2 flex-1">
                    <h2 className="text-lg sm:text-xl font-bold text-slate-900 leading-snug">
                      {currentQ.text}
                    </h2>
                    {currentQ.contextSnippet && (
                      <div className="p-3.5 bg-slate-50 rounded-xl border border-slate-200 text-sm text-slate-700 font-medium">
                        {currentQ.contextSnippet}
                      </div>
                    )}
                  </div>
                </div>
              </div>

              {/* Options */}
              <div className="space-y-3 pt-2">
                {currentQ.options.map((option, idx) => {
                  const isSelected = selectedOption === idx;
                  const optionLetters = ['A', 'B', 'C', 'D'];

                  return (
                    <button
                      key={idx}
                      type="button"
                      onClick={() => handleSelectOption(idx)}
                      disabled={isSubmitting}
                      className={`w-full text-left p-4 rounded-2xl border-2 transition-all flex items-center gap-3.5 cursor-pointer disabled:pointer-events-none ${
                        isSelected
                          ? 'border-blue-600 bg-blue-50/70 shadow-xs'
                          : 'border-slate-200 hover:border-slate-300 hover:bg-slate-50/50'
                      }`}
                    >
                      <span
                        className={`w-7 h-7 rounded-xl font-bold text-xs flex items-center justify-center transition-colors ${
                          isSelected
                            ? 'bg-blue-600 text-white'
                            : 'bg-slate-100 text-slate-600 border border-slate-200'
                        }`}
                      >
                        {optionLetters[idx]}
                      </span>
                      <span className="font-semibold text-slate-800 text-sm flex-1">
                        {option}
                      </span>
                      {isSelected && (
                        <CheckCircle2 className="w-5 h-5 text-blue-600 shrink-0" />
                      )}
                    </button>
                  );
                })}
              </div>

              {/* Action Button */}
              <div className="pt-6 border-t border-slate-100 flex items-center justify-between">
                <span className="text-xs text-slate-400 font-medium flex items-center gap-1.5">
                  <ShieldAlert className="w-3.5 h-3.5" />
                  Javoblar deterministic scoring orqali hisoblanadi
                </span>

                <Button
                  variant="primary"
                  size="md"
                  disabled={selectedOption === null || isSubmitting}
                  isLoading={isSubmitting}
                  onClick={handleConfirmAnswer}
                  rightIcon={<ArrowRight className="w-4 h-4" />}
                >
                  {currentQuestionIndex === questions.length - 1 ? 'Natijani Ko‘rish' : 'Tasdiqlash'}
                </Button>
              </div>
            </Card>
          </motion.div>
        </AnimatePresence>
      </div>
    </div>
  );
};
