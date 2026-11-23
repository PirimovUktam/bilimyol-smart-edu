import { useEffect, useRef, useState } from 'react';
import { ArrowLeft, ArrowRight, BookOpen, Check, ClipboardCheck, Route, ListChecks, Target } from 'lucide-react';
import { useTranslation } from '@/core/locales/useTranslation';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import type { DailyTimeCommitment, InitialLevel, OnboardingGoal } from '@/core/types/common';
import { foundationLessons, pendingFoundationLessons } from '@/domain/personalization/learningStart';
import { Button } from '@/presentation/components/Button';
import { SectionState } from '@/presentation/components/SectionState';
import { StudyPlanPreview } from './StudyPlanPreview';
import { useStudyPlan } from './useStudyPlan';

const starts = [
  { id: 'guided', hint: 'guidedHint', Icon: BookOpen },
  { id: 'map', hint: 'mapHint', Icon: Route },
  { id: 'diagnostic', hint: 'diagnosticHint', Icon: ClipboardCheck },
] as const;
const goals = [
  { id: 'mastery', Icon: BookOpen }, { id: 'exam_prep', Icon: ListChecks }, { id: 'skills_boost', Icon: Target },
] as const;
type Start = typeof starts[number]['id'];
const times = [15, 30, 60] as const;

