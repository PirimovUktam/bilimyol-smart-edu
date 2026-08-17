import React, { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  BookOpen,
  ArrowRight,
  ArrowLeft,
  CheckCircle2,
  Sparkles,
  Clock,
} from 'lucide-react';
import { useLessonStore } from '@/app/store/useLessonStore';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';
import { Badge } from '@/presentation/components/Badge';
import { MathFunctionGraph } from './MathFunctionGraph';
import { AudioSimWave } from './AudioSimWave';
import { YolchiAIPanel } from '../ai-tutor/YolchiAIPanel';
import { ReinforcementModal } from '../reinforcement/ReinforcementModal';
import { sounds } from '@/core/utils/soundEffects';

interface InteractiveLessonViewProps {
  lessonId: string;
  onFinish: () => void;
  onBackToRoadmap: () => void;
}

export const InteractiveLessonView: React.FC<InteractiveLessonViewProps> = ({
  lessonId,
  onFinish,
  onBackToRoadmap,
}) => {
  const {
    currentLesson,
    currentStepIndex,
    isLoading,
    isEvaluatingAnswer,
    lastAnswerResult,
    showAIPanel,
    showReinforcementModal,
    loadLesson,
    nextStep,
    prevStep,
    submitAnswer,
    openReinforcement,
    closeReinforcement,
    closeAIPanel,
  } = useLessonStore();

  const [pickedOption, setPickedOption] = useState<number | null>(null);

  useEffect(() => {
    loadLesson(lessonId);
  }, [lessonId, loadLesson]);

  if (isLoading || !currentLesson) {
    return (
      <div className="min-h-[60vh] flex items-center justify-center">
        <div className="text-center space-y-3">
          <div className="w-10 h-10 border-4 border-blue-600 border-t-transparent rounded-full animate-spin mx-auto" />
          <p className="text-sm font-semibold text-slate-600">Interaktiv dars yuklanmoqda...</p>
        </div>
      </div>
    );
  }

  const currentStep = currentLesson.steps[currentStepIndex];
  const isMath = currentLesson.courseId === 'course_math_01';

  const handleSelectQuizOption = (idx: number) => {
    if (isEvaluatingAnswer) return;
    setPickedOption(idx);
  };

  const handleAnswerSubmit = async () => {
    if (pickedOption === null || isEvaluatingAnswer) return;
    const res = await submitAnswer(pickedOption);
    if (res?.isCorrect) {
      sounds.playSuccess();
    } else {
      sounds.playMistake();
    }
  };

  return (
    <div className="max-w-4xl mx-auto px-4 py-8 space-y-6">
      {/* Top Breadcrumb & Progress */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-slate-200">
        <div className="flex items-center gap-3">
          <Button
            variant="ghost"
            size="sm"
            onClick={onBackToRoadmap}
            leftIcon={<ArrowLeft className="w-4 h-4" />}
            className="text-slate-500"
          >
            Yo‘l xaritasiga qaytish
          </Button>
          <div className="h-4 w-px bg-slate-200" />
          <Badge variant={isMath ? 'blue' : 'teal'} size="sm">
            <BookOpen className="w-3.5 h-3.5 mr-1" />
            {currentLesson.title}
          </Badge>
        </div>

        <div className="flex items-center gap-2 text-xs text-slate-500 font-medium">
          <Clock className="w-3.5 h-3.5" />
          <span>{currentLesson.estimatedMinutes} daqiqa</span>
          <span>•</span>
          <span>
            Qadam {currentStepIndex + 1} / {currentLesson.steps.length}
          </span>
        </div>
      </div>

      {/* Step Indicators */}
      <div className="flex items-center gap-2">
        {currentLesson.steps.map((st, idx) => {
          const isActive = currentStepIndex === idx;
          const isPassed = currentStepIndex > idx;
          return (
            <div
              key={st.id}
              className={`h-2 flex-1 rounded-full transition-all duration-300 ${
                isActive
                  ? 'bg-blue-600 shadow-sm'
                  : isPassed
                  ? 'bg-emerald-500'
                  : 'bg-slate-200'
              }`}
            />
          );
        })}
      </div>

      {/* Step Content Card */}
      <AnimatePresence mode="wait">
        <motion.div
          key={currentStep.id}
          initial={{ opacity: 0, y: 15 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -15 }}
          transition={{ duration: 0.25 }}
        >
          <Card className="p-7 sm:p-9 shadow-xl border-slate-200/90 space-y-6">
            {/* Step Header */}
            <div className="space-y-1">
              <div className="flex items-center gap-2">
                <span className="text-xs font-extrabold text-blue-600 uppercase tracking-wider">
                  Qadam {currentStep.stepNumber}
                </span>
                {currentStep.subtitle && (
                  <span className="text-xs font-semibold text-slate-400">
                    • {currentStep.subtitle}
                  </span>
                )}
              </div>
              <h2 className="text-2xl font-bold text-slate-900">{currentStep.title}</h2>
            </div>

            {/* Step Content Description */}
            <p className="text-sm sm:text-base text-slate-700 leading-relaxed whitespace-pre-line">
              {currentStep.content}
            </p>

            {/* Highlights */}
            {currentStep.highlightNotes && currentStep.highlightNotes.length > 0 && (
              <div className="p-4 bg-blue-50/70 border border-blue-200/80 rounded-2xl space-y-2">
                <span className="text-xs font-bold text-blue-800 uppercase tracking-wider block">
                  Asosiy Qoidalar:
                </span>
                <ul className="space-y-1.5">
                  {currentStep.highlightNotes.map((note, i) => (
                    <li key={i} className="text-xs sm:text-sm text-slate-800 flex items-start gap-2">
                      <CheckCircle2 className="w-4 h-4 text-blue-600 shrink-0 mt-0.5" />
                      <span>{note}</span>
                    </li>
                  ))}
                </ul>
              </div>
            )}

            {/* Step Formula Data (if any) */}
            {currentStep.formulaData && (
              <div className="p-6 bg-slate-900 text-white rounded-2xl space-y-4">
                <div className="text-center space-y-1">
                  <span className="text-xs text-slate-400 font-medium">Chiziqli Funksiya Ko‘rinishi:</span>
                  <div className="text-2xl sm:text-3xl font-mono font-bold text-teal-400 py-1">
                    {currentStep.formulaData.latex}
                  </div>
                  <p className="text-xs text-slate-300">{currentStep.formulaData.description}</p>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-3 border-t border-slate-800">
                  {currentStep.formulaData.variables.map((v, i) => (
                    <div key={i} className="p-3 bg-slate-800/80 rounded-xl border border-slate-700/80">
                      <span className="font-mono font-bold text-amber-300 text-sm">{v.symbol}</span>
                      <p className="text-xs text-slate-300 mt-0.5">{v.meaning}</p>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Step Visual Graph (if any) */}
            {currentStep.visualModelData?.type === 'function_graph' && <MathFunctionGraph />}

            {/* Step Audio Simulator (if any) */}
            {currentStep.visualModelData?.type === 'audio_wave' && (
              <AudioSimWave
                transcript={currentStep.visualModelData.audioTranscript || ''}
                speakerName={currentStep.visualModelData.speakerName || 'Audio Xabarchi'}
              />
            )}

            {/* Step Interactive Question (Quiz) */}
            {currentStep.interactiveQuestion && (
              <div className="pt-4 border-t border-slate-200 space-y-5">
                <div className="p-4 bg-indigo-50/70 border border-indigo-200 rounded-2xl space-y-2">
                  <div className="flex items-center gap-2 text-xs font-bold text-indigo-700 uppercase tracking-wider">
                    <Sparkles className="w-4 h-4" />
                    <span>Darsni Yakunlovchi Sinov Savoli</span>
                  </div>
                  <h3 className="text-base sm:text-lg font-bold text-slate-900">
                    {currentStep.interactiveQuestion.text}
                  </h3>
                  {currentStep.interactiveQuestion.formulaLatex && (
                    <div className="p-2 bg-white rounded-lg border border-indigo-200 font-mono font-bold text-blue-700 text-sm inline-block">
                      {currentStep.interactiveQuestion.formulaLatex}
                    </div>
                  )}
                </div>

                {/* Option buttons */}
                <div className="space-y-3">
                  {currentStep.interactiveQuestion.options.map((opt, idx) => {
                    const isSelected = pickedOption === idx;
                    return (
                      <button
                        key={idx}
                        type="button"
                        onClick={() => handleSelectQuizOption(idx)}
                        disabled={isEvaluatingAnswer}
                        className={`w-full text-left p-4 rounded-2xl border-2 transition-all flex items-center justify-between cursor-pointer ${
                          isSelected
                            ? 'border-blue-600 bg-blue-50/70 shadow-xs'
                            : 'border-slate-200 hover:border-slate-300 hover:bg-slate-50'
                        }`}
                      >
                        <span className="font-semibold text-slate-800 text-sm">{opt}</span>
                        {isSelected && <CheckCircle2 className="w-5 h-5 text-blue-600" />}
                      </button>
                    );
                  })}
                </div>

                {/* Quiz Submission Button */}
                <div className="pt-2 flex justify-end">
                  <Button
                    variant="primary"
                    size="lg"
                    disabled={pickedOption === null || isEvaluatingAnswer}
                    isLoading={isEvaluatingAnswer}
                    onClick={handleAnswerSubmit}
                    rightIcon={<ArrowRight className="w-5 h-5" />}
                  >
                    Javobni Tekshirish
                  </Button>
                </div>
              </div>
            )}

            {/* Navigation Buttons for Standard Content Steps */}
            {!currentStep.interactiveQuestion && (
              <div className="pt-6 border-t border-slate-100 flex items-center justify-between">
                <Button
                  variant="ghost"
                  size="md"
                  onClick={prevStep}
                  disabled={currentStepIndex === 0}
                  leftIcon={<ArrowLeft className="w-4 h-4" />}
                >
                  Oldingi
                </Button>

                <Button
                  variant="primary"
                  size="md"
                  onClick={nextStep}
                  rightIcon={<ArrowRight className="w-5 h-5" />}
                >
                  Keyingi qadam
                </Button>
              </div>
            )}
          </Card>
        </motion.div>
      </AnimatePresence>

      {/* Yo'lchi AI Feedback Panel */}
      <YolchiAIPanel
        isOpen={showAIPanel}
        explanation={lastAnswerResult?.aiExplanation || null}
        onProceedToReinforcement={openReinforcement}
        onClose={closeAIPanel}
      />

      {/* Reinforcement Exercise Modal */}
      <ReinforcementModal
        isOpen={showReinforcementModal}
        question={currentLesson.reinforcementExercise}
        courseId={currentLesson.courseId}
        skillId={currentLesson.skillId}
        onSuccess={() => {
          closeReinforcement();
          onFinish();
        }}
        onClose={closeReinforcement}
      />
    </div>
  );
};
