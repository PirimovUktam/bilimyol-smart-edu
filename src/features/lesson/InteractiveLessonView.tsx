import React, { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import confetti from 'canvas-confetti';
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
  RotateCcw,
  AlertTriangle,
} from 'lucide-react';
import { useLessonStore } from '@/app/store/useLessonStore';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { isLessonCourseMismatch } from '@/app/router/lessonResolution';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';
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
  const { activeCourse, activeCourseSkills } = useCourseStore();
  const { profile } = useLearnerStore();
  const {
    currentLesson,
    currentStepIndex,
    isLoading,
    error,
    isEvaluatingAnswer,
    isCompletingLesson,
    lastAnswerResult,
    showAIPanel,
    showReinforcementModal,
    isCompleted,
    correctAnswerCount,
    loadLesson,
    clearSession,
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
    // Leaving the lesson invalidates pending completion/profile work as well
    // as answer evaluation, even when no other lesson is opened next.
    return () => clearSession();
  }, [lessonId, loadLesson, clearSession]);

  useEffect(() => {
    // Each step owns its answer controls; a previous step must not disable or
    // carry its selection into the next question.
    setPickedOption(null);
    setHasSubmittedCurrent(false);
  }, [currentStepIndex]);

  if (isLoading) {
    return (
      <AILessonGeneratingCard
        topic={currentLesson?.title || activeCourse?.title || 'Mavzu tahlili'}
        courseTitle={activeCourse?.title || 'Fan'}
        onCancel={onBackToRoadmap}
        onRetry={() => loadLesson(lessonId)}
      />
    );
  }

  if (!currentLesson) {
    return (
      <AILessonGeneratingCard
        error={error || 'Ushbu dars topilmadi yoki yuklashda xatolik yuz berdi.'}
        topic={activeCourse?.title || 'Dars'}
        courseTitle={activeCourse?.title || 'Fan'}
        onCancel={onBackToRoadmap}
        onRetry={() => loadLesson(lessonId)}
      />
    );
  }

  // Cross-course isolation: refuse to render a lesson from a different course.
  if (isLessonCourseMismatch(currentLesson, activeCourse)) {
    return (
      <div className="max-w-md mx-auto px-4 py-16 text-center">
        <Card className="p-8 border-amber-200 bg-amber-50/50 shadow-lg">
          <div className="w-14 h-14 rounded-2xl bg-amber-100 text-amber-600 flex items-center justify-center mx-auto mb-4">
            <BookOpen className="w-8 h-8" />
          </div>
          <h2 className="text-xl font-bold text-slate-900 mb-2">Dars noto‘g‘ri fanda</h2>
          <p className="text-sm text-slate-600 mb-6">
            Ushbu dars boshqa fanga tegishli. Iltimos, yo‘nalishingizni tanlab, qayta urinib ko‘ring.
          </p>
          <Button variant="primary" onClick={onBackToRoadmap}>
            Yo‘l xaritasiga qaytish
          </Button>
        </Card>
      </div>
    );
  }

  const currentStep = currentLesson.steps[currentStepIndex];
  const isFinalStep = currentStepIndex === currentLesson.steps.length - 1;

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
    const activeSession = useLessonStore.getState();
    if (!res || activeSession.currentLesson !== currentLesson || activeSession.currentStepIndex !== currentStepIndex) return;
    setHasSubmittedCurrent(true);
    if (res?.isCorrect) {
      sounds.playSuccess();
      // Micro-win: celebrate every correct answer instantly.
      confetti({
        particleCount: 70,
        spread: 70,
        origin: { y: 0.7 },
        colors: ['#4F46E5', '#06B6D4', '#10B981', '#F59E0B'],
      });
    } else {
      sounds.playMistake();
    }
  };

  return (
    <div className="max-w-4xl mx-auto px-4 py-8 space-y-6">
      {/* Honest disclosure when the AI edge function failed and a deterministic demo lesson is shown */}
      {currentLesson.isDeterministicFallback && (
        <div className="p-4 bg-amber-50 border border-amber-200 rounded-2xl flex items-start gap-3">
          <AlertTriangle className="w-5 h-5 text-amber-600 shrink-0 mt-0.5" />
          <div className="text-xs sm:text-sm text-amber-900 font-medium leading-relaxed">
            AI xizmati hozircha javob bera olmayapti — namunaviy (demo) dars ko‘rsatilmoqda.
            Mavzular haqiqiy AI bilan yaratilganda avtomatik ravishda yangilanadi.
          </div>
        </div>
      )}

      {error && (
        <div role="alert" className="p-4 bg-amber-50 border border-amber-200 rounded-2xl text-sm text-amber-900">
          {error}
        </div>
      )}

      {/* Top Breadcrumb & Progress */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-[#e4ddce]">
        <div className="flex items-center gap-3">
          <Button
            variant="ghost"
            size="sm"
            onClick={onBackToRoadmap}
            leftIcon={<ArrowLeft className="w-4 h-4" />}
            className="text-slate-600 hover:text-slate-950 font-bold"
          >
            Yo‘l xaritasiga qaytish
          </Button>
          <div className="h-4 w-px bg-[#e4ddce]" />
          <span className="font-mono text-xs font-bold text-slate-800 bg-white border border-[#e4ddce] px-2.5 py-1 rounded-lg flex items-center gap-1.5 shadow-2xs">
            <BookOpen className="w-3.5 h-3.5 text-brand" />
            {currentLesson.title}
          </span>
        </div>

        <div className="flex items-center gap-2 font-mono text-xs text-slate-500 font-medium">
          <Clock className="w-3.5 h-3.5 text-slate-400" />
          <span>{currentLesson.estimatedMinutes} daqiqa</span>
          <span>•</span>
          <span>
            Qadam {currentStepIndex + 1} / {currentLesson.steps.length}
          </span>
        </div>
      </div>

      {/* Step Category Navigation Tabs */}
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
                  ? 'bg-[#10151f] text-white border-[#10151f] shadow-xs'
                  : isPassed
                  ? 'bg-mint/10 text-mint border-mint/25 hover:bg-mint/10'
                  : 'bg-white text-slate-600 border-[#e4ddce] hover:bg-[#fbf9f4] hover:border-slate-400'
              }`}
            >
              <IconComp className={`w-3.5 h-3.5 ${isActive ? 'text-path' : isPassed ? 'text-mint' : 'text-slate-400'}`} />
              <span>{catInfo.label}</span>
              {isPassed && <CheckCircle2 className="w-3 h-3 text-mint ml-0.5" />}
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
                  ? 'bg-[#10151f]'
                  : isPassed
                  ? 'bg-mint'
                  : 'bg-[#ece5d8]'
              }`}
            />
          );
        })}
      </div>

      {/* Step Content Card */}
      <AnimatePresence mode="wait">
        <motion.div
          key={currentStep.id}
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -12 }}
          transition={{ duration: 0.2 }}
        >
          <div className="p-7 sm:p-9 bg-white border border-[#e4ddce] rounded-2xl shadow-sm space-y-6">
            {/* Step Header */}
            <div className="space-y-1">
              <div className="flex items-center gap-2">
                <span className="editorial-kicker">
                  Qadam {currentStep.stepNumber}
                </span>
                {currentStep.subtitle && (
                  <span className="font-mono text-xs text-slate-500 font-medium">
                    // {currentStep.subtitle}
                  </span>
                )}
              </div>
              <h2 className="font-display text-2xl sm:text-3xl font-bold text-slate-900 tracking-tight">{currentStep.title}</h2>
            </div>

            {/* Step Content Description */}
            <p className="text-sm sm:text-base text-slate-700 leading-relaxed whitespace-pre-line font-medium">
              {currentStep.content}
            </p>

            {/* Highlights */}
            {currentStep.highlightNotes && currentStep.highlightNotes.length > 0 && (
              <div className="p-4 bg-[#fbf9f4] border-l-4 border-brand border-y border-r border-[#e4ddce] rounded-xl space-y-2">
                <span className="font-mono text-[10px] font-bold text-brand-dark uppercase tracking-widest block">
                  Asosiy Qoidalar:
                </span>
                <ul className="space-y-1.5">
                  {currentStep.highlightNotes.map((note, i) => (
                    <li key={i} className="text-xs sm:text-sm text-slate-800 flex items-start gap-2 font-medium">
                      <CheckCircle2 className="w-4 h-4 text-mint shrink-0 mt-0.5" />
                      <span>{note}</span>
                    </li>
                  ))}
                </ul>
              </div>
            )}

            {/* Step Formula Data (if any) */}
            {currentStep.formulaData && (
              <div className="p-6 bg-[#10151f] text-white rounded-xl border border-slate-700/80 space-y-4 shadow-md">
                <div className="text-center space-y-1">
                  <span className="font-mono text-[10px] text-slate-400 uppercase tracking-widest font-bold">Chiziqli Funksiya Ko‘rinishi:</span>
                  <div className="text-2xl sm:text-3xl font-mono font-bold text-path py-1">
                    {currentStep.formulaData.latex}
                  </div>
                  <p className="text-xs text-slate-300">{currentStep.formulaData.description}</p>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-3 border-t border-slate-800">
                  {currentStep.formulaData.variables.map((v, i) => (
                    <div key={i} className="p-3 bg-slate-800/80 rounded-lg border border-slate-700/80">
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
              <div className="pt-4 border-t border-[#e4ddce] space-y-5">
                <div className="p-4 bg-[#fbf9f4] border border-[#e4ddce] rounded-xl space-y-2">
                  <div className="flex items-center gap-2 text-xs font-mono font-bold text-brand-dark uppercase tracking-wider">
                    <Sparkles className="w-4 h-4 text-brand" />
                    <span>Darsni Yakunlovchi Sinov Savoli</span>
                  </div>
                  <h3 className="font-display text-base sm:text-lg font-bold text-slate-900">
                    {currentStep.interactiveQuestion.text}
                  </h3>
                  {currentStep.interactiveQuestion.formulaLatex && (
                    <div className="p-2 bg-white rounded-lg border border-[#e4ddce] font-mono font-bold text-brand-dark text-sm inline-block">
                      {currentStep.interactiveQuestion.formulaLatex}
                    </div>
                  )}
                </div>

                {/* Option buttons with A, B, C, D indicators and 2x2 grid */}
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  {currentStep.interactiveQuestion.options.map((opt, idx) => {
                    const isSelected = pickedOption === idx;
                    const letter = String.fromCharCode(65 + idx); // A, B, C, D

                    return (
                      <button
                        key={idx}
                        type="button"
                        onClick={() => handleSelectQuizOption(idx)}
                        disabled={isEvaluatingAnswer || hasSubmittedCurrent}
                        className={`w-full text-left p-4 rounded-xl border transition-all flex items-center justify-between cursor-pointer ${
                          isSelected
                            ? 'border-[#10151f] ring-2 ring-[#10151f] bg-white shadow-sm'
                            : 'border-[#e4ddce] bg-white hover:border-slate-400 hover:bg-[#fbf9f4]'
                        }`}
                      >
                        <div className="flex items-center gap-3">
                          <span
                            className={`w-7 h-7 rounded-lg flex items-center justify-center font-mono font-bold text-xs shrink-0 ${
                              isSelected
                                ? 'bg-[#10151f] text-white shadow-xs'
                                : 'bg-[#f5efe4] text-slate-700 border border-[#e4ddce]'
                            }`}
                          >
                            {letter}
                          </span>
                          <span className="font-mono font-bold text-slate-900 text-sm">{opt}</span>
                        </div>
                        {isSelected && (
                          <span className="font-mono text-[10px] font-bold px-2 py-0.5 rounded bg-slate-100 text-slate-800 border border-slate-300 shrink-0 uppercase tracking-wider">
                            tanlangan ✓
                          </span>
                        )}
                      </button>
                    );
                  })}
                </div>

                {/* Real-time Inline AI Explanation Card matching Reference 4 */}
                {lastAnswerResult && (
                  <motion.div
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    className={`p-5 rounded-3xl border-2 space-y-3 ${
                      lastAnswerResult.isCorrect
                        ? 'bg-emerald-50/90 border-mint/30 text-mint'
                        : 'bg-gradient-to-r from-coral/5 via-amber-50 to-orange-50 border-coral/30 text-coral shadow-sm'
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <Sparkles className={`w-4 h-4 ${lastAnswerResult.isCorrect ? 'text-mint' : 'text-coral'}`} />
                        <span className="text-xs font-black uppercase tracking-wider">
                          {lastAnswerResult.isCorrect ? 'To‘g‘ri javob!' : 'Xato tahlili: Yo‘lchi AI'}
                        </span>
                      </div>
<span className={`text-xs font-bold px-2.5 py-0.5 rounded-full ${
                          lastAnswerResult.isCorrect ? 'bg-mint/25 text-mint' : 'bg-coral/25 text-coral'
                        }`}>
                          {lastAnswerResult.isCorrect
                            ? `+${lastAnswerResult.xpAwarded ?? 2} XP`
                            : 'Mustahkamlash tavsiya etiladi'}
                        </span>
                    </div>

                    {lastAnswerResult.isCorrect ? (
                      <div className="space-y-1.5 text-xs sm:text-sm">
                        <p className="font-bold text-mint">
                          To‘g‘ri javob tanlandi!
                        </p>
                        <p className="text-slate-700">
                          {lastAnswerResult.explanation || 'Ajoyib! Mavzu bo‘yicha tushunchangiz mustahkamlandi va bilim foizingiz oshirildi.'}
                        </p>
                      </div>
                    ) : (
                      <div className="space-y-2 text-xs sm:text-sm">
                        <p className="font-bold text-coral">
                          {lastAnswerResult.explanation || 'Hisoblashda hadlarni birlashtirishda xatolik yuz berdi.'}
                        </p>
                        {lastAnswerResult.aiExplanation && (
                          <div className="p-3 bg-white/90 rounded-2xl border border-coral/25 text-slate-800 space-y-1">
                            <span className="text-[11px] font-black uppercase text-brand-dark block">
                              Yo‘lchi AI maslahati:
                            </span>
                            <p className="font-medium">
                              {lastAnswerResult.aiExplanation.remediationStep}
                            </p>
                          </div>
                        )}
                        <Button
                          variant="coral"
                          size="sm"
                          onClick={openReinforcement}
                          rightIcon={<ArrowRight className="w-4 h-4" />}
                          className="mt-2 font-bold"
                        >
                          Mavzuni mustahkamlash mashqi
                        </Button>
                      </div>
                    )}
                  </motion.div>
                )}

                {/* Quiz Submission Button (Reference 4 style TEKSHIRISH) */}
                <div className="pt-2 flex justify-end">
                  {!hasSubmittedCurrent ? (
                    <Button
                      variant="gradient"
                      size="lg"
                      disabled={pickedOption === null || isEvaluatingAnswer}
                      isLoading={isEvaluatingAnswer}
                      onClick={handleAnswerSubmit}
                      rightIcon={<ArrowRight className="w-5 h-5" />}
                      className="w-full sm:w-auto font-black px-8 py-3.5 tracking-wider shadow-lg shadow-indigo-600/30"
                    >
                      TEKSHIRISH
                    </Button>
                  ) : (
                    <div className="flex items-center gap-3 w-full sm:w-auto">
                      {!lastAnswerResult?.isCorrect && (
                        <Button
                          variant="outline"
                          size="md"
                          onClick={() => {
                            setPickedOption(null);
                            setHasSubmittedCurrent(false);
                          }}
                          leftIcon={<RotateCcw className="w-4 h-4" />}
                          className="flex-1 sm:flex-none"
                        >
                          Qayta urinish
                        </Button>
                      )}
                      <Button
                        variant="gradient"
                        size="md"
                        onClick={nextStep}
                        rightIcon={<ArrowRight className="w-4 h-4" />}
                        className="flex-1 sm:flex-none font-black"
                      >
                        Keyingi savol
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
                  disabled={isCompletingLesson || isEvaluatingAnswer || isCompleted}
                  isLoading={isCompletingLesson}
                  aria-busy={isCompletingLesson}
                  rightIcon={<ArrowRight className="w-5 h-5" />}
                >
                  {isCompletingLesson ? 'Saqlanmoqda…' : isFinalStep ? (error ? 'Qayta urinish' : 'Darsni yakunlash') : 'Keyingi qadam'}
                </Button>
              </div>
            )}
          </div>
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
      {(() => {
        const courseScores = (profile?.scoresByCourse && currentLesson?.courseId)
          ? (profile.scoresByCourse[currentLesson.courseId] || {})
          : {};
        const currentSkillId = currentLesson?.skillId || '';
        const prevScore = courseScores[currentSkillId]?.score ?? 50;
        const newSkillScore = lastAnswerResult?.newSkillScore ?? (lastAnswerResult?.isCorrect ? Math.min(100, prevScore + 15) : prevScore);
        const realDelta = Math.max(0, newSkillScore - prevScore);

        const dynamicSkillProgressList = activeCourseSkills.length > 0
          ? activeCourseSkills.slice(0, 5).map((sk) => {
              if (sk.id === currentSkillId) {
                return {
                  skillName: sk.name,
                  score: newSkillScore,
                  delta: realDelta > 0 ? realDelta : (lastAnswerResult?.isCorrect ? 15 : undefined),
                };
              }
              return {
                skillName: sk.name,
                score: courseScores[sk.id]?.score ?? 50,
                delta: undefined,
              };
            })
          : [
              {
                skillName: currentLesson.title,
                score: newSkillScore,
                delta: realDelta > 0 ? realDelta : (lastAnswerResult?.isCorrect ? 15 : undefined),
              },
            ];

        const currentSkillName = activeCourseSkills.find((s) => s.id === currentSkillId)?.name || currentLesson.title;
        const dynamicRecommendation = realDelta > 0
          ? `Siz ${currentSkillName} mavzusini muvaffaqiyatli o‘zlashtirdingiz (+${realDelta}% o‘sish). Ushbu bilimni keyingi modul bilan mustahkamlashni tavsiya qilamiz.`
          : `Siz ${currentSkillName} mavzusi bo‘yicha tushunchalarni mustahkamlab oldingiz. Yangi mashqlarga o‘tishga tayyorsiz.`;

        return (
          <LessonCompletionModal
            isOpen={isCompleted}
            scorePercentage={Math.round((correctAnswerCount / Math.max(currentLesson.steps.filter((step) => Boolean(step.interactiveQuestion)).length, 1)) * 100)}
            correctCount={correctAnswerCount}
            totalCount={Math.max(currentLesson.steps.filter((step) => Boolean(step.interactiveQuestion)).length, 1)}
            courseTitle={activeCourse?.title || 'Fan'}
            lessonTitle={currentLesson.title}
            skillProgressList={dynamicSkillProgressList}
            aiRecommendation={dynamicRecommendation}
            onProceedToNext={() => {
              useLessonStore.getState().resetLessonState();
              onFinish();
            }}
          />
        );
      })()}
    </div>
  );
};
