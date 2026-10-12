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
  RotateCcw,
  AlertTriangle,
  Zap,
} from 'lucide-react';
import { useLessonStore } from '@/app/store/useLessonStore';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { isLessonCourseMismatch } from '@/app/router/lessonResolution';
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
  const { activeCourse, activeCourseSkills } = useCourseStore();
  const { profile } = useLearnerStore();
  const {
    currentLesson,
    currentStepIndex,
    isLoading,
    error,
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

  if (error || !currentLesson) {
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
        <Card className="p-8 border-amber-500/40 bg-slate-900/90 shadow-2xl backdrop-blur-xl">
          <div className="w-14 h-14 rounded-2xl bg-amber-950 text-amber-400 flex items-center justify-center mx-auto mb-4 border border-amber-500/40">
            <BookOpen className="w-8 h-8" />
          </div>
          <h2 className="text-xl font-bold text-white mb-2">Dars noto‘g‘ri fanda</h2>
          <p className="text-sm text-slate-300 mb-6">
            Ushbu dars boshqa fanga tegishli. Iltimos, yo‘nalishingizni tanlab, qayta urinib ko‘ring.
          </p>
          <Button variant="gradient" onClick={onBackToRoadmap}>
            Yo‘l xaritasiga qaytish
          </Button>
        </Card>
      </div>
    );
  }

  const currentStep = currentLesson.steps[currentStepIndex];
  const isMath = currentLesson.courseId === 'course_math_01';

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
    <div className="max-w-4xl mx-auto px-4 py-8 space-y-6 relative">
      {/* Honest disclosure if fallback */}
      {currentLesson.isDeterministicFallback && (
        <div className="p-4 bg-amber-950/80 border border-amber-500/40 rounded-2xl flex items-start gap-3 backdrop-blur-xl">
          <AlertTriangle className="w-5 h-5 text-amber-400 shrink-0 mt-0.5" />
          <div className="text-xs sm:text-sm text-amber-200 font-medium leading-relaxed">
            AI xizmati hozircha javob bera olmayapti — namunaviy (demo) dars ko‘rsatilmoqda.
            Mavzular haqiqiy AI bilan yaratilganda avtomatik ravishda yangilanadi.
          </div>
        </div>
      )}

      {/* Top Breadcrumb & Progress */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-white/10">
        <div className="flex items-center gap-3">
          <Button
            variant="ghost"
            size="sm"
            onClick={onBackToRoadmap}
            leftIcon={<ArrowLeft className="w-4 h-4" />}
            className="text-slate-400 hover:text-white hover:bg-white/5"
          >
            Yo‘l xaritasiga qaytish
          </Button>
          <div className="h-4 w-px bg-white/10" />
          <Badge variant={isMath ? 'cyan' : 'teal'} size="sm">
            <BookOpen className="w-3.5 h-3.5 mr-1" />
            {currentLesson.title}
          </Badge>
        </div>

        <div className="flex items-center gap-3 text-xs text-slate-400 font-medium">
          <span className="flex items-center gap-1 text-cyan-300 font-bold">
            <Zap className="w-3.5 h-3.5 text-cyan-400" />
            +15 XP Savol
          </span>
          <span>•</span>
          <span className="flex items-center gap-1">
            <Clock className="w-3.5 h-3.5" />
            {currentLesson.estimatedMinutes} daqiqa
          </span>
          <span>•</span>
          <span className="text-slate-300 font-bold">
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
              className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer border backdrop-blur-xl ${
                isActive
                  ? 'bg-gradient-to-r from-cyan-500 to-indigo-600 text-white border-cyan-400 shadow-[0_0_15px_rgba(6,182,212,0.3)] font-black'
                  : isPassed
                  ? 'bg-emerald-950/80 text-emerald-300 border-emerald-500/40 hover:bg-emerald-900/60'
                  : 'bg-slate-900/80 text-slate-400 border-white/10 hover:text-white hover:bg-slate-800'
              }`}
            >
              <IconComp className={`w-3.5 h-3.5 ${isActive ? 'text-white' : isPassed ? 'text-emerald-400' : 'text-slate-400'}`} />
              <span>{catInfo.label}</span>
              {isPassed && <CheckCircle2 className="w-3 h-3 text-emerald-400 ml-0.5" />}
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
                  ? 'bg-cyan-400 shadow-[0_0_10px_rgba(6,182,212,0.8)]'
                  : isPassed
                  ? 'bg-emerald-400 shadow-[0_0_6px_rgba(16,185,129,0.5)]'
                  : 'bg-slate-800'
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
          <Card className="p-7 sm:p-9 shadow-2xl border-white/10 bg-slate-900/90 backdrop-blur-2xl space-y-6">
            {/* Step Header */}
            <div className="space-y-1">
              <div className="flex items-center gap-2">
                <span className="text-xs font-black text-cyan-400 uppercase tracking-wider">
                  Qadam {currentStep.stepNumber}
                </span>
                {currentStep.subtitle && (
                  <span className="text-xs font-semibold text-slate-400">
                    • {currentStep.subtitle}
                  </span>
                )}
              </div>
              <h2 className="text-2xl sm:text-3xl font-black text-white">{currentStep.title}</h2>
            </div>

            {/* Step Content Description */}
            <p className="text-sm sm:text-base text-slate-200 leading-relaxed whitespace-pre-line font-medium">
              {currentStep.content}
            </p>

            {/* Highlights */}
            {currentStep.highlightNotes && currentStep.highlightNotes.length > 0 && (
              <div className="p-4 bg-cyan-950/60 border border-cyan-500/30 rounded-2xl space-y-2 backdrop-blur-md">
                <span className="text-xs font-bold text-cyan-300 uppercase tracking-wider block">
                  Asosiy Qoidalar:
                </span>
                <ul className="space-y-1.5">
                  {currentStep.highlightNotes.map((note, i) => (
                    <li key={i} className="text-xs sm:text-sm text-slate-200 flex items-start gap-2">
                      <CheckCircle2 className="w-4 h-4 text-cyan-400 shrink-0 mt-0.5" />
                      <span>{note}</span>
                    </li>
                  ))}
                </ul>
              </div>
            )}

            {/* Step Formula Data (if any) */}
            {currentStep.formulaData && (
              <div className="p-6 bg-slate-950 border border-white/10 text-white rounded-2xl space-y-4 shadow-inner">
                <div className="text-center space-y-1">
                  <span className="text-xs text-slate-400 font-medium">Chiziqli Funksiya Ko‘rinishi:</span>
                  <div className="text-2xl sm:text-3xl font-mono font-bold text-cyan-400 py-1">
                    {currentStep.formulaData.latex}
                  </div>
                  <p className="text-xs text-slate-300">{currentStep.formulaData.description}</p>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-3 border-t border-slate-800">
                  {currentStep.formulaData.variables.map((v, i) => (
                    <div key={i} className="p-3 bg-slate-900/80 rounded-xl border border-white/5">
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
              <div className="pt-4 border-t border-white/10 space-y-5">
                <div className="p-5 bg-indigo-950/60 border border-indigo-500/40 rounded-2xl space-y-2 backdrop-blur-md">
                  <div className="flex items-center gap-2 text-xs font-bold text-cyan-300 uppercase tracking-wider">
                    <Sparkles className="w-4 h-4 text-cyan-400" />
                    <span>Darsni Yakunlovchi Sinov Savoli</span>
                  </div>
                  <h3 className="text-base sm:text-lg font-black text-white">
                    {currentStep.interactiveQuestion.text}
                  </h3>
                  {currentStep.interactiveQuestion.formulaLatex && (
                    <div className="p-2.5 bg-slate-900 rounded-xl border border-cyan-500/40 font-mono font-bold text-cyan-300 text-sm inline-block shadow-md">
                      {currentStep.interactiveQuestion.formulaLatex}
                    </div>
                  )}
                </div>

                {/* Option buttons with A, B, C, D indicators */}
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
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
                            ? 'border-cyan-400 bg-cyan-950/80 shadow-[0_0_20px_rgba(6,182,212,0.3)] ring-2 ring-cyan-400/30'
                            : 'border-white/10 bg-slate-900/80 hover:border-cyan-500/40 hover:bg-slate-800'
                        }`}
                      >
                        <div className="flex items-center gap-3">
                          <span
                            className={`w-8 h-8 rounded-xl flex items-center justify-center font-black text-xs shrink-0 ${
                              isSelected
                                ? 'bg-cyan-500 text-slate-950 shadow-md'
                                : 'bg-slate-800 text-slate-300'
                            }`}
                          >
                            {letter}
                          </span>
                          <span className="font-bold text-white text-sm font-mono">{opt}</span>
                        </div>
                        {isSelected && (
                          <span className="text-[11px] font-black px-2 py-0.5 rounded-full bg-cyan-900/80 text-cyan-300 border border-cyan-500/40 shrink-0">
                            tanlangan ✓
                          </span>
                        )}
                      </button>
                    );
                  })}
                </div>

                {/* Real-time Inline AI Explanation Card */}
                {lastAnswerResult && (
                  <motion.div
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    className={`p-5 rounded-3xl border-2 space-y-3 backdrop-blur-2xl ${
                      lastAnswerResult.isCorrect
                        ? 'bg-emerald-950/90 border-emerald-500/50 text-white shadow-[0_0_25px_rgba(16,185,129,0.25)]'
                        : 'bg-slate-900/95 border-amber-500/50 text-white shadow-[0_0_25px_rgba(245,158,11,0.25)]'
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <Sparkles className={`w-4 h-4 ${lastAnswerResult.isCorrect ? 'text-emerald-400' : 'text-amber-400'}`} />
                        <span className="text-xs font-black uppercase tracking-wider">
                          {lastAnswerResult.isCorrect ? 'To‘g‘ri javob! 🎉' : 'Yo‘lchi AI Pedagogik Tahlili'}
                        </span>
                      </div>
                      <span className={`text-xs font-bold px-2.5 py-0.5 rounded-full ${
                        lastAnswerResult.isCorrect ? 'bg-emerald-900/80 text-emerald-300 border border-emerald-500/40' : 'bg-amber-900/80 text-amber-300 border border-amber-500/40'
                      }`}>
                        {lastAnswerResult.isCorrect ? '+15 XP' : 'Mustahkamlash tavsiya etiladi'}
                      </span>
                    </div>

                    {lastAnswerResult.isCorrect ? (
                      <div className="space-y-1.5 text-xs sm:text-sm">
                        <p className="font-bold text-emerald-300">
                          Ajoyib natija! To‘g‘ri javob tanlandi.
                        </p>
                        <p className="text-slate-300">
                          {lastAnswerResult.explanation || 'Mavzu bo‘yicha tushunchangiz mustahkamlandi va bilim foizingiz oshirildi.'}
                        </p>
                      </div>
                    ) : (
                      <div className="space-y-2 text-xs sm:text-sm">
                        <p className="font-bold text-amber-300">
                          {lastAnswerResult.explanation || 'Hisoblashda qoidaga e’tibor bering.'}
                        </p>
                        {lastAnswerResult.aiExplanation && (
                          <div className="p-3.5 bg-slate-950/80 rounded-2xl border border-white/10 text-slate-200 space-y-1">
                            <span className="text-[11px] font-black uppercase text-cyan-400 block">
                              Yo‘lchi AI tushuntirishi:
                            </span>
                            <p className="font-medium leading-relaxed">
                              {lastAnswerResult.aiExplanation.remediationStep}
                            </p>
                          </div>
                        )}
                        <Button
                          variant="coral"
                          size="sm"
                          onClick={openReinforcement}
                          rightIcon={<ArrowRight className="w-4 h-4" />}
                          className="mt-2 font-black shadow-lg"
                        >
                          Mavzuni mustahkamlash mashqi
                        </Button>
                      </div>
                    )}
                  </motion.div>
                )}

                {/* Quiz Submission Button */}
                <div className="pt-2 flex justify-end">
                  {!hasSubmittedCurrent ? (
                    <Button
                      variant="gradient"
                      size="lg"
                      disabled={pickedOption === null || isEvaluatingAnswer}
                      isLoading={isEvaluatingAnswer}
                      onClick={handleAnswerSubmit}
                      rightIcon={<ArrowRight className="w-5 h-5" />}
                      className="w-full sm:w-auto font-black px-8 py-3.5 tracking-wider shadow-[0_0_25px_rgba(99,102,241,0.4)]"
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
                          className="flex-1 sm:flex-none bg-slate-800 text-slate-200 border-white/10 hover:bg-slate-700"
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
              <div className="pt-6 border-t border-white/10 flex items-center justify-between">
                <Button
                  variant="ghost"
                  size="md"
                  onClick={prevStep}
                  disabled={currentStepIndex === 0}
                  leftIcon={<ArrowLeft className="w-4 h-4" />}
                  className="text-slate-400 hover:text-white hover:bg-white/5"
                >
                  Oldingi
                </Button>

                <Button
                  variant="gradient"
                  size="md"
                  onClick={nextStep}
                  rightIcon={<ArrowRight className="w-5 h-5" />}
                  className="font-black"
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

      {/* Lesson Completion Modal */}
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
            scorePercentage={lastAnswerResult?.isCorrect ? 100 : (lastAnswerResult?.overallScore || 80)}
            correctCount={lastAnswerResult?.isCorrect ? 1 : 0}
            totalCount={1}
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
