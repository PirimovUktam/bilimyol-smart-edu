import React, { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { CheckCircle2, ArrowRight, ShieldAlert } from 'lucide-react';
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
    currentQuestion,
    questionNumber,
    totalQuestionsToAsk,
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

  const progressPercent = (questionNumber / totalQuestionsToAsk) * 100;

  const handleSelectOption = (index: number) => {
    if (isSubmitting) return;
    setSelectedOption(index);
  };

  const handleConfirmAnswer = async () => {
    if (selectedOption === null || isSubmitting) return;

    sounds.playSuccess();
    const isDone = await submitAnswer(selectedOption);
    setSelectedOption(null);
    if (isDone) {
      onComplete();
    }
  };

  const getDifficultyLabel = (diff: string) => {
    switch (diff) {
      case 'easy':
        return 'Oson daraja';
      case 'medium':
        return 'O‘rta daraja';
      case 'hard':
        return 'Murakkab daraja';
      default:
        return 'Moslashuvchan';
    }
  };

  if (!currentQuestion || hasFinished) {
    return (
      <div className="min-h-[60vh] flex items-center justify-center">
        <div className="text-center space-y-3">
          <div className="w-10 h-10 border-4 border-blue-600 border-t-transparent rounded-full animate-spin mx-auto" />
          <p className="text-sm font-semibold text-slate-600">
            {hasFinished ? 'Real bilim darajangiz hisoblanmoqda...' : 'Savol tayyorlanmoqda...'}
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
                Adaptiv Diagnostika • {activeCourse?.title || 'Matematika'}
              </Badge>
              <Badge variant="slate" size="sm">
                {getDifficultyLabel(currentQuestion.difficulty)}
              </Badge>
              <span className="text-xs font-semibold text-slate-500">
                Savol {questionNumber} / {totalQuestionsToAsk}
              </span>
            </div>
            <h1 className="text-xl font-bold text-slate-900 mt-1">
              Bilim darajangizni aniqlash
            </h1>
          </div>
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
            key={currentQuestion.id}
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
                    {questionNumber}
                  </span>
                  <div className="space-y-2 flex-1">
                    <h2 className="text-lg sm:text-xl font-bold text-slate-900 leading-snug">
                      {currentQuestion.text}
                    </h2>
                    {currentQuestion.formulaLatex && (
                      <div className="p-2.5 bg-blue-50/60 rounded-xl border border-blue-100 font-mono text-sm text-blue-900 inline-block">
                        {currentQuestion.formulaLatex}
                      </div>
                    )}
                  </div>
                </div>
              </div>

              {/* Options */}
              <div className="space-y-3 pt-2">
                {currentQuestion.options.map((option, idx) => {
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
                  Har bir javob real ko‘nikma foiziga ta’sir qiladi
                </span>

                <Button
                  variant="primary"
                  size="md"
                  disabled={selectedOption === null || isSubmitting}
                  isLoading={isSubmitting}
                  onClick={handleConfirmAnswer}
                  rightIcon={<ArrowRight className="w-4 h-4" />}
                >
                  {questionNumber >= totalQuestionsToAsk ? 'Natijani Ko‘rish' : 'Keyingi Savol'}
                </Button>
              </div>
            </Card>
          </motion.div>
        </AnimatePresence>
      </div>
    </div>
  );
};
