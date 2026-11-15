import { useTranslation } from '@/core/locales/useTranslation';
import { useEffect } from 'react';
import { ArrowRight, Check, Compass, Lock, Sparkles, Target, Zap } from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { SkillScoringEngine } from '@/domain/personalization/SkillScoringEngine';
import { Badge } from '@/presentation/components/Badge';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';
import { CircularProgress } from '@/presentation/components/CircularProgress';
import { PageHeader } from '@/presentation/components/PageHeader';
import { Progress } from '@/presentation/components/Progress';
import { SectionState } from '@/presentation/components/SectionState';

export function KnowledgeMapView({ onProceedToRoadmap, onStartPlacement, onChooseCourse }: {
  onProceedToRoadmap: () => void; onStartPlacement: () => void; onChooseCourse: () => void;
}) {
  const { t } = useTranslation();
  const course = useCourseStore((state) => state.activeCourse);
  const skills = useCourseStore((state) => state.activeCourseSkills);
  const profile = useLearnerStore((state) => state.profile);
  const roadmap = useRoadmapStore((state) => state.roadmap);
  const courseId = course?.id;

  useEffect(() => {
    if (courseId && useRoadmapStore.getState().roadmap?.courseId !== courseId) {
      void useRoadmapStore.getState().loadRoadmap(courseId);
    }
  }, [courseId]);

  const scores = courseId ? profile?.scoresByCourse[courseId] ?? {} : {};
  const hasScores = Object.keys(scores).length > 0;
  const overall = SkillScoringEngine.computeOverallScore(scores);
  const path = roadmap?.courseId === courseId ? roadmap : null;
  const weak = skills.filter((skill) => scores[skill.id] && scores[skill.id].score < 50);

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
          <div className="grid gap-5 lg:grid-cols-2">
            <Card className="fade-up stagger-1 flex items-center gap-4" padding="md">
              {hasScores ? (
                <CircularProgress value={overall} label={t('path.overallMastery')} />
              ) : (
                <span className="grid size-14 shrink-0 place-items-center rounded-2xl bg-sand text-brand">
                  <Target aria-hidden="true" className="size-7" />
                </span>
              )}
              <div className="space-y-2">
                <span className="highlight">{t('path.diagnosticStatus')}</span>
                <h2 className="heading text-lg font-extrabold">{t('path.evaluatedTopics')}</h2>
                <p className="text-sm text-slatefine">
                  {hasScores
                    ? Object.keys(scores).length + ' mavzu bo‘yicha natija mavjud.'
                    : t('path.diagnosticDescription')}
                </p>
                {!hasScores && (
                  <Button size="sm" variant="outline" onClick={onStartPlacement}>{t('path.startDiagnostic')}</Button>
                )}
              </div>
            </Card>

            <Card className="fade-up stagger-2 space-y-2.5" padding="md">
              <span className="highlight">{t('path.focus')}</span>
              <h2 className="heading flex items-center gap-2 text-lg font-extrabold">
                <Sparkles aria-hidden="true" className="size-5 text-brand" />{t('path.reinforce')}{' '}<span className="heading-accent">{t('path.needed')}</span>
              </h2>
              {weak.length ? (
                <ul className="list-disc space-y-1.5 pl-5 text-sm font-medium text-slatefine">
                  {weak.map((skill) => (
                    <li key={skill.id}>
                      {skill.name} · <span className="font-bold text-coral">{scores[skill.id].score}%</span>
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="text-sm text-slatefine">
                  {hasScores
                    ? t('path.noWeak')
                    : t('path.weakAfter')}
                </p>
              )}
            </Card>
          </div>

          {skills.length ? (
            <ol className="grid gap-5 lg:grid-cols-2">
              {skills.map((skill, index) => {
                const node = path?.nodes.find((item) => !item.isReinforcement && item.skillId === skill.id);
                const score = scores[skill.id]?.score;
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
                            ? ' · Yakunlangan'
                            : isLocked
                            ? ' · Qulflangan'
                            : node && node.id === path?.activeNodeId
                            ? ' · Joriy mavzu'
                            : ''}
                        </Badge>
                      </div>

                      {/* (b) Middle: Title, Description & Progress */}
                      <div className="min-w-0 space-y-2">
                        <h3 className="heading break-words text-lg font-extrabold">{skill.name}</h3>
                        <p className="line-clamp-2 text-sm text-slatefine">{skill.description}</p>
                        <div className="pt-2">
                          {score == null ? (
                            <p className="text-xs font-bold text-slatefine">{t('path.unassessed')}</p>
                          ) : (
                            <Progress
                              value={score}
                              ariaLabel={t('courses.mastery')}
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
          ) : (
            <SectionState title={t('path.noSkills')} />
          )}
        </>
      )}
    </div>
  );
}
