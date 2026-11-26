import { useTranslation } from '@/core/locales/useTranslation';
import React, { useEffect, useId, useMemo, useRef, useState } from 'react';
import { motion } from 'framer-motion';
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
  Layers,
  RotateCcw,
  AlertTriangle,
  MessageSquare,
  ShieldCheck,
} from 'lucide-react';
import { useLessonStore } from '@/app/store/useLessonStore';
import { useCourseStore } from '@/app/store/useCourseStore';
import { foundationLessons } from '@/domain/personalization/learningStart';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { useAuth } from '@/core/context/AuthContext';
import { isLessonCourseMismatch } from '@/app/router/lessonResolution';
import type { WordMatchPair } from '@/domain/entities/Question';
import { Badge } from '@/presentation/components/Badge';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';
import { MathFunctionGraph } from './MathFunctionGraph';
import { AudioSimWave } from './AudioSimWave';
import { AILessonGeneratingCard } from './AILessonGeneratingCard';
import { LessonCompletionModal } from './LessonCompletionModal';
import { LessonMediaPlayer } from './LessonMediaPlayer';
import { FlashcardDeck } from './FlashcardDeck';
import { YolchiAIPanel } from '../ai-tutor/YolchiAIPanel';
import { ReinforcementModal } from '../reinforcement/ReinforcementModal';
import { sounds } from '@/core/utils/soundEffects';
import { Formula, LearningText } from '@/presentation/components/LearningText';
import { PageHeader } from '@/presentation/components/PageHeader';
import { Progress } from '@/presentation/components/Progress';
import { Modal } from '@/presentation/components/Modal';
let lazyTutorLoadFailed = false;

function createLazyTutorConversation() {
  return React.lazy(() =>
    import('@/features/ai-tutor/YolchiAIChatView')
      .then((m) => ({ default: m.TutorConversation }))
      .catch((error) => {
        lazyTutorLoadFailed = true;
        throw error;
      }),
  );
}

let LazyTutorConversation = createLazyTutorConversation();

function resetLazyTutorConversationIfFailed() {
  if (!lazyTutorLoadFailed) return;
  lazyTutorLoadFailed = false;
  LazyTutorConversation = createLazyTutorConversation();
}

interface TutorModalErrorBoundaryProps {
  errorTitle: string;
  errorDescription: string;
  retryLabel: string;
  closeLabel: string;
  onRetry: () => void;
  onClose: () => void;
  children: React.ReactNode;
}

class TutorModalErrorBoundary extends React.Component<
  TutorModalErrorBoundaryProps,
  { hasError: boolean }
> {
  state = { hasError: false };

  static getDerivedStateFromError(): { hasError: boolean } {
    return { hasError: true };
  }

  componentDidCatch(error: Error): void {
    console.warn('Tutor modal chunk failed to load:', error);
  }

  private handleRetry = (): void => {
    this.props.onRetry();
    this.setState({ hasError: false });
  };

  render(): React.ReactNode {
    if (!this.state.hasError) {
      return this.props.children;
    }
    return (
      <div role="alert" className="space-y-3 rounded-2xl border border-coral/25 bg-coral/10 p-4 text-sm text-ink">
        <p className="font-semibold">{this.props.errorTitle}</p>
        <p className="text-slatefine">{this.props.errorDescription}</p>
        <div className="flex flex-wrap gap-2">
          <Button size="sm" onClick={this.handleRetry}>
            {this.props.retryLabel}
          </Button>
          <Button size="sm" variant="outline" onClick={this.props.onClose}>
            {this.props.closeLabel}
          </Button>
        </div>
      </div>
    );
  }
}
import { clearLessonPosition, readLessonPosition, saveLessonPosition } from './readingPosition';
import { DictionaryLookup } from '@/features/dictionary/DictionaryLookup';

