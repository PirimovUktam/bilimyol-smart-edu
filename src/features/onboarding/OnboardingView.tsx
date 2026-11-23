import { useEffect, useRef, useState } from 'react';
import { ArrowLeft, ArrowRight, BookOpen, Check, ClipboardCheck, Compass, Layers, Sprout } from 'lucide-react';
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

const levels = [
  { value: 'beginner', label: 'courses.zero', description: 'courses.zeroDescription', Icon: Sprout },
  { value: 'intermediate', label: 'courses.basics', description: 'courses.basicsDescription', Icon: Layers },
  { value: 'advanced', label: 'courses.advanced', description: 'courses.advancedDescription', Icon: Compass },
] as const;
const goals = [
  { value: 'mastery', label: 'courses.masteryGoal' },
  { value: 'exam_prep', label: 'courses.exam' },
  { value: 'skills_boost', label: 'courses.skillsGoal' },
] as const;
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
  const [levelChoice, setLevel] = useState<InitialLevel>();
  const [goalChoice, setGoal] = useState<OnboardingGoal>();
  const [minutesChoice, setMinutes] = useState<DailyTimeCommitment>();
  const [pending, setPending] = useState<'learn' | 'diagnostic' | null>(null);
  const [error, setError] = useState('');
  const mounted = useRef(false);
  const saving = useRef(false);
  const courseId = course?.id;
  const level = levelChoice ?? (courseId ? profile?.courseLevels?.[courseId] : undefined) ?? null;
  const goal = goalChoice ?? profile?.goal ?? 'mastery';
  const minutes = minutesChoice ?? profile?.dailyMinutes ?? 15;
  const path = roadmap?.courseId === courseId ? roadmap : null;
  const plan = useStudyPlan(course, profile, path, level, goal, minutes);
  const nextFoundation = pendingFoundationLessons(course, profile, level)[0];

  useEffect(() => {
    mounted.current = true;
    return () => { mounted.current = false; };
  }, []);

  useEffect(() => {
    if (courseId) void useRoadmapStore.getState().loadRoadmap(courseId);
  }, [courseId]);

  const submit = async (action: 'learn' | 'diagnostic') => {
    if (!courseId || !level || saving.current) return;
    saving.current = true;
    setPending(action);
    setError('');
    const isCurrent = () => mounted.current && useCourseStore.getState().activeCourse?.id === courseId;
    try {
      await useLearnerStore.getState().saveCourseLearningPlan(courseId, goal, minutes, level, isCurrent);
      if (isCurrent()) onComplete(courseId, level, action === 'diagnostic');
    } catch {
      if (isCurrent()) setError(t('courses.saveFailed'));
    } finally {
      saving.current = false;
      if (isCurrent()) setPending(null);
    }
  };

  const previewStatus = !level ? 'chooseLevel' : plan.unavailable || (!path && roadmapError) ? 'unavailable'
    : plan.loading || !path ? 'loading' : 'empty';

  return (
    <div className="learning-page max-w-296 space-y-5 sm:space-y-7">
      <header className="space-y-2">
        <Button variant="ghost" size="sm" className="-ml-3 text-slatefine" disabled={pending !== null} onClick={onBack} leftIcon={<ArrowLeft aria-hidden="true" className="size-4" />}>{t(editing ? 'courses.back' : 'courses.backSubjects')}</Button>
        {course && <p className="pt-1 text-sm font-bold text-brand-dark">{course.title}</p>}
        <h1 className="heading max-w-3xl text-[clamp(1.85rem,5vw,3.55rem)] font-extrabold leading-[1.05] tracking-[-0.055em]">{t('courses.plan')}</h1>
        <p className="max-w-2xl text-sm leading-relaxed text-slatefine sm:text-base">{t('courses.planDescription')}</p>
      </header>

      {!course ? <SectionState title={t('courses.chooseFirst')} /> : (
        <form className="grid items-start gap-4 lg:grid-cols-[minmax(0,1.03fr)_minmax(0,.97fr)] lg:grid-rows-[auto_1fr] lg:gap-x-6" onSubmit={(event) => { event.preventDefault(); void submit('learn'); }}>
          <div className="min-w-0 space-y-5 rounded-3xl border border-hairline bg-paper p-4 shadow-[var(--surface-shadow)] sm:p-6">
            <fieldset disabled={pending !== null} className="min-w-0 space-y-2.5">
              <legend className="mb-3 text-lg font-extrabold tracking-tight text-ink">{t('courses.startWhere')}</legend>
              {levels.map(({ value, label, description, Icon }) => (
                <label key={value} className="relative block cursor-pointer">
                  <input type="radio" name="learning-level" className="peer absolute inset-0 z-10 size-full cursor-pointer opacity-0" value={value} checked={level === value} onChange={() => setLevel(value)} />
                  <span className="flex min-h-16 items-center gap-3 rounded-2xl border border-hairline bg-paper p-3 text-ink motion-safe:transition-colors hover:bg-sand peer-checked:border-brand peer-checked:bg-brand/8 peer-focus-visible:outline-2 peer-focus-visible:outline-offset-2 peer-focus-visible:outline-brand">
                    <span className="grid size-9 shrink-0 place-items-center rounded-xl bg-sand text-brand-dark"><Icon aria-hidden="true" className="size-4.5" /></span>
                    <span className="min-w-0 flex-1">
                      <span className="block text-sm font-extrabold">{t(label)}</span>
                      <span className="mt-0.5 block text-xs leading-relaxed text-slatefine">{t(description)}</span>
                    </span>
                    <span aria-hidden="true" className={`grid size-5 shrink-0 place-items-center rounded-full border ${level === value ? 'border-brand bg-brand text-paper' : 'border-faint/55'}`}>{level === value && <Check className="size-3" strokeWidth={3} />}</span>
                  </span>
                </label>
              ))}
            </fieldset>

            <fieldset disabled={pending !== null} className="min-w-0 space-y-4 border-t border-hairline pt-4">
              <div>
                <label htmlFor="start-goal" className="mb-1.5 block text-sm font-extrabold text-ink">{t('courses.goal')}</label>
                <select id="start-goal" className="form-input min-h-11 px-3 text-sm" value={goal} onChange={(event) => setGoal(event.target.value as OnboardingGoal)}>
                  {goals.map((option) => <option key={option.value} value={option.value}>{t(option.label)}</option>)}
                </select>
                <p className="mt-1.5 text-xs leading-relaxed text-slatefine">{t(`studyPlan.${goal}`)}</p>
              </div>
              <fieldset className="min-w-0">
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
            </fieldset>
          </div>

          <div className="min-w-0 lg:col-start-2 lg:row-span-2 lg:row-start-1">
            <StudyPlanPreview sessions={plan.sessions} minutes={minutes} status={previewStatus} />
          </div>

          <div className="min-w-0 space-y-3 lg:col-start-1 lg:row-start-2">
            {error && <p role="alert" className="rounded-xl border border-coral/45 bg-coral/10 px-4 py-3 text-sm text-ink">{error}</p>}
            <div className="flex flex-col gap-2.5 sm:flex-row sm:items-center">
              <Button type="submit" disabled={!level || pending === 'diagnostic'} isLoading={pending === 'learn'} leftIcon={<BookOpen aria-hidden="true" className="size-4" />} rightIcon={<ArrowRight aria-hidden="true" className="size-4" />}>
                {t(editing ? 'studyPlan.save' : nextFoundation
                  ? nextFoundation === foundationLessons(course)[0] ? 'courses.firstLesson' : 'courses.continueFoundation'
                  : 'courses.openPath')}
              </Button>
              {level && level !== 'beginner' && <Button type="button" variant="outline" isLoading={pending === 'diagnostic'} disabled={pending === 'learn'} leftIcon={<ClipboardCheck aria-hidden="true" className="size-4" />} onClick={() => void submit('diagnostic')}>{t('courses.optionalDiagnostic')}</Button>}
            </div>
          </div>
        </form>
      )}
    </div>
  );
}