export function OnboardingView({ onComplete, onBack, editing = false }: {
  onComplete: (courseId: string, level: InitialLevel, diagnostic: boolean) => void;
  onBack: () => void;
  editing?: boolean;
}) {
  const { t } = useTranslation();
  const course = useCourseStore((state) => state.activeCourse);
  const profile = useLearnerStore((state) => state.profile);
  const roadmap = useRoadmapStore((state) => state.roadmap);
  const roadmapError = useRoadmapStore((state) => state.error);
  const [choice, setChoice] = useState<Start>();
  const [goalChoice, setGoal] = useState<OnboardingGoal>();
  const [minutesChoice, setMinutes] = useState<DailyTimeCommitment>();
  const [pending, setPending] = useState(false);
  const [error, setError] = useState('');
  const mounted = useRef(false);
  const saving = useRef(false);
  const courseId = course?.id;
  const savedLevel = courseId ? profile?.courseLevels?.[courseId] : undefined;
  const start = choice ?? (savedLevel ? savedLevel === 'beginner' ? 'guided' : 'map' : null);
  const diagnostic = start === 'diagnostic';
  const entryLevels = { guided: 'beginner', diagnostic: savedLevel ?? 'beginner',
    map: savedLevel === 'advanced' ? 'advanced' : 'intermediate' } as const;
  const level = start ? entryLevels[start] : null;
  const goal = goalChoice ?? profile?.goal ?? 'mastery';
  const minutes = minutesChoice ?? profile?.dailyMinutes ?? 15;
  const path = roadmap?.courseId === courseId ? roadmap : null;
  const plan = useStudyPlan(course, profile, path, level ?? 'beginner', goal, minutes);
  const nextFoundation = pendingFoundationLessons(course, profile, level)[0];

  useEffect(() => {
    mounted.current = true;
    return () => { mounted.current = false; };
  }, []);

  useEffect(() => {
    if (courseId) void useRoadmapStore.getState().loadRoadmap(courseId);
  }, [courseId]);

  const submit = async () => {
    if (!courseId || !level || saving.current) return;
    saving.current = true;
    setPending(true);
    setError('');
    const isCurrent = () => mounted.current && useCourseStore.getState().activeCourse?.id === courseId;
    try {
      await useLearnerStore.getState().saveCourseLearningPlan(courseId, goal, minutes, level, isCurrent);
      if (isCurrent()) onComplete(courseId, level, diagnostic);
    } catch {
      if (isCurrent()) setError(t('courses.saveFailed'));
    } finally {
      saving.current = false;
      if (isCurrent()) setPending(false);
    }
  };

  const previewStatus = plan.unavailable || (!path && roadmapError) ? 'unavailable'
    : plan.loading || !path ? 'loading' : 'empty';

  return (
    <div className="learning-page max-w-296 space-y-5 sm:space-y-7">
      <header className="space-y-2">
        <Button variant="ghost" size="sm" className="-ml-3 text-slatefine" disabled={pending} onClick={onBack} leftIcon={<ArrowLeft aria-hidden="true" className="size-4" />}>{t(editing ? 'courses.back' : 'courses.backSubjects')}</Button>
        {course && <p className="pt-1 text-sm font-bold text-brand-dark">{course.title}</p>}
        <h1 className="heading max-w-3xl text-[clamp(1.85rem,5vw,3.55rem)] font-extrabold leading-[1.05] tracking-[-0.055em]">{t('courses.plan')}</h1>
        <p className="max-w-2xl text-sm leading-relaxed text-slatefine sm:text-base">{t('entryPlan.intro')}</p>
      </header>

      {!course ? <SectionState title={t('courses.chooseFirst')} /> : (
        <form className="grid items-start gap-4 lg:grid-cols-[minmax(0,1.03fr)_minmax(0,.97fr)] lg:grid-rows-[auto_1fr] lg:gap-x-6" onSubmit={(event) => { event.preventDefault(); void submit(); }}>
          <div className="min-w-0 rounded-3xl border border-hairline bg-paper p-4 shadow-[var(--surface-shadow)] sm:p-6">
            <fieldset disabled={pending} className="min-w-0">
              <legend className="mb-3 text-xl font-extrabold tracking-tight">{t('entryPlan.start')}</legend>
              <div className="grid gap-2 sm:grid-cols-3">
                {starts.map(({ id, hint, Icon }) => (
                  <label key={id} className="relative cursor-pointer">
                    <input type="radio" name="entry-route" value={id} checked={start === id} onChange={() => setChoice(id)} className="peer absolute inset-0 z-10 size-full cursor-pointer opacity-0" />
                    <span className="flex h-full items-center gap-3 rounded-2xl border border-hairline p-3 peer-checked:border-brand peer-checked:bg-brand/8 peer-focus-visible:outline-2 peer-focus-visible:outline-brand sm:flex-col sm:items-start">
                      <span className="flex size-9 shrink-0 items-center justify-center rounded-xl bg-sand text-brand-dark"><Icon aria-hidden="true" className="size-5" /></span>
                      <span><strong className="block leading-tight">{t(`entryPlan.${id}`)}</strong><span className="mt-1 block text-xs leading-relaxed text-slatefine">{t(`entryPlan.${hint}`)}</span></span>
                      {start === id && <Check aria-hidden="true" className="ml-auto size-4 shrink-0 text-brand-dark sm:absolute sm:right-3 sm:top-3" />}
                    </span>
                  </label>
                ))}
              </div>
            </fieldset>

            <fieldset disabled={pending} className="mt-6 min-w-0">
              <legend className="mb-3 text-xl font-extrabold tracking-tight">{t('entryPlan.goal')}</legend>
              <div className="flex flex-wrap gap-2">
                {goals.map(({ id, Icon }) => (
                  <label key={id} className="relative cursor-pointer">
                    <input type="radio" name="plan-goal" className="peer absolute inset-0 z-10 size-full cursor-pointer opacity-0" value={id} checked={goal === id} onChange={() => setGoal(id)} />
                    <span className="inline-flex min-h-11 items-center gap-2 rounded-full border border-hairline px-3.5 text-sm font-semibold peer-checked:border-brand peer-checked:bg-brand peer-checked:text-white peer-focus-visible:outline-2 peer-focus-visible:outline-offset-2 peer-focus-visible:outline-brand"><Icon aria-hidden="true" className="size-4" />{t(`entryPlan.${id}`)}</span>
                  </label>
                ))}
              </div>
              <p aria-live="polite" className="mt-3 rounded-xl bg-sand px-4 py-3 text-sm leading-relaxed text-ink">{t(`entryPlan.${goal === 'mastery' ? course.subject : goal === 'exam_prep' ? 'examHint' : 'practiceHint'}`)}</p>
            </fieldset>
            <div className="mt-5 space-y-2 border-t border-hairline pt-4">
              <fieldset disabled={pending} className="min-w-0">
                <legend className="mb-1.5 text-sm font-extrabold text-ink">{t('courses.dailyTime')}</legend>
                <div className="grid grid-cols-3 gap-1 rounded-2xl bg-sand p-1">
                  {times.map((time) => (
                    <label key={time} className="relative block min-w-0 cursor-pointer">
                      <input type="radio" name="daily-minutes" className="peer absolute inset-0 z-10 size-full cursor-pointer opacity-0" value={time} checked={time === minutes} onChange={() => setMinutes(time)} />
                      <span className="flex min-h-11 flex-wrap items-center justify-center gap-x-1 rounded-xl px-1 text-center text-sm font-bold text-slatefine peer-checked:bg-paper peer-checked:text-brand-dark peer-checked:shadow-xs peer-focus-visible:outline-2 peer-focus-visible:outline-brand"><span className="font-mono">{time}</span><span className="text-xs">{t('courses.minutes')}</span></span>
                    </label>
                  ))}
                </div>
              </fieldset>
              <p className="text-xs text-slatefine">{t('studyPlan.sharedPreferences')}</p>
            </div>
          </div>

          <div className="min-w-0 space-y-3 lg:col-start-1 lg:row-start-2">
            {error && <p role="alert" className="rounded-xl border border-coral/45 bg-coral/10 px-4 py-3 text-sm text-ink">{error}</p>}
            <div className="flex flex-col gap-2.5 sm:flex-row sm:items-center">
              <Button type="submit" disabled={!level || pending} isLoading={pending} leftIcon={<BookOpen aria-hidden="true" className="size-4" />} rightIcon={<ArrowRight aria-hidden="true" className="size-4" />}>
                {t(diagnostic ? 'entryPlan.testAction' : editing ? 'studyPlan.save' : nextFoundation
                  ? nextFoundation === foundationLessons(course)[0] ? 'courses.firstLesson' : 'courses.continueFoundation'
                  : start === 'guided' && plan.sessions[0]?.items[0]?.ready ? 'courses.continue' : 'courses.openPath')}
              </Button>
            </div>
          </div>
          <div className="min-w-0 lg:sticky lg:top-5 lg:col-start-2 lg:row-span-2 lg:row-start-1">
            {diagnostic ? <section className="rounded-3xl bg-[#25264e] p-6 text-white" aria-live="polite">
              <ClipboardCheck aria-hidden="true" className="mb-4 size-8 text-teal-200" />
              <h2 className="text-2xl font-bold">{t('entryPlan.testFirst')}</h2>
              <p className="mt-2 max-w-prose text-sm leading-relaxed text-indigo-100">{t('entryPlan.testExplain')}</p>
            </section> : <StudyPlanPreview sessions={plan.sessions} minutes={minutes} status={previewStatus} sample={!level} />}
          </div>

        </form>
      )}
    </div>
  );
}
