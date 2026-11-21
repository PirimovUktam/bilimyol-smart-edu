import { useState } from 'react';
import { AnimatePresence, MotionConfig, motion, useReducedMotion } from 'framer-motion';
import {
  ArrowLeft,
  ArrowRight,
  Check,
  Compass,
  MapPin,
  RotateCcw,
  Sparkles,
} from 'lucide-react';
import { useTranslation } from '@/core/locales/useTranslation';
import { BilimYolLogo } from '@/presentation/components/BilimYolLogo';
import { Button } from '@/presentation/components/Button';
import { YolchiAIMascot } from '@/presentation/components/YolchiAIMascot';

export interface ProductTourViewProps {
  mode?: 'first-visit' | 'replay';
  onComplete: () => void;
  onSkip: () => void;
}

type MiniOption = 'am' | 'is' | 'are';

const MINI_OPTIONS: readonly MiniOption[] = ['am', 'is', 'are'] as const;

export function ProductTourView({
  mode = 'first-visit',
  onComplete,
  onSkip,
}: ProductTourViewProps) {
  const { t } = useTranslation();
  const prefersReducedMotion = useReducedMotion();
  const [sceneIndex, setSceneIndex] = useState(0);
  const [selectedOption, setSelectedOption] = useState<MiniOption | null>(null);

  const scenes = [
    {
      badge: t('tour.scene1Label'),
      titleStart: t('tour.scene1TitleStart'),
      titleAccent: t('tour.scene1TitleAccent'),
      titleFull: t('tour.scene1TitleFull'),
      description: t('tour.scene1Description'),
      cta: t('tour.scene1Cta'),
    },
    {
      badge: t('tour.scene2Label'),
      titleStart: t('tour.scene2TitleStart'),
      titleAccent: t('tour.scene2TitleAccent'),
      titleFull: t('tour.scene2TitleFull'),
      description: t('tour.scene2Description'),
      cta: t('tour.scene2Cta'),
    },
    {
      badge: t('tour.scene3Label'),
      titleStart: t('tour.scene3TitleStart'),
      titleAccent: t('tour.scene3TitleAccent'),
      titleFull: t('tour.scene3TitleFull'),
      description: t('tour.scene3Description'),
      cta: t('tour.scene3Cta'),
    },
  ] as const;

  const activeScene = scenes[sceneIndex];
  const isFirstScene = sceneIndex === 0;
  const isLastScene = sceneIndex === scenes.length - 1;

  const handleNext = () => {
    if (isLastScene) {
      onComplete();
      return;
    }
    setSceneIndex((current) => Math.min(current + 1, scenes.length - 1));
  };

  const handleBack = () => {
    setSceneIndex((current) => Math.max(current - 1, 0));
  };

  const isCorrectOption = selectedOption === 'am';
  const feedbackMessage =
    selectedOption === 'am'
      ? t('tour.scene2CorrectFeedback')
      : selectedOption === 'is'
      ? t('tour.scene2WrongIs')
      : selectedOption === 'are'
      ? t('tour.scene2WrongAre')
      : null;

  return (
    <MotionConfig reducedMotion="user">
      <div
        className="mx-auto flex w-full max-w-6xl flex-col px-4 pt-2 pb-5 sm:px-8 sm:pt-4 lg:min-h-[calc(100dvh-4rem)] lg:justify-between lg:py-6"
        data-tour-scene={sceneIndex + 1}
      >
        <div className="flex items-center justify-between gap-2 py-1 sm:py-2">
          <BilimYolLogo
            size="sm"
            showSubtitle={false}
            variant="auto"
            className="min-w-0 shrink gap-2! [&_span]:whitespace-nowrap [&_span.uppercase]:hidden sm:[&_span.uppercase]:inline-block"
          />

          <div className="flex shrink-0 items-center gap-1.5 sm:gap-3">
            <span
              className="font-mono-num inline-flex min-h-9 shrink-0 items-center whitespace-nowrap rounded-full border border-hairline bg-paper px-2.5 text-xs font-extrabold text-brand-dark shadow-2xs sm:px-3"
              aria-live="polite"
            >
              {t('tour.stepCounter', { current: sceneIndex + 1, total: scenes.length })}
            </span>
            <button
              type="button"
              onClick={onSkip}
              className="inline-flex min-h-11 shrink-0 cursor-pointer items-center whitespace-nowrap rounded-xl border border-transparent px-2 text-xs font-bold text-slatefine transition-colors hover:border-hairline hover:bg-sand hover:text-ink sm:px-3 sm:text-sm"
            >
              {t('tour.skip')}
            </button>
          </div>
        </div>

        <div className="my-auto grid items-center gap-4 py-1 sm:gap-6 lg:grid-cols-12 lg:gap-12 lg:py-4">
          <div className="order-1 lg:order-2 lg:col-span-7">
            <AnimatePresence mode={prefersReducedMotion ? 'sync' : 'wait'} initial={false}>
              <motion.div
                key={sceneIndex}
                initial={prefersReducedMotion ? false : { opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                exit={prefersReducedMotion ? undefined : { opacity: 0, y: -10 }}
                transition={prefersReducedMotion ? { duration: 0 } : { duration: 0.24, ease: [0.22, 1, 0.36, 1] }}
              >
                {sceneIndex === 0 && (
                  <KnowledgeMapStage variant="discovery" reducedMotion={Boolean(prefersReducedMotion)} />
                )}
                {sceneIndex === 1 && (
                  <MiniExerciseStage
                    selectedOption={selectedOption}
                    isCorrectOption={isCorrectOption}
                    feedbackMessage={feedbackMessage}
                    onSelect={setSelectedOption}
                  />
                )}
                {sceneIndex === 2 && (
                  <KnowledgeMapStage variant="result" reducedMotion={Boolean(prefersReducedMotion)} />
                )}
              </motion.div>
            </AnimatePresence>
          </div>

          <section
            aria-labelledby={`tour-scene-heading-${sceneIndex + 1}`}
            className="order-2 space-y-3 sm:space-y-4 lg:order-1 lg:col-span-5 lg:space-y-5"
          >
            <div className="flex flex-wrap items-center gap-2">
              <span className="highlight">
                {sceneIndex === 0 ? (
                  <Compass aria-hidden="true" className="size-3.5 text-brand-dark" />
                ) : sceneIndex === 1 ? (
                  <Sparkles aria-hidden="true" className="size-3.5 text-brand-dark" />
                ) : (
                  <MapPin aria-hidden="true" className="size-3.5 text-brand-dark" />
                )}
                {activeScene.badge}
              </span>
              {mode === 'replay' && (
                <span className="inline-flex items-center rounded-full border border-hairline bg-paper px-2.5 py-1 text-[11px] font-bold text-slatefine">
                  {t('tour.replayBadge')}
                </span>
              )}
            </div>

            <h1
              id={`tour-scene-heading-${sceneIndex + 1}`}
              className="heading text-[clamp(1.65rem,4.6vw,3.1rem)] leading-[1.08] font-extrabold tracking-tight"
            >
              {activeScene.titleStart}{' '}
              <span className="heading-accent">{activeScene.titleAccent}</span>
            </h1>

            <p className="max-w-lg text-sm leading-relaxed text-slatefine sm:text-base lg:text-[1.0625rem]">
              {activeScene.description}
            </p>

            <div className="flex flex-wrap items-center gap-2.5 pt-1 sm:gap-3">
              {!isFirstScene && (
                <Button
                  size="lg"
                  variant="outline"
                  onClick={handleBack}
                  leftIcon={<ArrowLeft aria-hidden="true" className="size-4.5" />}
                  className="shrink-0"
                >
                  {t('tour.back')}
                </Button>
              )}
              <Button
                size="lg"
                variant={isLastScene ? 'success' : 'primary'}
                onClick={handleNext}
                rightIcon={<ArrowRight aria-hidden="true" className="size-4.5" />}
                className="flex-1 sm:flex-none sm:min-w-44"
              >
                {activeScene.cta}
              </Button>
            </div>

            <nav
              aria-label={t('tour.eyebrow')}
              className="flex items-center gap-2 pt-0.5 sm:pt-2"
            >
              {scenes.map((scene, index) => {
                const isActive = index === sceneIndex;
                return (
                  <button
                    key={scene.badge}
                    type="button"
                    onClick={() => setSceneIndex(index)}
                    aria-current={isActive ? 'step' : undefined}
                    aria-label={t('tour.stepAria', { step: index + 1, title: scene.titleFull })}
                    className="group inline-flex min-h-11 min-w-11 cursor-pointer items-center justify-center rounded-full px-1 transition-colors hover:bg-sand/70"
                  >
                    <span
                      aria-hidden="true"
                      className={`h-2.5 rounded-full transition-all duration-200 ${
                        isActive
                          ? 'w-9 bg-gradient-to-r from-[#4F46E5] to-[#06B6D4] dark:from-[#8B5CF6] dark:to-[#22D3EE]'
                          : 'w-2.5 bg-hairline group-hover:bg-faint'
                      }`}
                    />
                  </button>
                );
              })}
            </nav>
          </section>
        </div>
      </div>
    </MotionConfig>
  );
}

function KnowledgeMapStage({
  variant,
  reducedMotion,
}: {
  variant: 'discovery' | 'result';
  reducedMotion: boolean;
}) {
  const { t } = useTranslation();
  const isResult = variant === 'result';

  return (
    <div
      className="relative overflow-hidden rounded-3xl border border-indigo-200/80 bg-gradient-to-br from-[#EEF2FF] via-[#F8FAFC] to-[#E0F2FE] p-4 shadow-[0_22px_54px_-16px_rgba(79,70,229,0.22)] sm:p-6 dark:border-indigo-400/30 dark:bg-gradient-to-br dark:from-[#121742] dark:via-[#181D52] dark:to-[#251A5C] dark:shadow-[0_24px_60px_-14px_rgba(4,6,22,0.82)]"
      data-stage={variant}
    >
      <div
        aria-hidden="true"
        className="pointer-events-none absolute -top-14 -right-10 size-44 rounded-full bg-cyan-400/18 blur-2xl dark:bg-cyan-400/20"
      />
      <div
        aria-hidden="true"
        className="pointer-events-none absolute -bottom-16 -left-10 size-44 rounded-full bg-indigo-500/16 blur-2xl dark:bg-purple-500/25"
      />

      <div className="relative flex flex-wrap items-center justify-between gap-2">
        <span
          className={`inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-[11px] font-extrabold tracking-wide ${
            isResult
              ? 'border border-amber-500/35 bg-amber-50 text-amber-900 dark:border-amber-400/40 dark:bg-amber-400/15 dark:text-amber-200'
              : 'border border-indigo-300/60 bg-white/90 text-indigo-900 shadow-2xs dark:border-indigo-400/35 dark:bg-white/10 dark:text-indigo-100'
          }`}
        >
          <span
            aria-hidden="true"
            className={`size-2 rounded-full ${
              isResult ? 'bg-amber-500 dark:bg-amber-300' : 'bg-cyan-500 dark:bg-cyan-300'
            }`}
          />
          {isResult ? t('tour.scene3SampleBadge') : t('tour.scene1MapTag')}
        </span>

        <div className="hidden items-center gap-2 rounded-full border border-indigo-200/70 bg-white/85 px-2.5 py-1 text-[11px] font-bold text-slate-700 sm:inline-flex dark:border-white/15 dark:bg-white/10 dark:text-indigo-100">
          <YolchiAIMascot size="xs" mood={isResult ? 'celebrating' : 'happy'} />
          <span>Yo‘lchi AI</span>
        </div>
      </div>

      <div className="relative mt-3 sm:mt-5 sm:py-2">
        <svg
          aria-hidden="true"
          viewBox="0 0 600 220"
          className="pointer-events-none absolute inset-0 hidden h-full w-full sm:block"
          preserveAspectRatio="none"
        >
          <defs>
            <linearGradient id={`tour-active-path-${variant}`} x1="0%" y1="50%" x2="100%" y2="50%">
              <stop offset="0%" stopColor={isResult ? '#10B981' : '#4F46E5'} />
              <stop offset="100%" stopColor={isResult ? '#06B6D4' : '#22D3EE'} />
            </linearGradient>
          </defs>

          <path
            d="M 125 110 C 145 110, 152 110, 178 110"
            fill="none"
            stroke={isResult ? '#10B981' : '#6366F1'}
            strokeOpacity={isResult ? 0.65 : 0.45}
            strokeWidth="3.5"
            strokeDasharray="6 5"
          />

          <path
            d="M 378 110 C 402 110, 405 64, 434 64"
            fill="none"
            stroke={isResult ? `url(#tour-active-path-${variant})` : '#6366F1'}
            strokeOpacity={isResult ? 1 : 0.38}
            strokeWidth={isResult ? 5 : 3}
            strokeLinecap="round"
          />

          <path
            d="M 378 110 C 402 110, 405 162, 434 162"
            fill="none"
            stroke="#64748B"
            strokeOpacity="0.32"
            strokeWidth="2.5"
            strokeDasharray="5 5"
          />
        </svg>

        <div className="relative grid grid-cols-1 gap-2 sm:grid-cols-12 sm:items-center sm:gap-5">
          <div className="sm:col-span-3">
            <div className="flex items-center gap-2 rounded-2xl border border-slate-200/90 bg-white/90 px-3 py-2 shadow-2xs dark:border-white/15 dark:bg-[#192050]/90">
              <span className="grid size-6 shrink-0 place-items-center rounded-full bg-emerald-500/15 text-emerald-700 dark:bg-emerald-400/20 dark:text-emerald-300">
                <Check aria-hidden="true" className="size-3.5" />
              </span>
              <p className="text-xs font-bold text-slate-700 dark:text-indigo-100">
                {t('tour.nodeGreeting')}
              </p>
            </div>
          </div>

          <div className="sm:col-span-5">
            <div
              className={`relative rounded-2xl border-2 p-3 sm:p-4 transition-all ${
                isResult
                  ? 'border-emerald-500 bg-white shadow-[0_12px_30px_-8px_rgba(16,185,129,0.28)] dark:border-emerald-400 dark:bg-[#16274C]'
                  : 'border-[#4F46E5] bg-white shadow-[0_14px_34px_-6px_rgba(79,70,229,0.34)] dark:border-[#22D3EE] dark:bg-[#1D245E] dark:shadow-[0_0_28px_rgba(34,211,238,0.28)]'
              }`}
            >
              {!isResult && !reducedMotion && (
                <span
                  aria-hidden="true"
                  className="pointer-events-none absolute -inset-1 rounded-[18px] border border-indigo-500/35 lab-pulse dark:border-cyan-300/45"
                />
              )}
              <div className="flex items-center justify-between gap-2">
                <span
                  className={`inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-[11px] font-extrabold ${
                    isResult
                      ? 'bg-emerald-100 text-emerald-800 dark:bg-emerald-400/20 dark:text-emerald-200'
                      : 'bg-indigo-100 text-indigo-800 dark:bg-cyan-400/20 dark:text-cyan-200'
                  }`}
                >
                  {isResult ? (
                    <Check aria-hidden="true" className="size-3" />
                  ) : (
                    <Sparkles aria-hidden="true" className="size-3" />
                  )}
                  {isResult ? t('tour.scene3PracticedBadge') : t('tour.scene1StartBadge')}
                </span>
              </div>
              <p className="mt-2 font-display text-sm font-extrabold text-slate-900 sm:text-base dark:text-white">
                {t('tour.nodeFocal')}
              </p>
              <p className="mt-0.5 text-xs font-medium text-slate-600 dark:text-indigo-200">
                {isResult ? 'I am a student' : t('tour.scene1StartHint')}
              </p>
            </div>
          </div>

          {isResult && (
            <div aria-hidden="true" className="flex justify-center sm:hidden">
              <span className="h-3.5 w-1 rounded-full bg-gradient-to-b from-emerald-500 to-cyan-500" />
            </div>
          )}

          <div className="grid grid-cols-2 gap-2 sm:col-span-4 sm:grid-cols-1 sm:gap-2.5">
            <div
              className={`rounded-2xl border p-2.5 sm:p-3 transition-all ${
                isResult
                  ? 'border-[#4F46E5] bg-white shadow-[0_14px_30px_-8px_rgba(79,70,229,0.3)] dark:border-cyan-300 dark:bg-[#1C2460] dark:shadow-[0_0_24px_rgba(34,211,238,0.22)]'
                  : 'border-slate-200/90 bg-white/80 dark:border-white/15 dark:bg-[#192050]/80'
              }`}
            >
              {isResult && (
                <span className="mb-1 inline-flex items-center gap-1 rounded-full bg-indigo-100 px-2 py-0.5 text-[10px] font-extrabold text-indigo-800 dark:bg-cyan-400/20 dark:text-cyan-200">
                  <ArrowRight aria-hidden="true" className="size-3" />
                  {t('tour.scene3NextBadge')}
                </span>
              )}
              <p className="text-xs font-extrabold text-slate-900 sm:text-sm dark:text-white">
                {t('tour.nodeNext')}
              </p>
            </div>

            <div className="flex flex-col justify-center gap-1.5 rounded-2xl border border-slate-200/80 bg-white/65 px-3 py-2 text-xs font-semibold text-slate-600 dark:border-white/10 dark:bg-white/5 dark:text-indigo-200">
              <span>{t('tour.nodePresent')}</span>
              <span className="h-px bg-slate-200/80 dark:bg-white/10" aria-hidden="true" />
              <span>{t('tour.nodeListening')}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function MiniExerciseStage({
  selectedOption,
  isCorrectOption,
  feedbackMessage,
  onSelect,
}: {
  selectedOption: MiniOption | null;
  isCorrectOption: boolean;
  feedbackMessage: string | null;
  onSelect: (option: MiniOption) => void;
}) {
  const { t } = useTranslation();

  return (
    <div
      className="relative overflow-hidden rounded-3xl border border-indigo-200/80 bg-gradient-to-br from-[#EEF2FF] via-[#F8FAFC] to-[#ECFEFF] p-4 shadow-[0_22px_54px_-16px_rgba(79,70,229,0.22)] sm:p-6 dark:border-indigo-400/35 dark:bg-gradient-to-br dark:from-[#121742] dark:via-[#181D52] dark:to-[#241A5B] dark:shadow-[0_24px_60px_-14px_rgba(4,6,22,0.82)]"
      data-stage="exercise"
    >
      <div className="flex flex-wrap items-center justify-between gap-2">
        <span className="inline-flex items-center gap-1.5 rounded-full border border-indigo-300/60 bg-white/90 px-3 py-1 text-[11px] font-extrabold text-indigo-900 dark:border-cyan-400/30 dark:bg-cyan-400/15 dark:text-cyan-200">
          <Sparkles aria-hidden="true" className="size-3.5" />
          {t('tour.scene2PromptLabel')}
        </span>
        <span className="inline-flex items-center rounded-full border border-slate-200 bg-white/80 px-2.5 py-1 text-[11px] font-bold text-slate-600 dark:border-white/15 dark:bg-white/10 dark:text-indigo-200">
          {t('tour.scene2GuestBadge')}
        </span>
      </div>

      <div className="mt-3 rounded-2xl border border-slate-200/90 bg-white p-4 shadow-sm sm:mt-4 sm:p-5 dark:border-white/15 dark:bg-[#171D4B]">
        <p className="text-xs font-semibold text-slate-600 sm:text-sm dark:text-indigo-200">
          {t('tour.scene2Instruction')}
        </p>

        <p className="mt-2.5 flex flex-wrap items-center gap-2 font-display text-2xl font-extrabold tracking-tight text-slate-900 sm:text-3xl dark:text-white">
          <span>I</span>
          <span
            className={`inline-flex min-w-16 items-center justify-center rounded-xl border-2 px-3 py-0.5 text-center transition-colors ${
              selectedOption === null
                ? 'border-dashed border-indigo-400 bg-indigo-50 text-indigo-700 dark:border-cyan-400/70 dark:bg-cyan-400/10 dark:text-cyan-200'
                : isCorrectOption
                ? 'border-emerald-500 bg-emerald-50 text-emerald-800 dark:border-emerald-400 dark:bg-emerald-400/20 dark:text-emerald-200'
                : 'border-amber-500 bg-amber-50 text-amber-900 dark:border-amber-400 dark:bg-amber-400/20 dark:text-amber-200'
            }`}
          >
            {selectedOption ?? '___'}
          </span>
          <span>a student.</span>
        </p>

        <div className="mt-4 grid grid-cols-3 gap-2.5">
          {MINI_OPTIONS.map((option) => {
            const isSelected = selectedOption === option;
            const optionIsCorrect = option === 'am';
            const stateClasses = !isSelected
              ? 'border-slate-200 bg-slate-50 text-slate-900 hover:border-indigo-400 hover:bg-indigo-50/70 dark:border-white/15 dark:bg-[#202763] dark:text-white dark:hover:border-cyan-300'
              : optionIsCorrect
              ? 'border-emerald-500 bg-emerald-600 text-white shadow-[0_8px_20px_-4px_rgba(16,185,129,0.5)]'
              : 'border-amber-500 bg-amber-100 text-amber-950 dark:border-amber-400 dark:bg-amber-400/25 dark:text-amber-100';

            return (
              <button
                key={option}
                type="button"
                onClick={() => onSelect(option)}
                aria-pressed={isSelected}
                className={`inline-flex min-h-12 cursor-pointer items-center justify-center gap-1.5 rounded-2xl border-2 px-3 py-2 font-display text-base font-extrabold transition-all active:scale-[0.98] ${stateClasses}`}
              >
                {isSelected && optionIsCorrect && <Check aria-hidden="true" className="size-4" />}
                {isSelected && !optionIsCorrect && <RotateCcw aria-hidden="true" className="size-3.5" />}
                <span>{option}</span>
              </button>
            );
          })}
        </div>

        <div
          role="status"
          aria-live="polite"
          className={`mt-3 rounded-2xl border px-3.5 py-2.5 text-xs font-semibold leading-relaxed sm:text-sm ${
            feedbackMessage === null
              ? 'border-slate-200/80 bg-slate-50/90 text-slate-600 dark:border-white/10 dark:bg-white/5 dark:text-indigo-200'
              : isCorrectOption
              ? 'border-emerald-400/60 bg-emerald-50 text-emerald-900 dark:border-emerald-400/40 dark:bg-emerald-500/15 dark:text-emerald-200'
              : 'border-amber-400/60 bg-amber-50 text-amber-950 dark:border-amber-400/40 dark:bg-amber-500/15 dark:text-amber-100'
          }`}
        >
          {feedbackMessage ?? t('tour.scene2RetryHint')}
        </div>
      </div>
    </div>
  );
}
