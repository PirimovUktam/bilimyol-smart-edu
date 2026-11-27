import { useTranslation } from '@/core/locales/useTranslation';
import { useEffect } from 'react';
import { ArrowRight, Check, Compass, Lock, Sparkles, Target, Zap } from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { resolveNextLearningLesson } from '@/app/router/lessonResolution';
import { SkillScoringEngine } from '@/domain/personalization/SkillScoringEngine';
import { AdaptiveCycleEngine } from '@/domain/personalization/AdaptiveCycleEngine';
import { usesMathMastery } from '@/domain/personalization/learningStart';
import { Badge } from '@/presentation/components/Badge';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';
import { CircularProgress } from '@/presentation/components/CircularProgress';
import { PageHeader } from '@/presentation/components/PageHeader';
import { Progress } from '@/presentation/components/Progress';
import { SectionState } from '@/presentation/components/SectionState';

export function KnowledgeMapView({ onProceedToRoadmap, onStartPlacement, onChooseCourse, onStartLesson }: {
  onProceedToRoadmap: () => void;
  onStartPlacement: () => void;
  onChooseCourse: () => void;
  onStartLesson?: (lessonId: string) => void;
}) {
  const { t } = useTranslation();
  const course = useCourseStore((state) => state.activeCourse);
  const skills = useCourseStore((state) => state.activeCourseSkills);
  const profile = useLearnerStore((state) => state.profile);
  const roadmap = useRoadmapStore((state) => state.roadmap);
  const roadmapError = useRoadmapStore((state) => state.error);
  const courseId = course?.id;

  useEffect(() => {
    if (courseId) {
      void useRoadmapStore.getState().loadRoadmap(courseId);
    }
  }, [courseId]);

  const lessonScores = courseId ? profile?.scoresByCourse[courseId] ?? {} : {};
  const placementSkillScores = courseId ? profile?.placementSkillScoresByCourse?.[courseId] ?? {} : {};
  const scores =
    courseId === 'course_eng_01'
      ? { ...placementSkillScores, ...lessonScores }
      : lessonScores;
  const path = roadmap?.courseId === courseId ? roadmap : null;
  const mathPilot = usesMathMastery(courseId);
  const objectives = path?.nodes.filter((node) => node.mastery && !node.isOptional) ?? [];
  const entries = mathPilot ? objectives.map((node) => ({
    id: node.id, name: node.title, description: node.description, node,
    score: node.mastery?.answered ? Math.round(100 * node.mastery.correct / node.mastery.answered) : undefined,
    confidence: undefined,
  })) : skills.map((skill) => {
    const skillObj = scores[skill.id];
    const resolvedConfidence = skillObj
      ? (skillObj.confidence ?? SkillScoringEngine.computeConfidence(skillObj.attemptCount ?? 2))
      : undefined;
    return {
      ...skill,
      node: path?.nodes.find((item) => !item.isReinforcement && item.skillId === skill.id),
      score: skillObj?.score,
      confidence: resolvedConfidence,
    };
  });
  const evaluated = entries.filter((skill) => skill.score != null);
  const hasScores = evaluated.length > 0;
  const overall = mathPilot
    ? (objectives.length
      ? Math.round(100 * objectives.filter((node) => node.status === 'completed').length / objectives.length)
      : 0)
    : SkillScoringEngine.computeOverallScore(scores);
  const diagnosticScores = Object.values(scores);
  const hasDiagnosticScores = diagnosticScores.length > 0;
  const hasPilotAnswers = mathPilot && (path?.nodes ?? []).some((node) => (node.mastery?.answered ?? 0) > 0);
  const isPilotDiagnosticOnlyState = mathPilot && hasDiagnosticScores && !hasPilotAnswers;
  const diagnosticScore = SkillScoringEngine.computeOverallScore(scores);
  const diagnosticGaps = diagnosticScores
    .filter((item) => item.score < 100)
    .sort((a, b) => a.score - b.score || a.skillId.localeCompare(b.skillId));
  const resolveSkillName = (skillId: string) =>
    skills.find((item) => item.id === skillId)?.name
    ?? path?.nodes.find((item) => item.skillId === skillId)?.title
    ?? skillId;
  const nextLessonId = resolveNextLearningLesson(course, profile, path);
  const effectiveness = mathPilot ? null : AdaptiveCycleEngine.measureEffectiveness({
    course,
    profile,
    skills,
    skillScores: scores,
    roadmap: path,
  });
  const weak = entries.filter((skill) => mathPilot
    ? skill.node?.status === 'reinforcement' || skill.node?.mastery?.reviewDue
    : skill.score != null && skill.score < 50);

  return (
    <div className="learning-page space-y-6 sm:space-y-8">
      <PageHeader
        title={t('path.map')}
        highlightWord="xaritasi"
        eyebrow={course?.title ?? t('path.skills')}
        description={t('path.mapDescription')}
        action={
          <Button onClick={onProceedToRoadmap} rightIcon={<ArrowRight aria-hidden="true" className="size-4" />}>{t('path.path')}</Button>
        }
      />
      {!course ? (
        <Card className="space-y-4">
          <SectionState title={t('courses.chooseFirst')} />
          <Button onClick={onChooseCourse}>{t('courses.subjects')}</Button>
        </Card>
      ) : (
        <>
          {!mathPilot || path ? <div className="grid gap-5 lg:grid-cols-2">
            <Card className="fade-up stagger-1 flex items-center gap-4" padding="md">
              {hasScores || isPilotDiagnosticOnlyState ? (
                <CircularProgress value={overall} label={t('path.overallMastery')} />
              ) : (
                <span className="grid size-14 shrink-0 place-items-center rounded-2xl bg-sand text-brand">
                  <Target aria-hidden="true" className="size-7" />
                </span>
              )}
              <div className="min-w-0 space-y-2">
                <span className="highlight">
                  {isPilotDiagnosticOnlyState ? t('path.diagnosticStatus') : t(mathPilot ? 'path.overallMastery' : 'path.diagnosticStatus')}
                </span>
                <h2 className="heading text-lg font-extrabold">
                  {isPilotDiagnosticOnlyState ? t('path.diagnosticResult') : t('path.evaluatedTopics')}
                </h2>
                <p className="text-sm text-slatefine">
                  {isPilotDiagnosticOnlyState
                    ? t('path.diagnosticSummary', { score: diagnosticScore, count: diagnosticScores.length, mastery: overall })
                    : hasScores
                    ? evaluated.length + ' · ' + t('path.evaluatedTopics')
                    : t('path.diagnosticDescription')}
                </p>
                {!hasScores && !isPilotDiagnosticOnlyState && (
                  <Button size="sm" variant="outline" onClick={onStartPlacement}>{t('path.startDiagnostic')}</Button>
                )}
              </div>
            </Card>

            <Card className="fade-up stagger-2 space-y-2.5" padding="md">
              <span className="highlight">{t('path.focus')}</span>
              {isPilotDiagnosticOnlyState ? (
                <>
                  <h2 className="heading flex items-center gap-2 text-lg font-extrabold">
                    <Sparkles aria-hidden="true" className="size-5 text-brand" />{t('lesson.nextStep')}
                  </h2>
                  {diagnosticGaps.length ? (
                    <div className="space-y-3">
                      <p className="text-sm text-slatefine">{t('path.diagnosticGapsIntro')}</p>
                      <ul className="list-disc space-y-1.5 pl-5 text-sm font-medium text-slatefine">
                        {diagnosticGaps.map((item) => (
                          <li key={item.skillId}>
                            {resolveSkillName(item.skillId)} · <span className="font-bold text-coral">{item.score}%</span>
                          </li>
                        ))}
                      </ul>
                      <p className="text-sm text-slatefine">{t('path.diagnosticGapsNextStep')}</p>
                    </div>
                  ) : (
                    <p className="text-sm text-slatefine">{t('path.diagnosticAllCorrectNextStep')}</p>
                  )}
                  <div className="pt-1">
                    <Button
                      size="sm"
                      onClick={() => {
                        if (nextLessonId && onStartLesson) onStartLesson(nextLessonId);
                        else onProceedToRoadmap();
                      }}
                      rightIcon={<ArrowRight aria-hidden="true" className="size-4" />}
                    >
                      {t('path.startFirstExercise')}
                    </Button>
                  </div>
                </>
              ) : (
                <>
                  <h2 className="heading flex items-center gap-2 text-lg font-extrabold">
                    <Sparkles aria-hidden="true" className="size-5 text-brand" />{t('path.reinforce')}{' '}<span className="heading-accent">{t('path.needed')}</span>
                  </h2>
                  {weak.length ? (
                    <div className="space-y-3">
                      <ul className="list-disc space-y-1.5 pl-5 text-sm font-medium text-slatefine">
                        {weak.map((skill) => (
                          <li key={skill.id}>
                            {skill.name} · <span className="font-bold text-coral">
                              {mathPilot ? t(skill.node?.mastery?.reviewDue ? 'path.scheduledReview' : 'path.needsReview') : skill.score + '%'}
                            </span>
                          </li>
                        ))}
                      </ul>
                      <div className="flex flex-wrap items-center justify-between gap-2 rounded-xl border border-coral/25 bg-coral/5 px-3 py-2 text-xs font-semibold text-graphite">
                        <span>{t('adaptive.lessonImpactWrong')}</span>
                        <Button size="sm" variant="outline" onClick={onProceedToRoadmap}>{t('path.path')}</Button>
                      </div>
                    </div>
                  ) : (
                    <p className="text-sm text-slatefine">
                      {hasScores
                        ? t(mathPilot ? 'path.yourPlan' : 'path.noWeak')
                        : t('path.weakAfter')}
                    </p>
                  )}
                </>
              )}
            </Card>
          </div> : roadmapError ? (
            <SectionState kind="error" title={t('path.failed')}
              onRetry={() => void useRoadmapStore.getState().loadRoadmap(course.id)} />
          ) : <SectionState kind="loading" title={t('path.loading')} />}

          {entries.length ? (
            <ol className="grid gap-5 lg:grid-cols-2">
              {entries.map((skill, index) => {
                const { node, score } = skill;
                const isCompleted = node?.status === 'completed';
                const isLocked = node?.status === 'locked';
                const Icon = isLocked ? Lock : isCompleted ? Check : Compass;
                const prerequisites =
                  node?.prerequisites.flatMap((id) => {
                    const item = path?.nodes.find((candidate) => candidate.id === id);
                    return item ? [item.title] : [];
                  }) ?? [];

                return (
                  <li key={skill.id} style={{ animationDelay: `${index * 80}ms` }} className="fade-up">
                    <Card padding="md" className="edtech-card-hover flex h-full flex-col justify-between gap-4">
                      {/* (a) Top: Icon & Status Badge */}
                      <div className="flex items-center justify-between gap-3">
                        <span
                          className={
                            'grid size-11 shrink-0 place-items-center rounded-2xl ' +
                            (isCompleted
                              ? 'bg-emerald-50 text-mint'
                              : isLocked
                              ? 'bg-slate-100 text-slatefine'
                              : 'bg-indigo-50 text-brand')
                          }
                        >
                          <Icon aria-hidden="true" className="size-5" />
                        </span>
                        <Badge
                          variant={isCompleted ? 'emerald' : isLocked ? 'slate' : 'indigo'}
                          size="sm"
                        >
                          {index + 1}{t('path.topicNumber')}{' '}{isCompleted
                            ? ' · ' + t(node.mastery ? 'path.mastered' : 'path.completed')
                            : isLocked
                            ? ' · ' + t('path.locked')
                            : node && node.id === path?.activeNodeId
                            ? ' · ' + t('path.currentTopic')
                            : ''}
                        </Badge>
                      </div>

                      {/* (b) Middle: Title, Description & Progress */}
                      <div className="min-w-0 space-y-2">
                        <div className="flex flex-wrap items-center justify-between gap-2">
                          <h3 className="heading break-words text-lg font-extrabold">{skill.name}</h3>
                          <div className="flex flex-wrap items-center gap-1.5">
                            {!mathPilot && skill.confidence && (
                              <Badge
                                variant={skill.confidence === 'high' ? 'emerald' : skill.confidence === 'medium' ? 'indigo' : 'slate'}
                                size="sm"
                                data-confidence={skill.confidence}
                              >
                                {t(
                                  skill.confidence === 'high'
                                    ? 'path.confidenceHigh'
                                    : skill.confidence === 'medium'
                                      ? 'path.confidenceMedium'
                                      : 'path.confidenceLow'
                                )}
                              </Badge>
                            )}
                            {effectiveness && score != null && (() => {
                              const delta = effectiveness.skillDeltas.find((d) => d.skillId === skill.id);
                              if (!delta) return null;
                              const gapLabel = delta.status === 'gap_detected'
                                ? t('adaptive.gapStatusDetected')
                                : delta.status === 'closed_gap'
                                ? t('adaptive.gapStatusClosed')
                                : delta.status === 'mastered'
                                ? t('adaptive.gapStatusMastered')
                                : t('adaptive.gapStatusReinforcing');
                              const variant = delta.status === 'gap_detected'
                                ? 'rose'
                                : delta.status === 'closed_gap' || delta.status === 'mastered'
                                ? 'emerald'
                                : 'amber';
                              return <Badge variant={variant} size="sm">{gapLabel}</Badge>;
                            })()}
                          </div>
                        </div>
                        <p className="line-clamp-2 text-sm text-slatefine">{skill.description}</p>
                        <div className="space-y-1.5 pt-2">
                          {mathPilot && node?.mastery && !isLocked && (
                            <p className="text-xs font-semibold text-slatefine">
                              {node.mastery.answered}/{node.mastery.requiredItems}
                              {node.mastery.answered > 0
                                ? ` · ${node.mastery.correct}/${node.mastery.requiredItems} ${t('path.masteryEvidence')}`
                                : ''}
                            </p>
                          )}
                          {score == null ? (
                            <p className="text-xs font-bold text-slatefine">{t('path.unassessed')}</p>
                          ) : (
                            <Progress
                              value={score}
                              ariaLabel={t(mathPilot ? 'path.assessmentAccuracy' : 'courses.mastery')}
                              showLabel
                              tone={score < 50 ? 'amber' : 'emerald'}
                            />
                          )}
                        </div>
                      </div>

                      {/* (c) Bottom: Meta Footer */}
                      <div className="mt-auto flex flex-wrap items-center justify-between gap-2 border-t border-slate-100 pt-3 text-xs font-bold text-slatefine">
                        <span>
                          {prerequisites.length > 0
                            ? t('path.related') + prerequisites.join(', ')
                            : t('path.independent')}
                        </span>
                        <span className="inline-flex items-center gap-1 text-brand">
                          <Zap aria-hidden="true" className="size-3.5" />{t('path.skillNumber')}{' '}{index + 1}
                        </span>
                      </div>
                    </Card>
                  </li>
                );
              })}
            </ol>
          ) : (!mathPilot || path) && (
            <SectionState title={t('path.noSkills')} />
          )}
        </>
      )}
    </div>
  );
}
