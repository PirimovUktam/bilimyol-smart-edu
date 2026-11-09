import { translate as t } from '@/core/locales/useTranslation';
import { useTranslation } from '@/core/locales/useTranslation';
import { useEffect, useRef, useState } from 'react';
import { ArrowLeft, ArrowRight, BookOpen, ClipboardCheck, Sparkles } from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import type { DailyTimeCommitment, InitialLevel, OnboardingGoal } from '@/core/types/common';
import { foundationLessons } from '@/domain/personalization/learningStart';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';
import { PageHeader } from '@/presentation/components/PageHeader';
import { SectionState } from '@/presentation/components/SectionState';

const levels: { value: InitialLevel; label: string; description: string; badge: string }[] = [
  {
    value: 'beginner',
    get label() { return t('courses.zero'); },
    get description() { return t('courses.zeroDescription'); },
    get badge() { return t('courses.beginner'); },
  },
  {
    value: 'intermediate',
    get label() { return t('courses.basics'); },
    get description() { return t('courses.basicsDescription'); },
    get badge() { return t('courses.intermediate'); },
  },
  {
    value: 'advanced',
    get label() { return t('courses.advanced'); },
    get description() { return t('courses.advancedDescription'); },
    get badge() { return t('courses.advancedBadge'); },
  },
];

const goals: { value: OnboardingGoal; label: string }[] = [
  { value: 'mastery', get label() { return t('courses.masteryGoal'); } },
  { value: 'exam_prep', get label() { return t('courses.exam'); } },
  { value: 'skills_boost', get label() { return t('courses.skillsGoal'); } },
];
const times: DailyTimeCommitment[] = [15, 30, 60];

