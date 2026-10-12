import React, { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { CheckCircle2, ArrowRight, ShieldAlert, Sparkles, Brain } from 'lucide-react';
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
        <div className="text-center space-y-4">
          <div className="relative w-14 h-14 mx-auto flex items-center justify-center">
            <div className="absolute inset-0 rounded-full border-4 border-cyan-500/20 border-t-cyan-400 animate-spin" />
            <Brain className="w-6 h-6 text-cyan-400 animate-pulse" />
          </div>
          <p className="text-sm font-semibold text-slate-300">
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
              <Badge variant="blue" size="sm" className="bg-cyan-950/80 text-cyan-300 border-cyan-500/40 shadow-xs shadow-cyan-500/20">
                <Brain className="w-3.5 h-3.5 mr-1 text-cyan-400" />
                Adaptiv Diagnostika • {activeCourse?.title || 'Matematika'}
              </Badge>
              <Badge variant="slate" size="sm" className="bg-slate-800/80 text-slate-300 border-slate-700">
                {getDifficultyLabel(currentQuestion.difficulty)}
              </Badge>
              <span className="text-xs font-semibold text-slate-400">
                Savol {questionNumber} / {totalQuestionsToAsk}
              </span>
            </div>
            <h1 className="text-xl sm:text-2xl font-black text-white mt-1.5 tracking-tight">
              Bilim darajangizni aniqlash
            </h1>
          </div>
        </div>

        {/* Progress bar */}
        <div className="h-2.5 w-full bg-slate-800/90 rounded-full overflow-hidden mb-6 border border-slate-700/60">
          <motion.div
            className="h-full bg-gradient-to-r from-cyan-400 via-blue-500 to-indigo-500 shadow-sm shadow-cyan-500/40"
            initial={{ width: 0 }}
            animate={{ width: `${progressPercent}%` }}
            transition={{ duration: 0.4 }}
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
            <Card variant="cosmicGlow" className="p-7 sm:p-9 bg-slate-900/90 space-y-6">
              {/* Question Text */}
              <div className="space-y-3">
                <div className="flex items-start gap-3.5">
                  <span className="w-9 h-9 rounded-xl bg-cyan-500/15 text-cyan-300 border border-cyan-500/40 font-black text-sm flex items-center justify-center shrink-0 mt-0.5 shadow-sm shadow-cyan-500/20">
                    {questionNumber}
                  </span>
                  <div className="space-y-2.5 flex-1">
                    <h2 className="text-lg sm:text-xl font-bold text-white leading-relaxed">
                      {currentQuestion.text}
                    </h2>
                    {currentQuestion.formulaLatex && (
                      <div className="p-3 bg-slate-950/80 rounded-xl border border-cyan-500/30 font-mono text-sm text-cyan-300 inline-block shadow-inner">
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
                          ? 'border-cyan-400 bg-cyan-950/60 text-white shadow-md shadow-cyan-500/25 ring-1 ring-cyan-400/50'
                          : 'border-slate-800 bg-slate-900/70 text-slate-300 hover:border-slate-700 hover:bg-slate-800/80 hover:text-white'
                      }`}
                    >
                      <span
                        className={`w-7 h-7 rounded-xl font-black text-xs flex items-center justify-center transition-colors ${
                          isSelected
                            ? 'bg-gradient-to-r from-cyan-400 to-blue-500 text-slate-950 shadow-xs'
                            : 'bg-slate-800 text-slate-400 border border-slate-700'
                        }`}
                      >
                        {optionLetters[idx]}
                      </span>
                      <span className="font-semibold text-sm flex-1">
                        {option}
                      </span>
                      {isSelected && (
                        <CheckCircle2 className="w-5 h-5 text-cyan-400 shrink-0" />
                      )}
                    </button>
                  );
                })}
              </div>

              {/* Action Button */}
              <div className="pt-6 border-t border-slate-800/80 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                <span className="text-xs text-slate-400 font-medium flex items-center gap-1.5">
                  <ShieldAlert className="w-3.5 h-3.5 text-cyan-400" />
                  Har bir javob real ko‘nikma foiziga ta’sir qiladi
                </span>

                <Button
                  variant="cyan"
                  size="md"
                  disabled={selectedOption === null || isSubmitting}
                  isLoading={isSubmitting}
                  onClick={handleConfirmAnswer}
                  rightIcon={<ArrowRight className="w-4 h-4" />}
                  className="font-black px-6"
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
