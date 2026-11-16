import { useTranslation } from '@/core/locales/useTranslation';
import { useEffect, useState } from 'react';
import { ArrowRight, BookOpenCheck, ChartNoAxesCombined, CheckCircle2, Clock, Flame, RefreshCw, Sparkles, Target, TrendingUp, Trophy, XCircle, Zap, type LucideIcon } from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { AdaptiveCycleEngine } from '@/domain/personalization/AdaptiveCycleEngine';
import { usesMathMastery } from '@/domain/personalization/learningStart';
import { SkillScoringEngine } from '@/domain/personalization/SkillScoringEngine';
import type { DailyActivitySummary } from '@/domain/repositories/ILearnerRepository';
import { supabaseLearnerRepository } from '@/data/repositories/SupabaseLearnerRepository';
import { Badge } from '@/presentation/components/Badge';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';
import { PageHeader } from '@/presentation/components/PageHeader';
import { Progress } from '@/presentation/components/Progress';
import { SectionState } from '@/presentation/components/SectionState';
import { WeeklyActivity } from '@/presentation/components/WeeklyActivity';

interface ProgressViewProps {
  onContinueLesson: () => void;
  onOpenRoadmap: () => void;
  onOpenKnowledgeMap: () => void;
}

export function ProgressView({ onContinueLesson, onOpenRoadmap, onOpenKnowledgeMap }: ProgressViewProps) {
  const { t } = useTranslation();
  const activeCourse = useCourseStore((state) => state.activeCourse);
  const courses = useCourseStore((state) => state.courses);
  const skills = useCourseStore((state) => state.activeCourseSkills);
  const profile = useLearnerStore((state) => state.profile);
  const roadmap = useRoadmapStore((state) => state.roadmap);
  const [period, setPeriod] = useState<7 | 30>(7);
  const [activity, setActivity] = useState<DailyActivitySummary[] | null>(null);
  const [failed, setFailed] = useState(false);
  const [retry, setRetry] = useState(0);

  useEffect(() => {
    let active = true;
    setActivity(null);
    setFailed(false);
    void supabaseLearnerRepository.getDailyActivity(period).then(
      (days) => { if (active) setActivity(days); },
      () => { if (active) setFailed(true); },
    );
    return () => { active = false; };
  }, [period, retry]);

  const totals = activity?.reduce((total, day) => ({
    questions: total.questions + (day.questionsAnswered ?? 0),
    correct: total.correct + (day.correctAnswers ?? 0),
    minutes: total.minutes + day.activeMinutes,
  }), { questions: 0, correct: 0, minutes: 0 });
  const accuracy = totals && totals.questions > 0 ? Math.round(100 * totals.correct / totals.questions) : null;
  const scores = activeCourse ? profile?.scoresByCourse[activeCourse.id] ?? {} : {};
  const path = roadmap?.courseId === activeCourse?.id ? roadmap : null;
  const courseId = activeCourse?.id;
  const mathPilot = usesMathMastery(courseId);
  useEffect(() => {
    if (mathPilot && courseId) void useRoadmapStore.getState().loadRoadmap(courseId);
  }, [courseId, mathPilot]);
  const effectiveness = mathPilot ? null : AdaptiveCycleEngine.measureEffectiveness({
    course: activeCourse,
    profile,
    skills,
    skillScores: scores,
    roadmap: path,
  });
  const completed = new Set(profile?.completedLessonIds);
  const evaluated = (mathPilot ? path?.nodes.flatMap((node) =>
    node.mastery?.answered && !node.isOptional ? [{
      id: node.id, name: node.title, score: Math.round(100 * node.mastery.correct / node.mastery.answered),
    }] : []) ?? [] : skills.flatMap((skill) =>
    scores[skill.id] ? [{ ...skill, score: scores[skill.id].score }] : [])).sort((a, b) => b.score - a.score);
  const achievements = [
    { title: t('progress.firstStep'), description: t('progress.firstLesson'), earned: completed.size >= 1 },
    { title: t('progress.regular'), description: t('progress.sevenDays'), earned: (profile?.streakDays ?? 0) >= 7 },
    { title: t('progress.fiveMilestones'), description: t('progress.fiveLessons'), earned: completed.size >= 5 },
  ];

  return (
    <div className="learning-page space-y-6 sm:space-y-8">
      <PageHeader
        title={t('progress.title')}
        highlightWord={t('progress.highlight')}
        eyebrow={t('progress.resultsTitle')}
        description={t('progress.description')}
        action={
          <Button onClick={onContinueLesson} rightIcon={<ArrowRight aria-hidden="true" className="size-4" />}>{t('progress.backLesson')}</Button>
        }
      />

      <div className="grid grid-cols-2 gap-4 xl:grid-cols-4">
        <Stat icon={Clock} tone="bg-indigo-50 text-brand" label={t('progress.studyTime')} value={totals ? t('dynamic.minutes', { count: totals.minutes }) : '—'} index={0} />
        <Stat icon={BookOpenCheck} tone="bg-emerald-50 text-mint" label={t('progress.completedLessons')} value={String(completed.size)} index={1} />
        <Stat icon={Flame} tone="bg-amber-50 text-amber-600" label={t('progress.streak')} value={t('dynamic.days', { count: profile?.streakDays ?? 0 })} index={2} />
        <Stat icon={Zap} tone="bg-sky-50 text-path" label={t('progress.xp')} value={String(profile?.xp ?? 0)} index={3} />
      </div>

      {/* ADAPTIVE CYCLE EFFECTIVENESS & COMPETITIVE ADVANTAGE */}
      {effectiveness && <section aria-labelledby="adaptive-effectiveness-heading" className="grid gap-5 lg:grid-cols-12">
        <Card className="fade-up stagger-2 space-y-5 lg:col-span-7" padding="md">
          <div className="flex flex-wrap items-start justify-between gap-2">
            <div className="space-y-1">
              <span className="highlight">
                <RefreshCw aria-hidden="true" className="size-3.5 text-path" />
                {t('adaptive.effectivenessEyebrow')}
              </span>
              <h2 id="adaptive-effectiveness-heading" className="heading text-xl font-extrabold">
                {t('adaptive.effectivenessTitle')}
              </h2>
              <p className="text-xs leading-relaxed text-slatefine sm:text-sm">
                {t('adaptive.effectivenessDesc')}
              </p>
            </div>
            <Badge variant="emerald" size="md">
              +{effectiveness.growthDelta}%
            </Badge>
          </div>

          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
            <div className="rounded-2xl border border-hairline bg-canvas/60 p-3">
              <p className="text-[11px] font-bold text-slatefine">{t('adaptive.baselineScore')} → {t('adaptive.currentScore')}</p>
              <p className="mt-1 font-mono text-base font-extrabold text-ink">
                {effectiveness.baselineScore}% → {effectiveness.currentScore}%
              </p>
            </div>
            <div className="rounded-2xl border border-hairline bg-canvas/60 p-3">
              <p className="text-[11px] font-bold text-slatefine">{t('adaptive.gapsClosed')}</p>
              <p className="mt-1 font-mono text-base font-extrabold text-mint">
                {effectiveness.closedGapsCount} / {effectiveness.detectedGapsCount}
              </p>
            </div>
            <div className="rounded-2xl border border-hairline bg-canvas/60 p-3">
              <p className="text-[11px] font-bold text-slatefine">{t('adaptive.cycleUpdates')}</p>
              <p className="mt-1 font-mono text-base font-extrabold text-brand">
                {effectiveness.adaptiveUpdatesCount}
              </p>
            </div>
            <div className="rounded-2xl border border-hairline bg-canvas/60 p-3">
              <p className="text-[11px] font-bold text-slatefine">{t('adaptive.paceEfficiency')}</p>
              <p className="mt-1 font-mono text-base font-extrabold text-path">
                {effectiveness.paceEfficiencyPct}%
              </p>
            </div>
          </div>

          {effectiveness.skillDeltas.length > 0 && (
            <ul className="space-y-2.5">
              {effectiveness.skillDeltas.slice(0, 4).map((item) => {
                const statusLabel = item.status === 'closed_gap'
                  ? t('adaptive.gapStatusClosed')
                  : item.status === 'gap_detected'
                  ? t('adaptive.gapStatusDetected')
                  : item.status === 'mastered'
                  ? t('adaptive.gapStatusMastered')
                  : item.status === 'unassessed'
                  ? t('adaptive.gapStatusUnassessed')
                  : t('adaptive.gapStatusReinforcing');
                const variant = item.status === 'closed_gap' || item.status === 'mastered'
                  ? 'emerald'
                  : item.status === 'gap_detected'
                  ? 'rose'
                  : item.status === 'unassessed'
                  ? 'slate'
                  : 'amber';
                return (
                  <li key={item.skillId} className="space-y-1.5 rounded-2xl border border-hairline bg-canvas/50 p-3">
                    <div className="flex flex-wrap items-center justify-between gap-2 text-xs">
                      <span className="font-extrabold text-ink">{item.skillName}</span>
                      <div className="flex items-center gap-2">
                        {item.delta > 0 && (
                          <span className="inline-flex items-center gap-0.5 font-mono font-bold text-mint">
                            <TrendingUp aria-hidden="true" className="size-3" />+{item.delta}%
                          </span>
                        )}
                        <Badge variant={variant} size="sm">{statusLabel}</Badge>
                      </div>
                    </div>
                    <Progress
                      value={item.current}
                      size="sm"
                      ariaLabel={`${item.skillName} ${item.current}%`}
                      tone={item.current >= 70 ? 'emerald' : item.current < 50 ? 'amber' : 'indigo'}
                    />
                  </li>
                );
              })}
            </ul>
          )}
        </Card>

        <Card className="fade-up stagger-3 flex flex-col justify-between space-y-4 lg:col-span-5" padding="md">
          <div className="space-y-1">
            <span className="highlight">
              <Sparkles aria-hidden="true" className="size-3.5 text-brand" />
              {t('adaptive.bilimyolLabel')}
            </span>
            <h2 className="heading text-lg font-extrabold">{t('adaptive.advantageTitle')}</h2>
          </div>

          <ul className="space-y-2.5">
            {[
              { trad: t('adaptive.advPlanTraditional'), smart: t('adaptive.advPlanBilimyol') },
              { trad: t('adaptive.advDynamicTraditional'), smart: t('adaptive.advDynamicBilimyol') },
              { trad: t('adaptive.advXaiTraditional'), smart: t('adaptive.advXaiBilimyol') },
              { trad: t('adaptive.advMeasureTraditional'), smart: t('adaptive.advMeasureBilimyol') },
            ].map((row) => (
              <li key={row.smart} className="rounded-2xl border border-hairline bg-canvas/60 p-3 text-xs space-y-1.5">
                <p className="flex items-start gap-2 text-slatefine">
                  <XCircle aria-hidden="true" className="mt-0.5 size-3.5 shrink-0 text-coral" />
                  <span><strong className="font-bold">{t('adaptive.traditionalLabel')}:</strong> {row.trad}</span>
                </p>
                <p className="flex items-start gap-2 font-semibold text-ink">
                  <CheckCircle2 aria-hidden="true" className="mt-0.5 size-3.5 shrink-0 text-mint" />
                  <span><strong className="font-bold text-mint">{t('adaptive.bilimyolLabel')}:</strong> {row.smart}</span>
                </p>
              </li>
            ))}
          </ul>
        </Card>
      </section>}

      <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_minmax(16rem,21rem)]">
        <Card className="fade-up stagger-2 min-w-0 space-y-4" padding="md">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <span className="highlight mb-1.5">{t('progress.statistics')}</span>
              <h2 className="heading flex items-center gap-2 text-xl font-extrabold">
                <ChartNoAxesCombined aria-hidden="true" className="size-5 text-brand" />{t('progress.study')}{' '}<span className="heading-accent">{t('progress.activity')}</span>
              </h2>
            </div>
            <div role="group" aria-label={t('progress.period')} className="flex gap-1 rounded-xl bg-sand p-1">
              {([7, 30] as const).map((days) => (
                <Button
                  key={days}
                  size="sm"
                  variant={period === days ? 'primary' : 'ghost'}
                  aria-pressed={period === days}
                  onClick={() => setPeriod(days)}
                >
                  {days}{' '}{t('courses.day')}</Button>
              ))}
            </div>
          </div>
          {failed ? (
            <SectionState kind="error" title={t('progress.activityFailed')} onRetry={() => setRetry((n) => n + 1)} />
          ) : activity ? (
            <WeeklyActivity days={activity} />
          ) : (
            <SectionState kind="loading" title={t('progress.activityLoading')} />
          )}
        </Card>

        <Card className="fade-up stagger-3 flex flex-col justify-between space-y-4" padding="md">
          <div className="space-y-2">
            <span className="highlight">{t('progress.accuracy')}</span>
            <h2 className="heading flex items-center gap-2 text-xl font-extrabold">
              <Target aria-hidden="true" className="size-5 text-brand" />{t('progress.exercises')}{' '}<span className="heading-accent">{t('progress.result')}</span>
            </h2>
          </div>
          {accuracy == null ? (
            <p className="text-sm leading-relaxed text-slatefine">
              {totals ? t('progress.noAttempts') : 'Hisoblanmoqda…'}
            </p>
          ) : (
            <div className="space-y-3">
              <p className="heading text-4xl font-extrabold text-ink">{accuracy}%</p>
              <Progress value={accuracy} ariaLabel={t('progress.accuracyDescription')} tone="emerald" />
              <p className="text-sm font-medium text-slatefine">
                {totals?.questions}{' '}{t('progress.outOf')}{' '}{totals?.correct}{' '}{t('progress.correct')}</p>
            </div>
          )}
        </Card>
      </div>

      <div className="grid gap-5 lg:grid-cols-2">
        <Card className="fade-up stagger-3 space-y-4" padding="md">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <span className="highlight mb-1">{t('progress.catalog')}</span>
              <h2 className="heading text-xl font-extrabold">{t('progress.bySubject')}{' '}<span className="heading-accent">{t('progress.results')}</span>
              </h2>
            </div>
            <Button size="sm" variant="ghost" onClick={onOpenRoadmap}>{t('path.path')}</Button>
          </div>
          {courses.length ? (
            <ul className="space-y-3">
              {courses.map((course) => {
                const subjectScores = profile?.scoresByCourse[course.id] ?? {};
                const scored = Object.keys(subjectScores).length > 0;
                const lessonCount = course.lessons.filter((id) => completed.has(id)).length;
                return (
                  <li key={course.id} className="space-y-2.5 rounded-2xl border border-hairline bg-canvas/70 p-4">
                    <div className="flex flex-wrap justify-between gap-2 text-sm">
                      <strong className="heading font-extrabold">{course.title}</strong>
                      {course.lessons.length > 0 && (
                        <Badge variant="indigo" size="sm">
                          {lessonCount} / {course.lessons.length}{t('courses.lesson')}</Badge>
                      )}
                    </div>
                    {scored ? (
                      <Progress
                        value={SkillScoringEngine.computeOverallScore(subjectScores)}
                        size="sm"
                        ariaLabel={t('path.evaluatedTopics')}
                        showLabel
                      />
                    ) : (
                      <p className="text-xs font-medium text-slatefine">{t('progress.notAssessed')}</p>
                    )}
                  </li>
                );
              })}
            </ul>
          ) : (
            <p className="text-sm text-slatefine">{t('progress.noResults')}</p>
          )}
        </Card>

        <Card className="fade-up stagger-4 space-y-4" padding="md">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <span className="highlight mb-1">{t('path.skills')}</span>
              <h2 className="heading text-xl font-extrabold">{t('progress.topics')}{' '}<span className="heading-accent">{t('progress.analysis')}</span>
              </h2>
            </div>
            <Button size="sm" variant="ghost" onClick={onOpenKnowledgeMap}>{t('path.map')}</Button>
          </div>
          {evaluated.length ? (
            <ul className="space-y-3.5">
              {evaluated.map((skill) => (
                <li key={skill.id} className="rounded-2xl border border-hairline bg-canvas/50 p-3.5">
                  {mathPilot && <p className="mb-2 text-sm font-semibold">{skill.name} · {t('path.assessmentAccuracy')}</p>}
                  <Progress
                    value={skill.score}
                    ariaLabel={skill.name}
                    showLabel
                    tone={skill.score >= 80 ? 'emerald' : skill.score < 50 ? 'amber' : 'indigo'}
                  />
                </li>
              ))}
            </ul>
          ) : (
            <p className="text-sm text-slatefine">{t('progress.assessmentDescription')}</p>
          )}
        </Card>
      </div>

      <section aria-labelledby="achievements-title" className="fade-up stagger-5 space-y-4">
        <div>
          <span className="highlight mb-1.5">
            <Sparkles aria-hidden="true" className="size-3.5" />{t('progress.rewards')}</span>
          <h2 id="achievements-title" className="heading text-xl font-extrabold">{t('progress.achievements')}</h2>
        </div>
        <div className="grid gap-4 sm:grid-cols-3">
          {achievements.map(({ title, description, earned }) => (
            <Card key={title} className="edtech-card-hover flex flex-col justify-between space-y-3" padding="md">
              <div className="flex items-center justify-between">
                <span
                  className={
                    'grid size-11 place-items-center rounded-2xl ' +
                    (earned ? 'bg-amber-50 text-amber-600' : 'bg-slate-100 text-faint')
                  }
                >
                  <Trophy aria-hidden="true" className="size-5" />
                </span>
                <Badge variant={earned ? 'emerald' : 'slate'} size="sm">
                  {earned ? 'Erishildi' : t('progress.locked')}
                </Badge>
              </div>
              <div>
                <h3 className="heading font-extrabold">{title}</h3>
                <p className="mt-1 text-xs text-slatefine">
                  {description} · {earned ? 'Erishildi' : t('progress.locked')}
                </p>
              </div>
            </Card>
          ))}
        </div>
      </section>
    </div>
  );
}

function Stat({ icon: Icon, tone, value, label, index }: { icon: LucideIcon; tone: string; value: string; label: string; index: number }) {
  return (
    <Card
      padding="sm"
      style={{ animationDelay: `${index * 70}ms` }}
      className="fade-up edtech-card-hover min-w-0 space-y-3"
    >
      <span className={`grid size-11 place-items-center rounded-2xl ${tone}`}>
        <Icon aria-hidden="true" className="size-5" />
      </span>
      <div>
        <p className="heading text-xl font-extrabold sm:text-2xl">{value}</p>
        <p className="mt-0.5 text-xs font-bold text-slatefine">{label}</p>
      </div>
    </Card>
  );
}