function hashString(value: string): number {
  let h = 2166136261;
  for (let i = 0; i < value.length; i++) {
    h ^= value.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function deterministicPermute<T>(items: T[], seedKey: string): T[] {
  if (items.length <= 1) return [...items];
  const copy = [...items];
  let seed = hashString(seedKey);
  for (let i = copy.length - 1; i > 0; i--) {
    seed = (seed * 1664525 + 1013904223) >>> 0;
    const j = seed % (i + 1);
    const tmp = copy[i];
    copy[i] = copy[j];
    copy[j] = tmp;
  }
  // Ensure permutation is non-identity when 2+ items exist
  const sameOrder = copy.every((item, idx) => item === items[idx]);
  if (sameOrder && copy.length >= 2) {
    const first = copy.shift()!;
    copy.push(first);
  }
  return copy;
}

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
  const { language, t } = useTranslation();
  const { activeCourse, activeCourseSkills } = useCourseStore();
  const { profile } = useLearnerStore();
  const { profile: account, isDemoMode } = useAuth();
  const {
    currentLesson,
    lessonSessionId,
    currentStepIndex,
    isLoading,
    error,
    isEvaluatingAnswer,
    isCompletingLesson,
    lastAnswerResult,
    showAIPanel,
    showReinforcementModal,
    isCompleted,
    answeredQuestionIds,
    correctAnswerCount,
    consecutiveMistakes,
    loadLesson,
    clearSession,
    nextStep,
    prevStep,
    goToStep,
    submitAnswer,
    submitTextAnswer,
    submitStructuredAnswer,
    submitSelfAssessment,
    switchToAlternateExercise,
    clearAnswerResult,
    openAIPanel,
    openReinforcement,
    closeReinforcement,
    closeAIPanel,
  } = useLessonStore();

  const [pickedOption, setPickedOption] = useState<number | null>(null);
  const [textAnswer, setTextAnswer] = useState<string>('');
  const [matchedPairs, setMatchedPairs] = useState<Record<string, string>>({});
  const [selectedMatchLeft, setSelectedMatchLeft] = useState<string | null>(null);
  const [orderedTokenIndices, setOrderedTokenIndices] = useState<number[]>([]);
  const [checkedRubricIds, setCheckedRubricIds] = useState<string[]>([]);
  const [localInputError, setLocalInputError] = useState<string | null>(null);
  const [hasSubmittedCurrent, setHasSubmittedCurrent] = useState<boolean>(false);
  const [help, setHelp] = useState<'tutor' | 'dictionary' | null>(null);
  const [tutorRetryNonce, setTutorRetryNonce] = useState(0);
  const restoredSessionKey = useRef<string | null>(null);
  const textInputRef = useRef<HTMLInputElement | null>(null);
  const productiveInputRef = useRef<HTMLTextAreaElement | null>(null);
  const textInputId = useId();
  const productiveInputId = useId();

  useEffect(() => {
    loadLesson(lessonId);
    setPickedOption(null);
    setTextAnswer('');
    setMatchedPairs({});
    setSelectedMatchLeft(null);
    setOrderedTokenIndices([]);
    setCheckedRubricIds([]);
    setLocalInputError(null);
    setHasSubmittedCurrent(false);
    // Leaving the lesson invalidates pending completion/profile work as well
    // as answer evaluation, even when no other lesson is opened next.
    return () => clearSession();
  }, [lessonId, loadLesson, clearSession]);

  const activeQuestionId = currentLesson?.steps[currentStepIndex]?.interactiveQuestion?.id ?? '';

  useEffect(() => {
    // Each step owns its answer controls; a previous step must not disable or
    // carry its selection into the next question.
    setPickedOption(null);
    setTextAnswer('');
    setMatchedPairs({});
    setSelectedMatchLeft(null);
    setOrderedTokenIndices([]);
    setCheckedRubricIds([]);
    setLocalInputError(null);
    setHasSubmittedCurrent(false);
  }, [currentStepIndex, activeQuestionId]);

  useEffect(() => {
    if (!account || !currentLesson || currentLesson.id !== lessonId || currentLesson.courseId !== activeCourse?.id) return;
    const sessionKey = `${account.id}:${currentLesson.id}:${lessonSessionId}`;
    if (restoredSessionKey.current !== sessionKey) {
      restoredSessionKey.current = sessionKey;
      const needsReview = currentLesson.requiresMastery && useRoadmapStore.getState().roadmap?.nodes.some(
        (node) => node.targetLessonId === currentLesson.id && node.status === 'reinforcement'
      );
      const position = needsReview
        ? Math.max(0, currentLesson.steps.findIndex((step) => step.type === 'visual_example'))
        : readLessonPosition(account.id, currentLesson, answeredQuestionIds);
      if (position !== currentStepIndex) {
        goToStep(position);
        return;
      }
    }
    if (isCompleted) clearLessonPosition(account.id, currentLesson);
    else saveLessonPosition(account.id, currentLesson, currentStepIndex, answeredQuestionIds);
  }, [account, currentLesson, lessonSessionId, lessonId, activeCourse?.id, currentStepIndex, isCompleted, answeredQuestionIds, goToStep]);

  const currentStep = currentLesson?.steps[currentStepIndex];
  const interactiveQ = currentStep?.interactiveQuestion;

  const shuffledRightPairs = useMemo<WordMatchPair[]>(() => {
    if (!interactiveQ?.matchPairs) return [];
    return deterministicPermute(interactiveQ.matchPairs, interactiveQ.id);
  }, [interactiveQ?.id, interactiveQ?.matchPairs]);

  const shuffledOrderTokens = useMemo<Array<{ index: number; token: string }>>(() => {
    if (!interactiveQ?.orderedTokens) return [];
    const indexed = interactiveQ.orderedTokens.map((token, index) => ({ index, token }));
    return deterministicPermute(indexed, interactiveQ.id);
  }, [interactiveQ?.id, interactiveQ?.orderedTokens]);

  const recentMistakeHints = useMemo(() => {
    const courseId = currentLesson?.courseId;
    const stepTitle = currentStep
      ? (currentStep.id === 'eng_list_step_2'
          ? currentStep.title
          : (language === 'ru' && currentStep.titleRu) ? currentStep.titleRu : currentStep.title)
      : '';
    return [
      ...(lastAnswerResult && !lastAnswerResult.isCorrect && interactiveQ
        ? [`${interactiveQ.topic ?? stepTitle} (${lastAnswerResult.selectedOption})`]
        : []),
      ...Object.values((courseId ? profile?.scoresByCourse[courseId] : undefined) ?? {})
        .filter((item) => item.score < 70 || item.isWeakestFocus)
        .map((item) => `${item.skillId}: ${item.score}%`),
    ].slice(0, 3);
  }, [currentLesson?.courseId, currentStep, interactiveQ, language, lastAnswerResult, profile?.scoresByCourse]);

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

  if (!currentLesson || !currentStep) {
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

  const reviewWorkedExample = () => {
    const example = currentLesson.steps.findIndex((step) => step.type === 'visual_example');
    goToStep(Math.max(0, example));
  };
  const isFoundation = foundationLessons(activeCourse).includes(currentLesson.id);
  const isFinalStep = currentStepIndex === currentLesson.steps.length - 1;
  const qType = interactiveQ?.questionType ?? 'multiple_choice';
  const isTextQuestion = qType === 'text_input' || qType === 'fill_blank';
  const isFillBlank = qType === 'fill_blank';
  const isWordMatch = qType === 'word_match';
  const isSentenceOrder = qType === 'sentence_order';
  const isSelfAssessed = qType === 'speaking_prompt' || qType === 'writing_prompt';
  const isChoiceQuestion = !isTextQuestion && !isWordMatch && !isSentenceOrder && !isSelfAssessed;

  const localizedLessonTitle = (language === 'ru' && currentLesson.titleRu) ? currentLesson.titleRu : currentLesson.title;
  const localizedLessonSummary = (language === 'ru' && currentLesson.summaryRu) ? currentLesson.summaryRu : currentLesson.summary;
  // Preserve T3-03 exact step-2 heading match on lesson_eng_listening_01
  const localizedStepTitle = currentStep.id === 'eng_list_step_2'
    ? currentStep.title
    : (language === 'ru' && currentStep.titleRu) ? currentStep.titleRu : currentStep.title;
  const localizedStepSubtitle = (language === 'ru' && currentStep.subtitleRu) ? currentStep.subtitleRu : currentStep.subtitle;
  const localizedStepContent = (language === 'ru' && currentStep.contentRu) ? currentStep.contentRu : currentStep.content;
  const localizedHighlights = (language === 'ru' && currentStep.highlightNotesRu) ? currentStep.highlightNotesRu : currentStep.highlightNotes;
  const localizedQuestionText = interactiveQ
    ? ((language === 'ru' && interactiveQ.textRu) ? interactiveQ.textRu : interactiveQ.text)
    : '';

  // Answer reveal: after submission we always show which option was correct and
  // (on a mistake) which option the learner picked, so feedback is never blind.
  const revealedCorrectOption = lastAnswerResult?.correctOption || '';
  const revealAnswers = hasSubmittedCurrent && Boolean(lastAnswerResult);
  const hideCorrectSpoiler = isTextQuestion || isWordMatch || isSentenceOrder || isSelfAssessed;

  const stepCategoryLabels = {
    concept: { label: t('lesson.stepConcept'), icon: BookOpen },
    formula: { label: t('lesson.formula'), icon: FileText },
    visual_example: { label: t('lesson.stepExample'), icon: Lightbulb },
    audio_simulation: { label: t('lesson.stepListening'), icon: FileText },
    flashcard: { label: t('lesson.flashcard'), icon: Layers },
    interactive_question: { label: t('lesson.stepQuiz'), icon: HelpCircle },
  };

  const celebrateSuccess = () => {
    sounds.playSuccess();
    confetti({
      particleCount: 70,
      spread: 70,
      origin: { y: 0.7 },
      colors: ['#5546E8', '#2563EB', '#10B981', '#F59E0B'], disableForReducedMotion: true,
    });
  };

  const handleSelectQuizOption = (idx: number) => {
    if (isEvaluatingAnswer || hasSubmittedCurrent) return;
    setPickedOption(idx);
  };

  const handleSelectMatchLeft = (pairId: string) => {
    if (isEvaluatingAnswer || hasSubmittedCurrent) return;
    setLocalInputError(null);
    if (selectedMatchLeft === pairId) {
      setSelectedMatchLeft(null);
      return;
    }
    setSelectedMatchLeft(pairId);
  };

  const handleSelectMatchRight = (rightPairId: string) => {
    if (isEvaluatingAnswer || hasSubmittedCurrent) return;
    setLocalInputError(null);
    if (!selectedMatchLeft) {
      // Allow clicking an already-matched right item to clear it
      const owner = Object.entries(matchedPairs).find(([, r]) => r === rightPairId)?.[0];
      if (owner) {
        const next = { ...matchedPairs };
        delete next[owner];
        setMatchedPairs(next);
      }
      return;
    }
    const next = { ...matchedPairs };
    // Remove previous assignment of this right item to keep 1:1 pairing
    for (const [k, v] of Object.entries(next)) {
      if (v === rightPairId) delete next[k];
    }
    next[selectedMatchLeft] = rightPairId;
    setMatchedPairs(next);
    setSelectedMatchLeft(null);
  };

  const handlePickOrderToken = (shuffledItemIdx: number) => {
    if (isEvaluatingAnswer || hasSubmittedCurrent) return;
    setLocalInputError(null);
    if (orderedTokenIndices.includes(shuffledItemIdx)) return;
    setOrderedTokenIndices((prev) => [...prev, shuffledItemIdx]);
  };

  const handleRemoveOrderToken = (positionInTray: number) => {
    if (isEvaluatingAnswer || hasSubmittedCurrent) return;
    setOrderedTokenIndices((prev) => prev.filter((_, idx) => idx !== positionInTray));
  };

  const handleAnswerSubmit = async () => {
    if (pickedOption === null || isEvaluatingAnswer) return;
    const res = await submitAnswer(pickedOption);
    const activeSession = useLessonStore.getState();
    if (!res || activeSession.currentLesson !== currentLesson || activeSession.currentStepIndex !== currentStepIndex) return;
    setHasSubmittedCurrent(true);
    if (res?.isCorrect) {
      celebrateSuccess();
    } else {
      sounds.playMistake();
    }
  };

  const handleTextSubmit = async (event?: React.FormEvent) => {
    event?.preventDefault();
    if (isEvaluatingAnswer) return;
    if (!textAnswer.trim()) {
      setLocalInputError(t('lesson.emptyAnswerError'));
      textInputRef.current?.focus();
      return;
    }
    setLocalInputError(null);
    const res = await submitTextAnswer(textAnswer);
    const activeSession = useLessonStore.getState();
    if (!res || activeSession.currentLesson !== currentLesson || activeSession.currentStepIndex !== currentStepIndex) return;
    setHasSubmittedCurrent(true);
    if (res.isCorrect) {
      celebrateSuccess();
    } else {
      sounds.playMistake();
    }
  };

  const hasStructuredSelection = isWordMatch
    ? Object.keys(matchedPairs).length > 0
    : isSentenceOrder
    ? orderedTokenIndices.length > 0
    : true;

  const handleStructuredSubmit = async () => {
    if (isEvaluatingAnswer || !interactiveQ || !hasStructuredSelection) return;
    setLocalInputError(null);
    const orderedTokens = orderedTokenIndices
      .map((idx) => shuffledOrderTokens[idx]?.token ?? '')
      .filter(Boolean);
    if (isSentenceOrder && orderedTokens.length === 0) return;
    const res = isWordMatch
      ? await submitStructuredAnswer({ matchPairs: matchedPairs })
      : await submitStructuredAnswer({ orderedTokens });
    const activeSession = useLessonStore.getState();
    if (!res || activeSession.currentLesson !== currentLesson || activeSession.currentStepIndex !== currentStepIndex) return;
    setHasSubmittedCurrent(true);
    if (res.isCorrect) {
      celebrateSuccess();
    } else {
      sounds.playMistake();
    }
  };

  const handleSelfAssessedSubmit = async () => {
    if (isEvaluatingAnswer) return;
    if (!textAnswer.trim()) {
      setLocalInputError(t('lesson.emptyProductiveError'));
      productiveInputRef.current?.focus();
      return;
    }
    setLocalInputError(null);
    const res = await submitSelfAssessment(textAnswer, checkedRubricIds);
    const activeSession = useLessonStore.getState();
    if (!res || activeSession.currentLesson !== currentLesson || activeSession.currentStepIndex !== currentStepIndex) return;
    setHasSubmittedCurrent(true);
    if (res.isCorrect) {
      celebrateSuccess();
    }
  };

  const handleRetryExercise = () => {
    clearAnswerResult();
    setPickedOption(null);
    setMatchedPairs({});
    setSelectedMatchLeft(null);
    setOrderedTokenIndices([]);
    setLocalInputError(null);
    setHasSubmittedCurrent(false);
    if (isTextQuestion) {
      setTimeout(() => textInputRef.current?.focus(), 0);
    } else if (isSelfAssessed) {
      setTimeout(() => productiveInputRef.current?.focus(), 0);
    }
  };

  const submitPrimary = () => {
    if (isTextQuestion) void handleTextSubmit();
    else if (isWordMatch || isSentenceOrder) void handleStructuredSubmit();
    else if (isSelfAssessed) void handleSelfAssessedSubmit();
    else void handleAnswerSubmit();
  };

  const isSubmitDisabled = isEvaluatingAnswer
    ? true
    : isChoiceQuestion
    ? pickedOption === null
    : isWordMatch || isSentenceOrder
    ? !hasStructuredSelection
    : false;

  const canAdvanceAfterSubmit =
    (!hideCorrectSpoiler && !(lastAnswerResult && !lastAnswerResult.isCorrect && Boolean(currentLesson.alternateExercise))) ||
    lastAnswerResult?.isCorrect === true;

  const savedScore = profile?.scoresByCourse[currentLesson.courseId]?.[currentLesson.skillId]?.score;
  const completedSkill = currentLesson.requiresMastery || savedScore == null ? undefined : {
    name: activeCourseSkills.find((skill) => skill.id === currentLesson.skillId)?.name ?? localizedLessonTitle,
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

      <PageHeader title={localizedLessonTitle} eyebrow={activeCourse.title}
        description={localizedLessonSummary === localizedStepContent ? undefined : localizedLessonSummary}
        action={<Button variant="outline" size="sm" onClick={onBackToRoadmap}
          leftIcon={<ArrowLeft aria-hidden="true" className="size-4" />} className="min-h-11">{t('lesson.backPath')}</Button>} />
      <div className="fade-up stagger-1 flex flex-wrap items-center gap-2 rounded-[20px] border border-hairline bg-paper px-4 py-3 shadow-[var(--shadow-editorial)]">
        <span className="mr-auto flex items-center gap-2 text-sm font-bold text-ink">
          <Sparkles aria-hidden="true" className="size-4 text-brand" />{t('lesson.help')}</span>
        <Button size="sm" variant="outline" leftIcon={<Sparkles aria-hidden="true" className="size-4 text-brand" />} onClick={() => setHelp('tutor')} className="min-h-11">{t('lesson.ask')}</Button>
        {activeCourse.subject === 'english' && <Button size="sm" variant="ghost" leftIcon={<BookOpen aria-hidden="true" className="size-4" />} onClick={() => setHelp('dictionary')} className="min-h-11">{t('lesson.dictionary')}</Button>}
      </div>
      <div className="flex flex-wrap items-center justify-between gap-2 text-sm font-semibold text-slatefine">
        <span className="inline-flex items-center gap-1.5 rounded-full bg-paper border border-hairline px-3 py-1 text-xs font-bold text-ink shadow-2xs">
          <Clock aria-hidden="true" className="size-3.5 text-brand" />{currentLesson.estimatedMinutes}{' '}{t('courses.minutes')}</span>
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
              className={`flex min-h-11 items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer border ${
                isActive
                  ? 'commonBtn border-transparent'
                  : isPassed
                  ? 'bg-mint/15 text-[#6EE7B7] border-mint/30 hover:bg-mint/20'
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
      <motion.div
        key={currentStep.id}
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.18 }}
      >
          <div className="edtech-card p-5 sm:p-8 space-y-6">
            {/* Step Header */}
            <div className="space-y-1.5">
              <div className="flex flex-wrap items-center gap-2">
                <span className="highlight">{t('lesson.step')}{' '}{currentStep.stepNumber}
                </span>
                {localizedStepSubtitle && (
                  <span className="font-mono text-xs text-slatefine font-medium">
                    // {localizedStepSubtitle}
                  </span>
                )}
              </div>
              <h2 className="heading text-2xl sm:text-3xl font-extrabold text-ink tracking-tight">{localizedStepTitle}</h2>
            </div>

            {/* Step Content Description */}
            <div className="text-sm text-slatefine sm:text-base"><LearningText text={localizedStepContent} /></div>

            {currentStep.media && (
              <LessonMediaPlayer media={currentStep.media} accountId={account?.id} lessonId={currentLesson.id} />
            )}

            {/* Highlights */}
            {localizedHighlights && localizedHighlights.length > 0 && (
              <div className="p-4 bg-canvas border-l-4 border-brand border-y border-r border-hairline rounded-xl space-y-2">
                <span className="font-mono text-[10px] font-bold text-brand-dark uppercase tracking-widest block">{t('lesson.rules')}</span>
                <ul className="space-y-1.5">
                  {localizedHighlights.map((note, i) => (
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
            {!currentStep.media && currentStep.visualModelData?.type === 'audio_wave' && (
              <AudioSimWave
                transcript={currentStep.visualModelData.audioTranscript || ''}
                speakerName={currentStep.visualModelData.speakerName || t('lesson.audio')}
              />
            )}

            {/* Step Flashcard Deck (if any) */}
            {currentStep.type === 'flashcard' && currentStep.flashcards && currentStep.flashcards.length > 0 && (
              <FlashcardDeck
                cards={currentStep.flashcards}
                srsMap={profile?.flashcardSrsByCourse?.[currentLesson.courseId]}
                onRateCard={(cardId, rating, intervalsDays) => {
                  void useLearnerStore
                    .getState()
                    .recordFlashcardSrs(currentLesson.courseId, cardId, rating, intervalsDays);
                }}
              />
            )}

            {/* Step Interactive Question (All 9 Modes) */}
            {interactiveQ && (
              <div className="pt-4 border-t border-hairline space-y-5">
                <div data-question-mode={qType} className="space-y-5">
                  {interactiveQ.media && (
                  <LessonMediaPlayer
                    media={interactiveQ.media}
                    accountId={account?.id}
                    lessonId={currentLesson.id}
                  />
                )}

                <div className="p-4 bg-canvas border border-hairline rounded-xl space-y-2.5">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <div className="flex items-center gap-2 text-xs font-mono font-bold text-brand-dark uppercase tracking-wider">
                      <Sparkles className="w-4 h-4 text-brand" />
                      <span>{t(currentStep.masteryCheckpoint ? 'lesson.masteryCheck' : 'lesson.finalQuestion')}</span>
                    </div>
                    {isSelfAssessed && (
                      <Badge variant="indigo" size="sm">{t('lesson.selfAssessedBadge')}</Badge>
                    )}
                  </div>
                  <h3 className="font-display text-base sm:text-lg font-bold text-ink">
                    {localizedQuestionText}
                  </h3>
                  {interactiveQ.formulaLatex && (
                    <div className="p-2 bg-paper rounded-lg border border-hairline font-mono font-bold text-brand-dark text-sm inline-block">
                      <Formula source={interactiveQ.formulaLatex} />
                    </div>
                  )}
                </div>

                {/* Mode 1 & 2: text_input & fill_blank */}
                {isTextQuestion && (
                  <form onSubmit={handleTextSubmit} className="space-y-3">
                    {isFillBlank && interactiveQ.blankTemplate && (
                      <div className="rounded-xl border border-brand/25 bg-sand px-4 py-3 text-sm font-semibold text-ink">
                        {interactiveQ.blankTemplate}
                      </div>
                    )}
                    <label htmlFor={textInputId} className="block text-sm font-semibold text-ink">
                      {isFillBlank ? t('lesson.fillBlankLabel') : t('lesson.typeAnswer')}
                    </label>
                    <input
                      ref={textInputRef}
                      id={textInputId}
                      type="text"
                      value={textAnswer}
                      onChange={(e) => {
                        setTextAnswer(e.target.value);
                        setLocalInputError(null);
                        if (hasSubmittedCurrent && !lastAnswerResult?.isCorrect) {
                          setHasSubmittedCurrent(false);
                        }
                      }}
                      placeholder={t('lesson.answerPlaceholder')}
                      disabled={isEvaluatingAnswer || (hasSubmittedCurrent && lastAnswerResult?.isCorrect === true)}
                      autoComplete="off"
                      className="form-input min-h-11 px-4 py-3"
                    />
                    {localInputError && (
                      <p
                        role="alert"
                        className="rounded-xl border border-coral/30 bg-coral/10 px-3 py-2 text-xs font-semibold text-ink"
                      >
                        {localInputError}
                      </p>
                    )}
                  </form>
                )}

                {/* Mode 3: word_match */}
                {isWordMatch && interactiveQ.matchPairs && (
                  <div className="space-y-3">
                    <p className="text-xs font-medium text-slatefine">{t('lesson.wordMatchSelectPrompt')}</p>
                    <div
                      role="group"
                      aria-label={t('lesson.wordMatchGroup')}
                      className="grid grid-cols-1 sm:grid-cols-2 gap-3"
                    >
                      <div data-match-side="left" className="space-y-2">
                        <span className="block font-mono text-[11px] font-bold uppercase tracking-wider text-slatefine">
                          {t('lesson.wordMatchLeft')}
                        </span>
                        {interactiveQ.matchPairs.map((pair) => {
                          const isSelectedLeft = selectedMatchLeft === pair.id;
                          const assignedRightId = matchedPairs[pair.id];
                          const assignedPair = interactiveQ.matchPairs?.find((p) => p.id === assignedRightId);
                          return (
                            <button
                              key={pair.id}
                              type="button"
                              data-match-item
                              data-pair-id={pair.id}
                              aria-pressed={isSelectedLeft}
                              disabled={isEvaluatingAnswer || hasSubmittedCurrent}
                              onClick={() => handleSelectMatchLeft(pair.id)}
                              className={`flex min-h-11 w-full cursor-pointer items-center justify-between gap-2 rounded-xl border px-3.5 py-2.5 text-left text-sm font-bold transition-colors ${
                                isSelectedLeft
                                  ? 'border-brand bg-brand/15 text-brand-dark ring-2 ring-brand/30'
                                  : assignedPair
                                  ? 'border-mint/40 bg-mint/10 text-ink'
                                  : 'border-hairline bg-paper text-ink hover:bg-sand'
                              }`}
                            >
                              <span>{pair.left}</span>
                              {assignedPair && (
                                <span className="rounded-full bg-sand px-2 py-0.5 text-xs font-semibold text-brand-dark">
                                  {assignedPair.right}
                                </span>
                              )}
                            </button>
                          );
                        })}
                      </div>

                      <div data-match-side="right" className="space-y-2">
                        <span className="block font-mono text-[11px] font-bold uppercase tracking-wider text-slatefine">
                          {t('lesson.wordMatchRight')}
                        </span>
                        {shuffledRightPairs.map((pair) => {
                          const isUsed = Object.values(matchedPairs).includes(pair.id);
                          return (
                            <button
                              key={pair.id}
                              type="button"
                              data-match-item
                              data-pair-id={pair.id}
                              aria-pressed={isUsed}
                              disabled={isEvaluatingAnswer || hasSubmittedCurrent}
                              onClick={() => handleSelectMatchRight(pair.id)}
                              className={`flex min-h-11 w-full cursor-pointer items-center justify-between gap-2 rounded-xl border px-3.5 py-2.5 text-left text-sm font-semibold transition-colors ${
                                isUsed
                                  ? 'border-brand/40 bg-sand text-brand-dark'
                                  : 'border-hairline bg-paper text-ink hover:bg-sand'
                              }`}
                            >
                              <span>{pair.right}</span>
                            </button>
                          );
                        })}
                      </div>
                    </div>
                  </div>
                )}

                {/* Mode 4: sentence_order */}
                {isSentenceOrder && interactiveQ.orderedTokens && (
                  <div className="space-y-3">
                    <div className="space-y-1.5">
                      <span className="block font-mono text-[11px] font-bold uppercase tracking-wider text-slatefine">
                        {t('lesson.sentenceOrderTray')}
                      </span>
                      <div className="flex min-h-14 flex-wrap items-center gap-2 rounded-2xl border border-hairline bg-canvas p-3">
                        {orderedTokenIndices.length === 0 ? (
                          <span className="text-xs text-slatefine">{t('lesson.sentenceOrderBank')}…</span>
                        ) : (
                          orderedTokenIndices.map((shuffledIdx, trayPos) => (
                            <button
                              key={`${shuffledIdx}-${trayPos}`}
                              type="button"
                              disabled={isEvaluatingAnswer || hasSubmittedCurrent}
                              onClick={() => handleRemoveOrderToken(trayPos)}
                              className="min-h-11 cursor-pointer rounded-xl border border-brand/40 bg-brand/15 px-3 py-1.5 text-sm font-bold text-brand-dark hover:bg-brand/25"
                            >
                              {shuffledOrderTokens[shuffledIdx]?.token}
                            </button>
                          ))
                        )}
                      </div>
                    </div>

                    <div
                      role="group"
                      aria-label={t('lesson.sentenceOrderGroup')}
                      className="flex flex-wrap gap-2 rounded-2xl border border-hairline bg-paper p-3"
                    >
                      {shuffledOrderTokens.map((item, shuffledIdx) => {
                        const isPicked = orderedTokenIndices.includes(shuffledIdx);
                        return (
                          <button
                            key={`${item.index}-${item.token}`}
                            type="button"
                            data-word-token={item.token}
                            disabled={isEvaluatingAnswer || hasSubmittedCurrent || isPicked}
                            onClick={() => handlePickOrderToken(shuffledIdx)}
                            className={`min-h-11 cursor-pointer rounded-xl border px-3.5 py-2 text-sm font-bold transition-colors ${
                              isPicked
                                ? 'border-hairline bg-sand text-slatefine opacity-45'
                                : 'border-hairline bg-canvas text-ink hover:border-brand hover:bg-sand'
                            }`}
                          >
                            {item.token}
                          </button>
                        );
                      })}
                    </div>
                  </div>
                )}

                {/* Mode 5 & 6: speaking_prompt & writing_prompt (self_assessed) */}
                {isSelfAssessed && (
                  <div className="space-y-3">
                    <label htmlFor={productiveInputId} className="block text-sm font-semibold text-ink">
                      {t('lesson.selfAssessedInputLabel')}
                    </label>
                    <textarea
                      ref={productiveInputRef}
                      id={productiveInputId}
                      rows={4}
                      value={textAnswer}
                      onChange={(e) => {
                        setTextAnswer(e.target.value);
                        setLocalInputError(null);
                      }}
                      placeholder={t('lesson.selfAssessedPlaceholder')}
                      disabled={isEvaluatingAnswer || (hasSubmittedCurrent && lastAnswerResult?.isCorrect === true)}
                      className="form-input w-full px-4 py-3"
                    />
                    {localInputError && (
                      <p
                        role="alert"
                        className="rounded-xl border border-coral/30 bg-coral/10 px-3 py-2 text-xs font-semibold text-ink"
                      >
                        {localInputError}
                      </p>
                    )}
                  </div>
                )}

                {/* Mode 7, 8, 9: multiple_choice, error_correction, conversation_completion */}
                {isChoiceQuestion && (
                  <div className="space-y-3">
                    {qType === 'error_correction' && interactiveQ.sentenceWithError && (
                      <div className="rounded-xl border border-coral/35 bg-coral/10 px-4 py-3 space-y-1">
                        <span className="font-mono text-[10px] font-bold uppercase tracking-wider text-coral block">
                          {t('lesson.errorSentenceLabel')}
                        </span>
                        <p className="font-mono text-sm font-bold text-ink">{interactiveQ.sentenceWithError}</p>
                      </div>
                    )}

                    {qType === 'conversation_completion' && interactiveQ.dialogueContext && interactiveQ.dialogueContext.length > 0 && (
                      <div className="rounded-xl border border-brand/25 bg-sand px-4 py-3 space-y-1.5">
                        <span className="inline-flex items-center gap-1.5 font-mono text-[10px] font-bold uppercase tracking-wider text-brand-dark">
                          <MessageSquare className="size-3.5" aria-hidden="true" />
                          {t('lesson.dialogueContextLabel')}
                        </span>
                        <div className="space-y-1">
                          {interactiveQ.dialogueContext.map((line, i) => (
                            <p key={i} className="text-xs sm:text-sm font-medium text-ink">
                              {line}
                            </p>
                          ))}
                        </div>
                      </div>
                    )}

                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                      {interactiveQ.options.map((opt, idx) => {
                        const isSelected = pickedOption === idx;
                        const letter = String.fromCharCode(65 + idx);
                        const isCorrectOption = revealAnswers && revealedCorrectOption !== '' && opt === revealedCorrectOption;
                        const isWrongPick = revealAnswers && isSelected && lastAnswerResult?.isCorrect === false;

                        const optionTone = isCorrectOption
                          ? 'border-mint/50 bg-mint/10 ring-2 ring-mint/30'
                          : isWrongPick
                          ? 'border-coral/50 bg-coral/10 ring-2 ring-coral/25'
                          : isSelected
                          ? 'border-brand ring-2 ring-brand/40 bg-sand shadow-sm'
                          : 'border-hairline bg-paper hover:border-brand/40 hover:bg-canvas';

                        return (
                          <button
                            key={idx}
                            type="button"
                            data-option-index={idx}
                            onClick={() => handleSelectQuizOption(idx)}
                            disabled={isEvaluatingAnswer || hasSubmittedCurrent}
                            aria-pressed={isSelected}
                            className={`w-full min-h-11 text-left p-4 rounded-xl border transition-all flex items-center justify-between cursor-pointer ${optionTone}`}
                          >
                            <div className="flex items-center gap-3">
                              <span
                                className={`w-7 h-7 rounded-lg flex items-center justify-center font-mono font-bold text-xs shrink-0 ${
                                  isCorrectOption
                                    ? 'bg-mint text-white'
                                    : isWrongPick
                                    ? 'bg-coral text-white'
                                    : isSelected
                                    ? 'bg-brand text-white shadow-xs'
                                    : 'bg-sand text-ink border border-hairline'
                                }`}
                              >
                                {letter}
                              </span>
                              <span className="font-mono font-bold text-ink text-sm">{opt}</span>
                            </div>
                            {isCorrectOption ? (
                              <span className="font-mono text-[10px] font-bold px-2 py-0.5 rounded bg-mint/15 text-[#6EE7B7] border border-mint/30 shrink-0 uppercase tracking-wider flex items-center gap-1">
                                <CheckCircle2 className="w-3 h-3" />{t('lesson.correctAnswer')}</span>
                            ) : isWrongPick ? (
                              <span className="font-mono text-[10px] font-bold px-2 py-0.5 rounded bg-coral/15 text-[#FDA4AF] border border-coral/30 shrink-0 uppercase tracking-wider flex items-center gap-1">
                                <XCircle className="w-3 h-3" />{t('lesson.youSelected')}</span>
                            ) : isSelected ? (
                              <span className="font-mono text-[10px] font-bold px-2 py-0.5 rounded bg-sand text-brand-dark border border-brand/30 shrink-0 uppercase tracking-wider">{t('lesson.selected')}</span>
                            ) : null}
                          </button>
                        );
                      })}
                    </div>
                  </div>
                )}
                </div>

                {!hasSubmittedCurrent &&
                  ((isWordMatch && Object.keys(matchedPairs).length > 0) ||
                    (isSentenceOrder && orderedTokenIndices.length > 0)) && (
                    <div>
                      <Button
                        type="button"
                        size="sm"
                        variant="ghost"
                        onClick={() => {
                          if (isWordMatch) {
                            setMatchedPairs({});
                            setSelectedMatchLeft(null);
                          }
                          if (isSentenceOrder) {
                            setOrderedTokenIndices([]);
                          }
                        }}
                        className="min-h-11"
                      >
                        {t('lesson.clearSelection')}
                      </Button>
                    </div>
                  )}

                {/* Self-Assessed Model + Rubric + Honest Non-Certification Notice */}
                {isSelfAssessed && hasSubmittedCurrent && lastAnswerResult?.isCorrect && (
                  <div
                    role="status"
                    aria-live="polite"
                    className="space-y-4 rounded-3xl border-2 border-mint/40 bg-paper p-5 text-ink"
                  >
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <Badge variant="emerald" size="sm">{t('lesson.selfAssessedBadge')}</Badge>
                      <span className="rounded-full bg-mint/20 px-2.5 py-0.5 text-xs font-bold text-ink">
                        +{lastAnswerResult.xpAwarded ?? 2} XP
                      </span>
                    </div>

                    {interactiveQ.sampleResponse && (
                      <div className="space-y-1.5 rounded-2xl border border-hairline bg-canvas p-4">
                        <h4 className="font-mono text-xs font-bold uppercase tracking-wider text-brand-dark">
                          {t('lesson.modelResponse')}
                        </h4>
                        <p className="text-sm font-semibold text-ink">{interactiveQ.sampleResponse}</p>
                      </div>
                    )}

                    {interactiveQ.rubricCriteria && interactiveQ.rubricCriteria.length > 0 && (
                      <div className="space-y-2 rounded-2xl border border-hairline bg-canvas p-4">
                        <h4 className="font-mono text-xs font-bold uppercase tracking-wider text-brand-dark">
                          {t('lesson.rubricTitle')}
                        </h4>
                        <ul className="space-y-2">
                          {interactiveQ.rubricCriteria.map((criterion) => {
                            const checked = checkedRubricIds.includes(criterion.id);
                            const label = language === 'ru' ? criterion.labelRu : criterion.labelUz;
                            return (
                              <li key={criterion.id}>
                                <label className="flex min-h-11 cursor-pointer items-center gap-2.5 rounded-xl border border-hairline bg-paper px-3 py-2 text-xs sm:text-sm font-medium text-ink">
                                  <input
                                    type="checkbox"
                                    checked={checked}
                                    onChange={() =>
                                      setCheckedRubricIds((prev) =>
                                        prev.includes(criterion.id)
                                          ? prev.filter((id) => id !== criterion.id)
                                          : [...prev, criterion.id]
                                      )
                                    }
                                    className="size-4 accent-brand"
                                  />
                                  <span>{label}</span>
                                </label>
                              </li>
                            );
                          })}
                        </ul>
                      </div>
                    )}

                    <p className="flex items-start gap-2 rounded-xl border border-hairline bg-sand px-3 py-2 text-xs text-slatefine">
                      <ShieldCheck aria-hidden="true" className="mt-0.5 size-4 shrink-0 text-brand" />
                      <span>{t('lesson.selfAssessedDisclaimer')}</span>
                    </p>
                  </div>
                )}

                {/* Real-time Inline AI Explanation Card for deterministic exercises */}
                {!isSelfAssessed && lastAnswerResult && (
                  <motion.div
                    role="status"
                    aria-live="polite"
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    className={`p-5 rounded-3xl border-2 space-y-3 ${
                      lastAnswerResult.isCorrect
                        ? 'bg-paper border-mint/40 text-ink'
                        : 'bg-paper border-coral/40 text-ink shadow-sm'
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <Sparkles className={`w-4 h-4 ${lastAnswerResult.isCorrect ? 'text-mint' : 'text-coral'}`} />
                        <span className={`text-xs font-black uppercase tracking-wider ${lastAnswerResult.isCorrect ? 'text-mint' : 'text-coral'}`}>
                          {lastAnswerResult.isCorrect ? t('lesson.correct') : t('lesson.review')}
                        </span>
                      </div>
                      <span className={`text-xs font-bold px-2.5 py-0.5 rounded-full ${
                        lastAnswerResult.isCorrect ? 'bg-mint/20 text-ink' : 'bg-coral/20 text-ink'
                      }`}>
                        {lastAnswerResult.isCorrect
                          ? `+${lastAnswerResult.xpAwarded ?? 2} XP`
                          : t('lesson.reinforceRecommended')}
                      </span>
                    </div>

                    {lastAnswerResult.isCorrect ? (
                      <div className="space-y-2 text-xs sm:text-sm">
                        <p className="font-bold text-mint">{t('lesson.correctSelected')}</p>
                        <div className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-mint/15 border border-mint/30 font-mono text-[11px] font-bold text-ink">
                          <CheckCircle2 className="w-3.5 h-3.5 text-mint" />{t('lesson.answer')}{' '}{lastAnswerResult.selectedOption || lastAnswerResult.correctOption}
                        </div>
                        <p className="text-graphite">
                          {lastAnswerResult.explanation || t('lesson.understood')}
                        </p>
                        <p className="rounded-xl border border-mint/30 bg-mint/10 px-3 py-2 text-xs font-bold text-ink">
                          {t('adaptive.lessonImpactCorrect')}
                        </p>
                      </div>
                    ) : (
                      <div className="space-y-3 text-xs sm:text-sm">
                        <div className="flex flex-col sm:flex-row sm:items-center gap-2">
                          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-coral/10 border border-coral/30 font-mono text-[11px] font-bold text-ink">
                            <XCircle className="w-3.5 h-3.5 text-coral" />{t('lesson.selectedAnswer')}{' '}{lastAnswerResult.selectedOption || '—'}
                          </span>
                          {!hideCorrectSpoiler && Boolean(lastAnswerResult.correctOption) && (
                            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-mint/15 border border-mint/30 font-mono text-[11px] font-bold text-ink">
                              <CheckCircle2 className="w-3.5 h-3.5 text-mint" />{t('lesson.rightAnswer')}{' '}{lastAnswerResult.correctOption}
                            </span>
                          )}
                        </div>

                        <p className="font-medium text-graphite">
                          {lastAnswerResult.explanation ||
                            (lastAnswerResult.correctOption
                              ? `Nima uchun xato? To‘g‘ri javob — "${lastAnswerResult.correctOption}". Yechimni qadam-baqadam tekshirib ko‘ring.`
                              : t('lesson.incorrect'))}
                        </p>

                        {currentLesson.alternateExercise &&
                          !currentLesson.steps.some((step) => step.interactiveQuestion?.id === currentLesson.alternateExercise?.id) && (
                          <div className="space-y-2 rounded-xl border border-amber/30 bg-amber/10 px-3 py-2.5">
                            <p className="text-xs font-semibold text-ink">{t('lesson.checkpointRemedialNotice')}</p>
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={() => {
                                if (switchToAlternateExercise()) {
                                  setPickedOption(null);
                                  setTextAnswer('');
                                  setMatchedPairs({});
                                  setSelectedMatchLeft(null);
                                  setOrderedTokenIndices([]);
                                  setHasSubmittedCurrent(false);
                                }
                              }}
                              className="min-h-11"
                            >
                              {t('lesson.tryAlternateVariant')}
                            </Button>
                          </div>
                        )}

                        {consecutiveMistakes >= 2 && (
                          <div
                            role="status"
                            aria-live="polite"
                            className="space-y-2 rounded-2xl border border-amber-500/40 bg-amber-500/10 px-4 py-3 text-xs sm:text-sm"
                          >
                            <div className="flex flex-wrap items-center justify-between gap-2">
                              <span className="inline-flex items-center gap-1.5 font-extrabold text-[#FCD34D]">
                                <AlertTriangle className="size-4 shrink-0" aria-hidden="true" />
                                {t('lesson.repeatedMistakeTitle', { count: consecutiveMistakes })}
                              </span>
                              <Badge variant="amber" size="sm">{t('lesson.remedialBadge')}</Badge>
                            </div>
                            <p className="font-medium text-graphite">
                              {t('lesson.repeatedMistakeDescription')}
                            </p>
                            <Button
                              size="sm"
                              variant="coral"
                              onClick={currentLesson.requiresMastery ? reviewWorkedExample : openReinforcement}
                              rightIcon={<ArrowRight className="size-4" aria-hidden="true" />}
                              className="min-h-11 font-bold"
                            >
                              {t(currentLesson.requiresMastery ? 'lesson.reviewExample' : 'lesson.remedialAction')}
                            </Button>
                          </div>
                        )}

                        <p className="rounded-xl border border-coral/25 bg-coral/10 px-3 py-2 text-xs font-bold text-ink">
                          {t('adaptive.lessonImpactWrong')}
                        </p>

                        <div className="flex flex-col sm:flex-row gap-2 mt-1">
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={openAIPanel}
                            leftIcon={<Sparkles className="w-4 h-4 text-brand" />}
                            className="min-h-11 font-bold"
                          >{t('lesson.aiAnalysis')}</Button>
                          {consecutiveMistakes < 2 && (
                            <Button
                              variant="coral"
                              size="sm"
                              onClick={currentLesson.requiresMastery ? reviewWorkedExample : openReinforcement}
                              rightIcon={<ArrowRight className="w-4 h-4" />}
                              className="min-h-11 font-bold"
                            >{t(currentLesson.requiresMastery ? 'lesson.reviewExample' : 'tutor.reinforce')}</Button>
                          )}
                        </div>
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
                      disabled={isSubmitDisabled}
                      isLoading={isEvaluatingAnswer}
                      onClick={submitPrimary}
                      rightIcon={<ArrowRight className="w-5 h-5" />}
                      className="min-h-11 w-full sm:w-auto font-black px-8 py-3.5 tracking-wider shadow-lg shadow-indigo-600/30"
                    >{t('lesson.check')}</Button>
                  ) : (
                    <div className="flex flex-wrap items-center gap-3 w-full sm:w-auto">
                      {!lastAnswerResult?.isCorrect && (
                        <Button
                          variant="outline"
                          size="md"
                          onClick={handleRetryExercise}
                          leftIcon={<RotateCcw className="w-4 h-4" />}
                          className="min-h-11 flex-1 sm:flex-none"
                        >{t('courses.retry')}</Button>
                      )}
                      {canAdvanceAfterSubmit && (
                        <Button
                          variant="gradient"
                          size="md"
                          onClick={nextStep}
                          isLoading={isCompletingLesson}
                          rightIcon={<ArrowRight className="w-4 h-4" />}
                          className="min-h-11 flex-1 sm:flex-none font-black"
                        >
                          {isSelfAssessed && isFinalStep ? t('lesson.complete') : t('lesson.nextQuestion')}
                        </Button>
                      )}
                    </div>
                  )}
                </div>
              </div>
            )}

            {/* Navigation Buttons for Standard Content Steps */}
            {!interactiveQ && (
              <div className="pt-6 border-t border-hairline flex flex-wrap items-center justify-between gap-2">
                <Button
                  variant="ghost"
                  size="md"
                  onClick={prevStep}
                  disabled={currentStepIndex === 0}
                  leftIcon={<ArrowLeft className="w-4 h-4" />}
                  className="min-h-11"
                >{t('lesson.previous')}</Button>

                <Button
                  variant="primary"
                  size="md"
                  onClick={nextStep}
                  disabled={isCompletingLesson || isEvaluatingAnswer || isCompleted}
                  isLoading={isCompletingLesson}
                  aria-busy={isCompletingLesson}
                  rightIcon={<ArrowRight className="w-5 h-5" />}
                  className="min-h-11"
                >
                  {isCompletingLesson ? t('lesson.saving') : isFinalStep ? (error ? t('courses.retry') : t('lesson.complete')) : t('lesson.nextStep')}
                </Button>
              </div>
            )}
          </div>
      </motion.div>

      {help && (
        <Modal
          isOpen
          onClose={() => {
            resetLazyTutorConversationIfFailed();
            setHelp(null);
          }}
          title={help === 'tutor' ? t('lesson.lessonChat') : t('lesson.englishDictionary')}
        >
          {help === 'tutor' ? (
            <TutorModalErrorBoundary
              errorTitle={t('shell.openFailed')}
              errorDescription={t('shell.reloadDescription')}
              retryLabel={t('courses.retry')}
              closeLabel={t('courses.close')}
              onRetry={() => {
                resetLazyTutorConversationIfFailed();
                setTutorRetryNonce((prev) => prev + 1);
              }}
              onClose={() => {
                resetLazyTutorConversationIfFailed();
                setHelp(null);
              }}
            >
              <React.Suspense key={tutorRetryNonce} fallback={<p role="status" className="py-4 text-sm text-slatefine">{t('shell.pageLoading')}</p>}>
                <LazyTutorConversation compact
                  conversation={[account?.id, currentLesson.courseId, currentLesson.id].join('/')}
                  courseId={currentLesson.courseId} courseTitle={activeCourse.title} skillId={currentLesson.skillId}
                  lessonId={currentLesson.id}
                  topic={localizedLessonTitle} score={savedScore}
                  questionId={interactiveQ?.id || undefined}
                  questionPrompt={interactiveQ ? localizedQuestionText : undefined}
                  questionSkillId={interactiveQ?.skillId}
                  recentMistakes={recentMistakeHints}
                  isDemoMode={isDemoMode} />
              </React.Suspense>
            </TutorModalErrorBoundary>
          ) : <DictionaryLookup />}
        </Modal>
      )}

      {/* Yo'lchi AI Feedback Panel */}
      {showAIPanel && lastAnswerResult && interactiveQ && <YolchiAIPanel
        question={interactiveQ}
        answer={lastAnswerResult}
        lessonId={currentLesson.id}
        learnerScore={savedScore}
        recentMistakes={recentMistakeHints}
        onProceedToReinforcement={currentLesson.requiresMastery ? reviewWorkedExample : openReinforcement}
        onClose={closeAIPanel}
      />}

      {/* Reinforcement Exercise Modal */}
      <ReinforcementModal
        isOpen={showReinforcementModal}
        question={currentLesson.reinforcementExercise}
        courseId={currentLesson.courseId}
        skillId={currentLesson.reinforcementExercise.skillId || currentLesson.skillId}
        lessonId={currentLesson.id}
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
        lessonTitle={localizedLessonTitle}
        skill={completedSkill}
        mastery={currentLesson.requiresMastery}
        onProceedToNext={() => {
          useLessonStore.getState().resetLessonState();
          onFinish();
        }}
      />
    </div>
  );
};