export function OnboardingView({ onComplete, onBack }: {
  onComplete: (courseId: string, level: InitialLevel, diagnostic: boolean) => void;
  onBack: () => void;
}) {
  const { t } = useTranslation();
  const course = useCourseStore((state) => state.activeCourse);
  const profile = useLearnerStore((state) => state.profile);
  const [level, setLevel] = useState<InitialLevel | null>(course ? profile?.courseLevels?.[course.id] ?? null : null);
  const [goal, setGoal] = useState<OnboardingGoal>(profile?.goal ?? 'mastery');
  const [minutes, setMinutes] = useState<DailyTimeCommitment>(profile?.dailyMinutes ?? 15);
  const [pending, setPending] = useState<'learn' | 'diagnostic' | null>(null);
  const [error, setError] = useState('');
  const mounted = useRef(false);
  const saving = useRef(false);
  const foundation = course ? foundationLessons(course) : [];
  const nextFoundation = foundation.find((id) => !profile?.completedLessonIds.includes(id));

  useEffect(() => {
    mounted.current = true;
    return () => { mounted.current = false; };
  }, []);

  const submit = async (action: 'learn' | 'diagnostic') => {
    if (!course || !level || saving.current) return;
    saving.current = true;
    setPending(action);
    setError('');
    const isCurrent = () => mounted.current && useCourseStore.getState().activeCourse?.id === course.id;
    try {
      await useLearnerStore.getState().saveCourseLearningPlan(course.id, goal, minutes, level, isCurrent);
      if (isCurrent()) onComplete(course.id, level, action === 'diagnostic');
    } catch {
      if (isCurrent()) setError(t('courses.saveFailed'));
    } finally {
      saving.current = false;
      if (isCurrent()) setPending(null);
    }
  };

  return (
    <div className="learning-page max-w-200 space-y-6">
      <PageHeader
        eyebrow={course?.title ?? t('courses.start')}
        title={t('courses.plan')}
        highlightWord={t('courses.planHighlight')}
        description={t('courses.planDescription')}
      />
      {!course ? (
        <Card className="space-y-4">
          <SectionState title={t('courses.chooseFirst')} />
          <Button onClick={onBack}>{t('courses.subjects')}</Button>
        </Card>
      ) : (
        <Card className="fade-up stagger-1 space-y-6" padding="md">
          <form className="space-y-6" onSubmit={(event) => { event.preventDefault(); void submit('learn'); }}>
            <fieldset disabled={pending !== null} className="space-y-3">
              <legend className="heading mb-3 text-lg font-extrabold">{t('courses.startWhere')}</legend>
              {levels.map((option, index) => {
                const selected = level === option.value;
                return (
                  <label
                    key={option.value}
                    style={{ animationDelay: `${index * 70}ms` }}
                    className={
                      'fade-up flex min-h-16 cursor-pointer items-start gap-3.5 rounded-2xl border p-4 transition-all ' +
                      (selected
                        ? 'border-brand bg-sand/70 ring-2 ring-brand/20 shadow-xs'
                        : 'border-hairline bg-paper hover:border-brand/50 hover:-translate-y-0.5')
                    }
                  >
                    <input
                      type="radio"
                      name="learning-level"
                      className="mt-1 size-4 shrink-0 accent-brand"
                      value={option.value}
                      checked={selected}
                      onChange={() => setLevel(option.value)}
                    />
                    <span className="min-w-0 flex-1">
                      <span className="flex flex-wrap items-center justify-between gap-2">
                        <span className="heading text-sm font-extrabold">{option.label}</span>
                        <span className="highlight !py-0.5 !px-2.5 !text-[10px]">{option.badge}</span>
                      </span>
                      <span className="mt-1 block break-words text-sm leading-relaxed text-slatefine">
                        {option.description}
                      </span>
                    </span>
                  </label>
                );
              })}
            </fieldset>

            <details className="rounded-2xl border border-hairline bg-canvas/60 p-4">
              <summary className="cursor-pointer text-sm font-bold text-brand">{t('courses.goalTime')}</summary>
              <div className="mt-4 grid gap-4 sm:grid-cols-2">
                <div>
                  <label htmlFor="start-goal" className="mb-1.5 block text-sm font-bold">{t('courses.goal')}</label>
                  <select
                    id="start-goal"
                    className="form-input px-3"
                    value={goal}
                    disabled={pending !== null}
                    onChange={(event) => setGoal(event.target.value as OnboardingGoal)}
                  >
                    {goals.map((option) => (
                      <option key={option.value} value={option.value}>
                        {option.label}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label htmlFor="start-minutes" className="mb-1.5 block text-sm font-bold">{t('courses.dailyTime')}</label>
                  <select
                    id="start-minutes"
                    className="form-input px-3"
                    value={minutes}
                    disabled={pending !== null}
                    onChange={(event) => setMinutes(Number(event.target.value) as DailyTimeCommitment)}
                  >
                    {times.map((time) => (
                      <option key={time} value={time}>
                        {time}{' '}{t('courses.minutes')}</option>
                    ))}
                  </select>
                </div>
              </div>
            </details>

            {level === 'beginner' && (
              <p className="flex items-center gap-2 rounded-2xl bg-sand p-3.5 text-sm font-medium text-brand-dark">
                <Sparkles aria-hidden="true" className="size-4 shrink-0 text-brand" />
                {nextFoundation
                  ? `${foundation.length} ta boshlang‘ich dars sizni asosiy mavzularga tayyorlaydi.`
                  : t('courses.availableTopics')}
              </p>
            )}
            {error && (
              <p role="alert" className="rounded-2xl bg-rose-50 p-3.5 text-sm text-coral">
                {error}
              </p>
            )}

            <div className="flex flex-wrap items-center gap-2.5 pt-1">
              <Button
                type="submit"
                disabled={level === null || pending === 'diagnostic'}
                isLoading={pending === 'learn'}
                leftIcon={<BookOpen aria-hidden="true" className="size-4" />}
                rightIcon={<ArrowRight aria-hidden="true" className="size-4" />}
              >
                {level === 'beginner' && nextFoundation
                  ? nextFoundation === foundation[0]
                    ? t('courses.firstLesson')
                    : t('courses.continueFoundation')
                  : t('courses.openPath')}
              </Button>
              {level !== null && level !== 'beginner' && (
                <Button
                  type="button"
                  variant="outline"
                  isLoading={pending === 'diagnostic'}
                  disabled={pending === 'learn'}
                  leftIcon={<ClipboardCheck aria-hidden="true" className="size-4" />}
                  onClick={() => void submit('diagnostic')}
                >{t('courses.optionalDiagnostic')}</Button>
              )}
              <Button
                type="button"
                variant="ghost"
                disabled={pending !== null}
                onClick={onBack}
                leftIcon={<ArrowLeft aria-hidden="true" className="size-4" />}
              >{t('courses.backSubjects')}</Button>
            </div>
          </form>
        </Card>
      )}
    </div>
  );
}
