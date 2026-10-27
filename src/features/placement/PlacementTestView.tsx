import React, { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { CheckCircle2, ArrowRight, ShieldAlert, Cpu } from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { usePlacementStore } from '@/app/store/usePlacementStore';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';
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
    isLoading,
    error,
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

  const progressPercent = totalQuestionsToAsk > 0
    ? (questionNumber / totalQuestionsToAsk) * 100
    : 0;

  const handleSelectOption = (index: number) => {
    if (isSubmitting) return;
    setSelectedOption(index);
  };

  const handleConfirmAnswer = async () => {
    if (selectedOption === null || isSubmitting) return;

    const isDone = await submitAnswer(selectedOption);
    setSelectedOption(null);
    if (isDone) {
      sounds.playSuccess();
      onComplete();
    }
  };

  const getDifficultyLabel = (diff: string) => {
    switch (diff) {
      case 'easy':
        return 'OSON';
      case 'medium':
        return 'O‘RTA';
      case 'hard':
        return 'MURAKKAB';
      default:
        return 'ADAPTIV';
    }
  };

  if (isLoading) {
    return (
      <div className="min-h-[60vh] flex items-center justify-center">
        <div className="p-8 rounded-2xl bg-white border border-[#e4ddce] text-center space-y-4 max-w-sm shadow-xs">
          <div className="w-10 h-10 border-2 border-[#10151f] border-t-transparent rounded-full animate-spin mx-auto" />
          <div className="editorial-kicker justify-center">Yuklanmoqda</div>
          <p className="font-display text-sm font-bold text-slate-800">
            Diagnostika savollari tayyorlanmoqda...
          </p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-[60vh] flex items-center justify-center px-4">
        <Card className="max-w-md w-full p-8 text-center border-[#e4ddce] bg-white space-y-4 shadow-sm">
          <ShieldAlert className="w-10 h-10 text-coral mx-auto" />
          <div className="space-y-1">
            <div className="editorial-kicker justify-center text-coral">Xatolik</div>
            <h2 className="font-display text-lg font-bold text-[#10151f]">Diagnostika yuklanmadi</h2>
            <p className="text-xs text-slate-600 mt-1">{error}</p>
          </div>
          {activeCourse && (
            <Button
              variant="primary"
              onClick={() => {
                setSelectedOption(null);
                void initPlacement(activeCourse.id);
              }}
              className="w-full font-bold"
            >
              Qayta urinish
            </Button>
          )}
        </Card>
      </div>
    );
  }

  if (hasFinished) {
    return (
      <div className="min-h-[60vh] flex items-center justify-center px-4">
        <Card className="max-w-md w-full p-8 text-center border-[#e4ddce] bg-white space-y-5 shadow-sm">
          <div className="w-12 h-12 rounded-2xl bg-[#10151f] text-white flex items-center justify-center mx-auto shadow-md">
            <CheckCircle2 className="w-6 h-6 text-mint" />
          </div>
          <div className="space-y-1">
            <div className="editorial-kicker justify-center text-mint">Tugallandi</div>
            <h2 className="font-display text-xl font-bold text-[#10151f]">Diagnostika Yakunlandi</h2>
            <p className="text-xs text-slate-600 mt-1">
              Barcha savollar bo‘yicha individual ko‘nikma matritsangiz hisoblab chiqildi.
            </p>
          </div>
          <Button variant="primary" onClick={onComplete} className="w-full font-bold">
            Shaxsiy Yo‘lni Ko‘rish
          </Button>
        </Card>
      </div>
    );
  }

  if (!currentQuestion || totalQuestionsToAsk === 0) {
    return (
      <div className="min-h-[60vh] flex items-center justify-center px-4">
        <Card className="max-w-md w-full p-8 text-center border-[#e4ddce] bg-white space-y-4">
          <p className="text-sm font-semibold text-slate-600">Diagnostika uchun savollar mavjud emas.</p>
          {activeCourse && (
            <Button variant="outline" onClick={() => void initPlacement(activeCourse.id)}>
              Qayta yuklash
            </Button>
          )}
        </Card>
      </div>
    );
  }

  return (
    <div className="min-h-[calc(100vh-120px)] flex flex-col items-center justify-center px-4 py-8">
      <div className="max-w-2xl w-full space-y-6">
        {/* Header with progress */}
        <div className="flex flex-col sm:flex-row sm:items-end justify-between gap-4 pb-4 border-b border-[#e4ddce]">
          <div className="space-y-1">
            <div className="editorial-kicker">
              <span>ADAPTIV DIAGNOSTIKA</span>
              <span>//</span>
              <span>{activeCourse?.title || 'FAN'}</span>
            </div>
            <h1 className="font-display text-2xl font-extrabold text-[#10151f] tracking-tight">
              Bilim Darajangizni Aniqlash
            </h1>
          </div>

          <div className="flex items-center gap-2">
            <span className="font-mono text-[10px] font-bold px-2 py-0.5 rounded bg-[#f5efe4] text-slate-800 border border-[#e4ddce]">
              {getDifficultyLabel(currentQuestion.difficulty)}
            </span>
            <span className="font-mono text-xs font-bold text-slate-600 bg-white px-2.5 py-1 rounded-lg border border-[#e4ddce]">
              SAVOL {questionNumber} / {totalQuestionsToAsk}
            </span>
          </div>
        </div>

        {/* Progress bar */}
        <div className="h-1.5 w-full bg-[#f5efe4] rounded-full overflow-hidden border border-[#e4ddce]">
          <motion.div
            className="h-full bg-[#10151f]"
            initial={{ width: 0 }}
            animate={{ width: `${progressPercent}%` }}
            transition={{ duration: 0.3 }}
          />
        </div>

        {/* Question Card */}
        <AnimatePresence mode="wait">
          <motion.div
            key={currentQuestion.id}
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -12 }}
            transition={{ duration: 0.2 }}
          >
            <div className="p-7 sm:p-9 rounded-2xl border border-[#e4ddce] bg-white shadow-xs space-y-6">
              {/* Question Text */}
              <div className="space-y-3">
                <div className="flex items-start gap-3">
                  <span className="w-7 h-7 rounded-lg bg-[#10151f] text-white font-mono font-bold text-xs flex items-center justify-center shrink-0 mt-0.5">
                    {String(questionNumber).padStart(2, '0')}
                  </span>
                  <div className="space-y-2 flex-1">
                    <h2 className="font-display text-lg sm:text-xl font-bold text-slate-900 leading-snug">
                      {currentQuestion.text}
                    </h2>
                    {currentQuestion.formulaLatex && (
                      <div className="p-2.5 bg-[#fbf9f4] rounded-lg border border-[#e4ddce] font-mono font-bold text-sm text-brand-dark inline-block">
                        {currentQuestion.formulaLatex}
                      </div>
                    )}
                  </div>
                </div>
              </div>

              {/* Options */}
              <div className="space-y-2.5 pt-2">
                {currentQuestion.options.map((option, idx) => {
                  const isSelected = selectedOption === idx;
                  const optionLetters = ['A', 'B', 'C', 'D'];

                  return (
                    <button
                      key={idx}
                      type="button"
                      onClick={() => handleSelectOption(idx)}
                      disabled={isSubmitting}
                      className={`w-full text-left p-4 rounded-xl border transition-all flex items-center gap-3.5 cursor-pointer disabled:pointer-events-none ${
                        isSelected
                          ? 'border-[#10151f] ring-2 ring-[#10151f] bg-[#fbf9f4] shadow-xs'
                          : 'border-[#e4ddce] bg-white hover:border-slate-400 hover:bg-[#fbf9f4]'
                      }`}
                    >
                      <span
                        className={`w-7 h-7 rounded-lg font-mono font-bold text-xs flex items-center justify-center transition-colors shrink-0 ${
                          isSelected
                            ? 'bg-[#10151f] text-white'
                            : 'bg-[#f5efe4] text-slate-700 border border-[#e4ddce]'
                        }`}
                      >
                        {optionLetters[idx]}
                      </span>
                      <span className="font-mono text-sm font-bold text-slate-900 flex-1">
                        {option}
                      </span>
                      {isSelected && (
                        <CheckCircle2 className="w-5 h-5 text-[#10151f] shrink-0" />
                      )}
                    </button>
                  );
                })}
              </div>

              {/* Action Button */}
              <div className="pt-6 border-t border-[#e4ddce] flex items-center justify-between">
                <span className="font-mono text-[11px] text-slate-400 font-medium flex items-center gap-1.5">
                  <Cpu className="w-3.5 h-3.5" />
                  Ko‘nikma matritsasi yangilanadi
                </span>

                <Button
                  variant="primary"
                  size="md"
                  disabled={selectedOption === null || isSubmitting}
                  isLoading={isSubmitting}
                  onClick={handleConfirmAnswer}
                  rightIcon={<ArrowRight className="w-4 h-4" />}
                  className="font-bold uppercase tracking-wider text-xs px-6 py-2.5"
                >
                  {questionNumber >= totalQuestionsToAsk ? 'Natijani Ko‘rish' : 'Keyingi Savol'}
                </Button>
              </div>
            </div>
          </motion.div>
        </AnimatePresence>
      </div>
    </div>
  );
};
