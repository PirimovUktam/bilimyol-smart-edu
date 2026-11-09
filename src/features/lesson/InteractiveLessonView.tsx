import { useTranslation } from '@/core/locales/useTranslation';
import React, { useEffect, useRef, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import confetti from 'canvas-confetti';
import {
  BookOpen,
  ArrowRight,
  ArrowLeft,
  CheckCircle2,
  XCircle,
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
import { foundationLessons } from '@/domain/personalization/learningStart';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useAuth } from '@/core/context/AuthContext';
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
import { Formula, LearningText } from '@/presentation/components/LearningText';
import { PageHeader } from '@/presentation/components/PageHeader';
import { Progress } from '@/presentation/components/Progress';
import { Modal } from '@/presentation/components/Modal';
import { TutorConversation } from '@/features/ai-tutor/YolchiAIChatView';
import { clearLessonPosition, readLessonPosition, saveLessonPosition } from './readingPosition';
import { DictionaryLookup } from '@/features/dictionary/DictionaryLookup';

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
  const { t } = useTranslation();
  const { activeCourse, activeCourseSkills } = useCourseStore();
  const { profile } = useLearnerStore();
  const { profile: account, isDemoMode } = useAuth();
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
    clearAnswerResult,
    openAIPanel,
    openReinforcement,
    closeReinforcement,
    closeAIPanel,
  } = useLessonStore();

  const [pickedOption, setPickedOption] = useState<number | null>(null);
  const [hasSubmittedCurrent, setHasSubmittedCurrent] = useState<boolean>(false);
  const [help, setHelp] = useState<'tutor' | 'dictionary' | null>(null);
  const restored = useRef<typeof currentLesson>(null);

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

  useEffect(() => {
    if (!account || !currentLesson || currentLesson.id !== lessonId || currentLesson.courseId !== activeCourse?.id) return;
    if (restored.current !== currentLesson) {
      restored.current = currentLesson;
      const position = readLessonPosition(account.id, currentLesson);
      if (position !== currentStepIndex) {
        goToStep(position);
        return;
      }
    }
    if (isCompleted) clearLessonPosition(account.id, currentLesson);
    else saveLessonPosition(account.id, currentLesson, currentStepIndex);
  }, [account, currentLesson, lessonId, activeCourse?.id, currentStepIndex, isCompleted, goToStep]);

  if (isLoading) {
    return (
      <AILessonGeneratingCard
        topic={currentLesson?.title || activeCourse?.title || t('lesson.analysis')}
        courseTitle={activeCourse?.title || t('admin.subject')}
        onCancel={onBackToRoadmap}
        onRetry={() => loadLesson(lessonId)}
      />
    );
  }

  if (!currentLesson) {
    return (
      <AILessonGeneratingCard
        error={error || t('lesson.missing')}
        topic={activeCourse?.title || 'Dars'}
        courseTitle={activeCourse?.title || t('admin.subject')}
        onCancel={onBackToRoadmap}
        onRetry={() => loadLesson(lessonId)}
      />
    );
  }

  // Cross-course isolation: refuse to render a lesson from a different course.
  if (!activeCourse || isLessonCourseMismatch(currentLesson, activeCourse)) {
    return (
      <div className="max-w-md mx-auto px-4 py-16 text-center">
        <Card className="p-8 border-amber-200 bg-amber-50/50 shadow-lg">
          <div className="w-14 h-14 rounded-2xl bg-amber-100 text-amber-600 flex items-center justify-center mx-auto mb-4">
            <BookOpen className="w-8 h-8" />
          </div>
          <h2 className="text-xl font-bold text-ink mb-2">{t('lesson.wrongCourse')}</h2>
          <p className="text-sm text-slatefine mb-6">{t('lesson.wrongCourseDescription')}</p>
          <Button variant="primary" onClick={onBackToRoadmap}>{t('lesson.backRoadmap')}</Button>
        </Card>
      </div>
    );
  }

  const currentStep = currentLesson.steps[currentStepIndex];
  const isFoundation = foundationLessons(activeCourse).includes(currentLesson.id);
  const isFinalStep = currentStepIndex === currentLesson.steps.length - 1;

  // Answer reveal: after submission we always show which option was correct and
  // (on a mistake) which option the learner picked, so feedback is never blind.
  const revealedCorrectOption = lastAnswerResult?.correctOption || '';
  const revealAnswers = hasSubmittedCurrent && Boolean(lastAnswerResult);

  const stepCategoryLabels = {
    concept: { label: 'Nazariya', icon: BookOpen },
    formula: { label: t('lesson.formula'), icon: FileText },
    visual_example: { label: 'Misol', icon: Lightbulb },
    audio_simulation: { label: 'Tinglash', icon: FileText },
    interactive_question: { label: 'Test', icon: HelpCircle },
  };

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
        colors: ['#5546E8', '#2563EB', '#10B981', '#F59E0B'], disableForReducedMotion: true,
      });
    } else {
      sounds.playMistake();
    }
  };

  const savedScore = profile?.scoresByCourse[currentLesson.courseId]?.[currentLesson.skillId]?.score;
  const completedSkill = savedScore == null ? undefined : {
    name: activeCourseSkills.find((skill) => skill.id === currentLesson.skillId)?.name ?? currentLesson.title,
    score: savedScore,
  };

  return (
    <div className="learning-page max-w-240 space-y-5">
      {currentLesson.isAiGenerated && (
        <p className="rounded-xl border border-brand/20 bg-sand p-3 text-sm leading-relaxed text-brand-dark">{t('lesson.aiNotice')}</p>
      )}
      {/* Honest disclosure when the AI edge function failed and a deterministic demo lesson is shown */}
      {currentLesson.isDeterministicFallback && (
        <div className="p-4 bg-amber-50 border border-amber-200 rounded-2xl flex items-start gap-3">
          <AlertTriangle className="w-5 h-5 text-amber-600 shrink-0 mt-0.5" />
          <div className="text-xs sm:text-sm text-amber-900 font-medium leading-relaxed">{t('lesson.demoNotice')}</div>
        </div>
      )}

      {error && (
        <div role="alert" className="p-4 bg-amber-50 border border-amber-200 rounded-2xl text-sm text-amber-900">
          {error}
        </div>
      )}

      <PageHeader title={currentLesson.title} eyebrow={activeCourse.title}
        description={currentLesson.summary === currentStep.content ? undefined : currentLesson.summary}
        action={<Button variant="outline" size="sm" onClick={onBackToRoadmap}
          leftIcon={<ArrowLeft aria-hidden="true" className="size-4" />}>{t('lesson.backPath')}</Button>} />
      <div className="fade-up stagger-1 flex flex-wrap items-center gap-2 rounded-[20px] border border-hairline bg-paper px-4 py-3 shadow-[var(--shadow-editorial)]">
        <span className="mr-auto flex items-center gap-2 text-sm font-bold text-ink">
          <Sparkles aria-hidden="true" className="size-4 text-brand" />{t('lesson.help')}</span>
        <Button size="sm" variant="outline" leftIcon={<Sparkles aria-hidden="true" className="size-4 text-brand" />} onClick={() => setHelp('tutor')}>{t('lesson.ask')}</Button>
        {activeCourse.subject === 'english' && <Button size="sm" variant="ghost" leftIcon={<BookOpen aria-hidden="true" className="size-4" />} onClick={() => setHelp('dictionary')}>{t('lesson.dictionary')}</Button>}
      </div>
      <div className="flex flex-wrap items-center justify-between gap-2 text-sm font-semibold text-slatefine">
        <span className="inline-flex items-center gap-1.5 rounded-full bg-paper border border-hairline px-3 py-1 text-xs font-bold text-ink shadow-2xs">
          <Clock aria-hidden="true" className="size-3.5 text-brand" />{currentLesson.estimatedMinutes}{t('courses.minutes')}</span>
        <span className="highlight">{t('lesson.step')}{' '}{currentStepIndex + 1} / {currentLesson.steps.length}</span>
      </div>

      {/* Step Category Navigation Tabs */}
      {!isFoundation && <nav aria-label={t('lesson.steps')} className="flex flex-wrap items-center gap-2">
        {currentLesson.steps.map((st, idx) => {
          const isActive = currentStepIndex === idx;
          const isPassed = currentStepIndex > idx;
          const catInfo = st.interactiveQuestion ? stepCategoryLabels.interactive_question : (stepCategoryLabels[st.type] ?? stepCategoryLabels.concept);
          const IconComp = catInfo.icon;

          return (
            <button
              key={st.id}
              aria-current={isActive ? 'step' : undefined}
              onClick={() => goToStep(idx)}
              className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer border ${
                isActive
                  ? 'commonBtn border-transparent'
                  : isPassed
                  ? 'bg-mint/10 text-[#059669] border-mint/25 hover:bg-mint/15'
                  : 'bg-paper text-slatefine border-hairline hover:bg-sand/50 hover:border-brand/30'
              }`}
            >
              <IconComp className={`w-3.5 h-3.5 ${isActive ? 'text-white' : isPassed ? 'text-mint' : 'text-brand'}`} />
              <span>{catInfo.label}</span>
              {isPassed && <CheckCircle2 className="w-3.5 h-3.5 text-mint ml-0.5" />}
            </button>
          );
        })}
      </nav>}

      <Progress value={100 * (currentStepIndex + 1) / currentLesson.steps.length} ariaLabel={t('lesson.steps')} size="sm" />

      {/* Step Content Card */}
      <AnimatePresence mode="wait">
        <motion.div
          key={currentStep.id}
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -12 }}
          transition={{ duration: 0.25 }}
        >
          <div className="edtech-card p-5 sm:p-8 space-y-6">
            {/* Step Header */}
            <div className="space-y-1.5">
              <div className="flex items-center gap-2">
                <span className="highlight">{t('lesson.step')}{' '}{currentStep.stepNumber}
                </span>
                {currentStep.subtitle && (
                  <span className="font-mono text-xs text-slatefine font-medium">
                    // {currentStep.subtitle}
                  </span>
                )}
              </div>
              <h2 className="heading text-2xl sm:text-3xl font-extrabold text-ink tracking-tight">{currentStep.title}</h2>
            </div>

            {/* Step Content Description */}
            <div className="text-sm text-slatefine sm:text-base"><LearningText text={currentStep.content} /></div>

            {/* Highlights */}
            {currentStep.highlightNotes && currentStep.highlightNotes.length > 0 && (
              <div className="p-4 bg-canvas border-l-4 border-brand border-y border-r border-hairline rounded-xl space-y-2">
                <span className="font-mono text-[10px] font-bold text-brand-dark uppercase tracking-widest block">{t('lesson.rules')}</span>
                <ul className="space-y-1.5">
                  {currentStep.highlightNotes.map((note, i) => (
                    <li key={i} className="text-xs sm:text-sm text-graphite flex items-start gap-2 font-medium">
                      <CheckCircle2 className="w-4 h-4 text-mint shrink-0 mt-0.5" />
                      <span>{note}</span>
                    </li>
                  ))}
                </ul>
              </div>
            )}

            {/* Step Formula Data (if any) */}
            {currentStep.formulaData && (
              <div className="p-6 bg-navy text-white rounded-xl border border-slate-700/80 space-y-4 shadow-md">
                <div className="text-center space-y-1">
                  <span className="font-mono text-[10px] text-slate-400 uppercase tracking-widest font-bold">{t('lesson.formula')}</span>
                  <div className="text-2xl sm:text-3xl font-mono font-bold text-path py-1">
                    <Formula source={currentStep.formulaData.latex} display />
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
                speakerName={currentStep.visualModelData.speakerName || t('lesson.audio')}
              />
            )}

            {/* Step Interactive Question (Quiz) */}
            {currentStep.interactiveQuestion && (
              <div className="pt-4 border-t border-hairline space-y-5">
                <div className="p-4 bg-canvas border border-hairline rounded-xl space-y-2">
                  <div className="flex items-center gap-2 text-xs font-mono font-bold text-brand-dark uppercase tracking-wider">
                    <Sparkles className="w-4 h-4 text-brand" />
                    <span>{t('lesson.finalQuestion')}</span>
                  </div>
                  <h3 className="font-display text-base sm:text-lg font-bold text-ink">
                    {currentStep.interactiveQuestion.text}
                  </h3>
                  {currentStep.interactiveQuestion.formulaLatex && (
                    <div className="p-2 bg-paper rounded-lg border border-hairline font-mono font-bold text-brand-dark text-sm inline-block">
                      <Formula source={currentStep.interactiveQuestion.formulaLatex} />
                    </div>
                  )}
                </div>

                {/* Option buttons with A, B, C, D indicators and 2x2 grid */}
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  {currentStep.interactiveQuestion.options.map((opt, idx) => {
                    const isSelected = pickedOption === idx;
                    const letter = String.fromCharCode(65 + idx); // A, B, C, D
                    const isCorrectOption = revealAnswers && revealedCorrectOption !== '' && opt === revealedCorrectOption;
                    const isWrongPick = revealAnswers && isSelected && lastAnswerResult?.isCorrect === false;

                    const optionTone = isCorrectOption
                      ? 'border-mint/50 bg-mint/10 ring-2 ring-mint/30'
                      : isWrongPick
                      ? 'border-coral/50 bg-coral/5 ring-2 ring-coral/25'
                      : isSelected
                      ? 'border-navy ring-2 ring-navy bg-paper shadow-sm'
                      : 'border-hairline bg-paper hover:border-slate-400 hover:bg-canvas';

                    return (
                      <button
                        key={idx}
                        type="button"
                        onClick={() => handleSelectQuizOption(idx)}
                        disabled={isEvaluatingAnswer || hasSubmittedCurrent}
                        aria-pressed={isSelected}
                        className={`w-full text-left p-4 rounded-xl border transition-all flex items-center justify-between cursor-pointer ${optionTone}`}
                      >
                        <div className="flex items-center gap-3">
                          <span
                            className={`w-7 h-7 rounded-lg flex items-center justify-center font-mono font-bold text-xs shrink-0 ${
                              isCorrectOption
                                ? 'bg-mint text-white'
                                : isWrongPick
                                ? 'bg-coral text-white'
                                : isSelected
                                ? 'bg-navy text-white shadow-xs'
                                : 'bg-sand text-slate-700 border border-hairline'
                            }`}
                          >
                            {letter}
                          </span>
                          <span className="font-mono font-bold text-ink text-sm">{opt}</span>
                        </div>
                        {isCorrectOption ? (
                          <span className="font-mono text-[10px] font-bold px-2 py-0.5 rounded bg-mint/15 text-[#046b4a] border border-mint/30 shrink-0 uppercase tracking-wider flex items-center gap-1">
                            <CheckCircle2 className="w-3 h-3" />{t('lesson.correctAnswer')}</span>
                        ) : isWrongPick ? (
                          <span className="font-mono text-[10px] font-bold px-2 py-0.5 rounded bg-coral/10 text-[#a51c1c] border border-coral/30 shrink-0 uppercase tracking-wider flex items-center gap-1">
                            <XCircle className="w-3 h-3" />{t('lesson.youSelected')}</span>
                        ) : isSelected ? (
                          <span className="font-mono text-[10px] font-bold px-2 py-0.5 rounded bg-slate-100 text-graphite border border-slate-300 shrink-0 uppercase tracking-wider">{t('lesson.selected')}</span>
                        ) : null}
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
                          {lastAnswerResult.isCorrect ? t('lesson.correct') : t('lesson.review')}
                        </span>
                      </div>
<span className={`text-xs font-bold px-2.5 py-0.5 rounded-full ${
                          lastAnswerResult.isCorrect ? 'bg-mint/25 text-mint' : 'bg-coral/25 text-coral'
                        }`}>
                          {lastAnswerResult.isCorrect
                            ? `+${lastAnswerResult.xpAwarded ?? 2} XP`
                            : t('lesson.reinforceRecommended')}
                        </span>
                    </div>

                    {lastAnswerResult.isCorrect ? (
                      <div className="space-y-2 text-xs sm:text-sm">
                        <p className="font-bold text-mint">{t('lesson.correctSelected')}</p>
                        <div className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-mint/15 border border-mint/30 font-mono text-[11px] font-bold text-[#046b4a]">
                          <CheckCircle2 className="w-3.5 h-3.5" />{t('lesson.answer')}{' '}{lastAnswerResult.selectedOption || lastAnswerResult.correctOption}
                        </div>
                        <p className="text-slate-700">
                          {lastAnswerResult.explanation || t('lesson.understood')}
                        </p>
                      </div>
                    ) : (
                      <div className="space-y-3 text-xs sm:text-sm">
                        {/* Explicit answer reveal: what was chosen vs what is correct */}
                        <div className="flex flex-col sm:flex-row sm:items-center gap-2">
                          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-coral/10 border border-coral/30 font-mono text-[11px] font-bold text-[#a51c1c]">
                            <XCircle className="w-3.5 h-3.5" />{t('lesson.selectedAnswer')}{' '}{lastAnswerResult.selectedOption || '—'}
                          </span>
                          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-mint/15 border border-mint/30 font-mono text-[11px] font-bold text-[#046b4a]">
                            <CheckCircle2 className="w-3.5 h-3.5" />{t('lesson.rightAnswer')}{' '}{lastAnswerResult.correctOption || '—'}
                          </span>
                        </div>

                        <p className="font-medium text-graphite">
                          {lastAnswerResult.explanation ||
                            (lastAnswerResult.correctOption
                              ? `Nima uchun xato? To‘g‘ri javob — "${lastAnswerResult.correctOption}". Yechimni qadam-baqadam tekshirib ko‘ring.`
                              : t('lesson.incorrect'))}
                        </p>

                        <div className="flex flex-col sm:flex-row gap-2 mt-1">
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={openAIPanel}
                            leftIcon={<Sparkles className="w-4 h-4 text-brand" />}
                            className="font-bold"
                          >{t('lesson.aiAnalysis')}</Button>
                          <Button
                            variant="coral"
                            size="sm"
                            onClick={openReinforcement}
                            rightIcon={<ArrowRight className="w-4 h-4" />}
                            className="font-bold"
                          >{t('tutor.reinforce')}</Button>
                        </div>
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
                    >{t('lesson.check')}</Button>
                  ) : (
                    <div className="flex items-center gap-3 w-full sm:w-auto">
                      {!lastAnswerResult?.isCorrect && (
                        <Button
                          variant="outline"
                          size="md"
                          onClick={() => {
                            clearAnswerResult();
                            setPickedOption(null);
                            setHasSubmittedCurrent(false);
                          }}
                          leftIcon={<RotateCcw className="w-4 h-4" />}
                          className="flex-1 sm:flex-none"
                        >{t('courses.retry')}</Button>
                      )}
                      <Button
                        variant="gradient"
                        size="md"
                        onClick={nextStep}
                        rightIcon={<ArrowRight className="w-4 h-4" />}
                        className="flex-1 sm:flex-none font-black"
                      >{t('lesson.nextQuestion')}</Button>
                    </div>
                  )}
                </div>
              </div>
            )}

            {/* Navigation Buttons for Standard Content Steps */}
            {!currentStep.interactiveQuestion && (
              <div className="pt-6 border-t border-hairline flex flex-wrap items-center justify-between gap-2">
                <Button
                  variant="ghost"
                  size="md"
                  onClick={prevStep}
                  disabled={currentStepIndex === 0}
                  leftIcon={<ArrowLeft className="w-4 h-4" />}
                >{t('lesson.previous')}</Button>

                <Button
                  variant="primary"
                  size="md"
                  onClick={nextStep}
                  disabled={isCompletingLesson || isEvaluatingAnswer || isCompleted}
                  isLoading={isCompletingLesson}
                  aria-busy={isCompletingLesson}
                  rightIcon={<ArrowRight className="w-5 h-5" />}
                >
                  {isCompletingLesson ? 'Saqlanmoqda…' : isFinalStep ? (error ? t('courses.retry') : t('lesson.complete')) : t('lesson.nextStep')}
                </Button>
              </div>
            )}
          </div>
        </motion.div>
      </AnimatePresence>

      {help && <Modal isOpen onClose={() => setHelp(null)} title={help === 'tutor' ? t('lesson.lessonChat') : t('lesson.englishDictionary')}>
        {help === 'tutor' ? <TutorConversation compact
          conversation={[account?.id, currentLesson.courseId, currentLesson.id].join('/')}
          courseId={currentLesson.courseId} courseTitle={activeCourse.title} skillId={currentLesson.skillId}
          topic={currentLesson.title} score={savedScore} isDemoMode={isDemoMode} /> : <DictionaryLookup />}
      </Modal>}

      {/* Yo'lchi AI Feedback Panel */}
        {showAIPanel && lastAnswerResult && currentStep.interactiveQuestion && <YolchiAIPanel
          question={currentStep.interactiveQuestion}
          answer={lastAnswerResult}
        onProceedToReinforcement={openReinforcement}
        onClose={closeAIPanel}
        />}

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

      <LessonCompletionModal
        isOpen={isCompleted}
        correctCount={correctAnswerCount}
        totalCount={currentLesson.steps.filter((step) => Boolean(step.interactiveQuestion)).length}
        lessonTitle={currentLesson.title}
        skill={completedSkill}
        onProceedToNext={() => {
          useLessonStore.getState().resetLessonState();
          onFinish();
        }}
      />
    </div>
  );
};
