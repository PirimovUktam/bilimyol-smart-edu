import React, { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  BookOpen,
  ArrowRight,
  ArrowLeft,
  CheckCircle2,
  Sparkles,
  Clock,
  Lightbulb,
  FileText,
  HelpCircle,
  XCircle,
  RotateCcw,
} from 'lucide-react';
import { useLessonStore } from '@/app/store/useLessonStore';
import { useCourseStore } from '@/app/store/useCourseStore';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';
import { Badge } from '@/presentation/components/Badge';
import { MathFunctionGraph } from './MathFunctionGraph';
import { AudioSimWave } from './AudioSimWave';
import { AILessonGeneratingCard } from './AILessonGeneratingCard';
import { LessonCompletionModal } from './LessonCompletionModal';
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
  const { activeCourse } = useCourseStore();
  const {
    currentLesson,
    currentStepIndex,
    isLoading,
    isEvaluatingAnswer,
    lastAnswerResult,
    showAIPanel,
    showReinforcementModal,
    isCompleted,
    loadLesson,
    nextStep,
    prevStep,
    goToStep,
    submitAnswer,
    openReinforcement,
    closeReinforcement,
    closeAIPanel,
  } = useLessonStore();

  const [pickedOption, setPickedOption] = useState<number | null>(null);
  const [hasSubmittedCurrent, setHasSubmittedCurrent] = useState<boolean>(false);

  useEffect(() => {
    loadLesson(lessonId);
    setPickedOption(null);
    setHasSubmittedCurrent(false);
  }, [lessonId, loadLesson]);

  if (isLoading || !currentLesson) {
    return (
      <AILessonGeneratingCard
        topic={currentLesson?.title || 'Chiziqli tenglamalar'}
        courseTitle={activeCourse?.title || 'Matematika'}
      />
    );
  }

  const currentStep = currentLesson.steps[currentStepIndex];
  const isMath = currentLesson.courseId === 'course_math_01';

  // Infographic 2 Step 8 category tabs mapping
  const stepCategoryLabels = [
    { label: 'Nazariya', icon: BookOpen },
    { label: 'Misol', icon: Lightbulb },
    { label: 'Mashq', icon: FileText },
    { label: 'Test', icon: HelpCircle },
  ];

  const handleSelectQuizOption = (idx: number) => {
    if (isEvaluatingAnswer || hasSubmittedCurrent) return;
    setPickedOption(idx);
  };

  const handleAnswerSubmit = async () => {
    if (pickedOption === null || isEvaluatingAnswer) return;
    const res = await submitAnswer(pickedOption);
    setHasSubmittedCurrent(true);
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
            className="text-slate-500 hover:text-slate-800"
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

      {/* Step Category Navigation Tabs matching Infographic 2 Step 8 */}
      <div className="flex items-center gap-2 overflow-x-auto pb-1">
        {currentLesson.steps.map((st, idx) => {
          const isActive = currentStepIndex === idx;
          const isPassed = currentStepIndex > idx;
          const catInfo = stepCategoryLabels[idx % stepCategoryLabels.length];
          const IconComp = catInfo.icon;

          return (
            <button
              key={st.id}
              onClick={() => goToStep(idx)}
              className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer border ${
                isActive
                  ? 'bg-blue-600 text-white border-blue-600 shadow-md shadow-blue-500/20'
                  : isPassed
                  ? 'bg-emerald-50 text-emerald-700 border-emerald-200 hover:bg-emerald-100'
                  : 'bg-white text-slate-600 border-slate-200 hover:bg-slate-50 hover:border-slate-300'
              }`}
            >
              <IconComp className={`w-3.5 h-3.5 ${isActive ? 'text-white' : isPassed ? 'text-emerald-600' : 'text-slate-400'}`} />
              <span>{catInfo.label}</span>
              {isPassed && <CheckCircle2 className="w-3 h-3 text-emerald-600 ml-0.5" />}
            </button>
          );
        })}
      </div>

      {/* Step Progress Line */}
      <div className="flex items-center gap-2">
        {currentLesson.steps.map((st, idx) => {
          const isActive = currentStepIndex === idx;
          const isPassed = currentStepIndex > idx;
          return (
            <div
              key={st.id}
              className={`h-1.5 flex-1 rounded-full transition-all duration-300 ${
                isActive
                  ? 'bg-blue-600 shadow-xs'
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

            {/* Step Interactive Question (Quiz) matching Infographic 2 Step 9 */}
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

                {/* Option buttons with A, B, C, D indicators */}
                <div className="space-y-3">
                  {currentStep.interactiveQuestion.options.map((opt, idx) => {
                    const isSelected = pickedOption === idx;
                    const letter = String.fromCharCode(65 + idx); // A, B, C, D

                    return (
                      <button
                        key={idx}
                        type="button"
                        onClick={() => handleSelectQuizOption(idx)}
                        disabled={isEvaluatingAnswer || hasSubmittedCurrent}
                        className={`w-full text-left p-4 rounded-2xl border-2 transition-all flex items-center justify-between cursor-pointer ${
                          isSelected
                            ? 'border-blue-600 bg-blue-50/70 shadow-xs ring-2 ring-blue-500/20'
                            : 'border-slate-200 hover:border-slate-300 hover:bg-slate-50'
                        }`}
                      >
                        <div className="flex items-center gap-3">
                          <span
                            className={`w-7 h-7 rounded-lg flex items-center justify-center font-bold text-xs ${
                              isSelected
                                ? 'bg-blue-600 text-white'
                                : 'bg-slate-100 text-slate-600'
                            }`}
                          >
                            {letter}
                          </span>
                          <span className="font-semibold text-slate-800 text-sm">{opt}</span>
                        </div>
                        {isSelected && <CheckCircle2 className="w-5 h-5 text-blue-600" />}
                      </button>
                    );
                  })}
                </div>

                {/* Real-time Inline AI Explanation Card matching Infographic 2 Step 9 */}
                {lastAnswerResult && (
                  <motion.div
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    className={`p-5 rounded-2xl border-2 space-y-3 ${
                      lastAnswerResult.isCorrect
                        ? 'bg-emerald-50/90 border-emerald-300 text-emerald-950'
                        : 'bg-indigo-50/90 border-indigo-300 text-indigo-950'
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <Sparkles className={`w-4 h-4 ${lastAnswerResult.isCorrect ? 'text-emerald-600' : 'text-indigo-600'}`} />
                        <span className="text-xs font-black uppercase tracking-wider">
                          AI Tushuntirishi
                        </span>
                      </div>
                      <span className={`text-xs font-bold px-2 py-0.5 rounded-full ${
                        lastAnswerResult.isCorrect ? 'bg-emerald-200 text-emerald-900' : 'bg-rose-200 text-rose-900'
                      }`}>
                        {lastAnswerResult.isCorrect ? 'To‘g‘ri javob! +2 XP' : 'Qayta mustahkamlash zarur'}
                      </span>
                    </div>

                    {lastAnswerResult.isCorrect ? (
                      <div className="space-y-1.5 text-xs sm:text-sm">
                        <p className="font-bold text-emerald-800">
                          To‘g‘ri javob tanlandi!
                        </p>
                        <p className="text-slate-700">
                          {lastAnswerResult.explanation || 'Ajoyib! Mavzu bo‘yicha tushunchangiz mustahkamlandi va bilim foizingiz oshirildi.'}
                        </p>
                      </div>
                    ) : (
                      <div className="space-y-1.5 text-xs sm:text-sm">
                        <p className="font-bold text-indigo-950">
                          {lastAnswerResult.explanation || 'Bu yerda formulani qo‘llashda noaniqlik yuz berdi.'}
                        </p>
                        {lastAnswerResult.aiExplanation && (
                          <p className="text-slate-700 italic">
                            💡 {lastAnswerResult.aiExplanation.remediationStep}
                          </p>
                        )}
                      </div>
                    )}
                  </motion.div>
                )}

                {/* Quiz Submission Button */}
                <div className="pt-2 flex justify-end">
                  {!hasSubmittedCurrent ? (
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
                  ) : (
                    <div className="flex items-center gap-3">
                      {!lastAnswerResult?.isCorrect && (
                        <Button
                          variant="outline"
                          size="md"
                          onClick={() => {
                            setPickedOption(null);
                            setHasSubmittedCurrent(false);
                          }}
                          leftIcon={<RotateCcw className="w-4 h-4" />}
                        >
                          Qayta urinish
                        </Button>
                      )}
                      <Button
                        variant="primary"
                        size="md"
                        onClick={nextStep}
                        rightIcon={<ArrowRight className="w-4 h-4" />}
                      >
                        Davom etish
                      </Button>
                    </div>
                  )}
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

      {/* Lesson Completion Modal matching Infographic 2 Step 10 & 11 */}
      <LessonCompletionModal
        isOpen={isCompleted}
        scorePercentage={100}
        correctCount={1}
        totalCount={1}
        courseTitle={activeCourse?.title || 'Matematika'}
        lessonTitle={currentLesson.title}
        onProceedToNext={() => {
          useLessonStore.getState().resetLessonState();
          onFinish();
        }}
      />
    </div>
  );
};
