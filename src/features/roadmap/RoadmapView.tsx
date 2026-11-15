import { translate as t } from '@/core/locales/useTranslation';
import { useTranslation } from '@/core/locales/useTranslation';
import { useEffect, useState } from 'react';
import { ArrowRight, BookOpen, Check, Clock, Compass, Lock, Play, Sparkles, Zap } from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { resolveNextLearningLesson, resolveRoadmapNodeLessonId } from '@/app/router/lessonResolution';
import { supabaseLessonRepository } from '@/data/repositories/SupabaseLessonRepository';
import type { LearningPathNode } from '@/domain/entities/LearningPathNode';
import type { Question } from '@/domain/entities/Question';
import { foundationLessons, hasStartedCourse, pendingFoundationLesson } from '@/domain/personalization/learningStart';
import { ReinforcementModal } from '@/features/reinforcement/ReinforcementModal';
import { Badge } from '@/presentation/components/Badge';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';
import { PageHeader } from '@/presentation/components/PageHeader';
import { Progress } from '@/presentation/components/Progress';
import { SectionState } from '@/presentation/components/SectionState';

const filters = { get all() { return t('courses.all'); }, get active() { return t('path.openStages'); }, get completed() { return t('path.completed'); } } as const;

interface RoadmapViewProps {
  onStartLesson: (lessonId: string) => void;
  onOpenKnowledgeMap: () => void;
  onChooseCourse: () => void;
  onConfigure: () => void;
}

export function RoadmapView({ onStartLesson, onOpenKnowledgeMap, onChooseCourse, onConfigure }: RoadmapViewProps) {
  const { t } = useTranslation();
  const course = useCourseStore((state) => state.activeCourse);
  const profile = useLearnerStore((state) => state.profile);
  const roadmap = useRoadmapStore((state) => state.roadmap);
  const error = useRoadmapStore((state) => state.error);
  const [filter, setFilter] = useState<keyof typeof filters>('all');
  const [practice, setPractice] = useState<Question | null>(null);
  const [practiceLoading, setPracticeLoading] = useState<string | null>(null);
  const [practiceError, setPracticeError] = useState('');
  const courseId = course?.id;

  useEffect(() => {
    if (courseId) void useRoadmapStore.getState().loadRoadmap(courseId);
  }, [courseId]);

  const path = roadmap?.courseId === courseId ? roadmap : null;
  const nodes = path?.nodes ?? [];
  const topics = nodes.filter((node) => !node.isReinforcement);
  const completed = topics.filter((node) => node.status === 'completed').length;
  const lesson = resolveNextLearningLesson(course, profile, path);
  const foundation = pendingFoundationLesson(course, profile);
  const foundationPath = course ? foundationLessons(course) : [];
  const ready = Boolean(course && hasStartedCourse(course, profile));
  const foundationCompleted = foundationPath.filter((id) => profile?.completedLessonIds.includes(id)).length;
  const shown = nodes.filter((node) => filter === 'all' || (filter === 'active'
    ? node.status !== 'locked' && node.status !== 'completed' : node.status === 'completed'));

  const loadPractice = async (node: LearningPathNode) => {
    setPracticeLoading(node.id);
    setPracticeError('');
    try {
      const baseNode = topics.find((topic) => topic.skillId === node.skillId);
      const linked = baseNode?.targetLessonId
        ? await supabaseLessonRepository.getLessonById(baseNode.targetLessonId)
        : await supabaseLessonRepository.getLessonByCourseAndSkill(node.courseId, node.skillId);
      if (!linked || linked.courseId !== node.courseId || linked.skillId !== node.skillId) {
        throw new Error(t('path.noExercise'));
      }
      setPractice(linked.reinforcementExercise);
    } catch {
      setPracticeError(t('path.exerciseFailed'));
    } finally {
      setPracticeLoading(null);
    }
  };

  return (
    <div className="learning-page space-y-6 sm:space-y-8">
      <PageHeader
        eyebrow={course?.title ?? t('path.curriculum')}
        title={t('path.title')}
        highlightWord={t('path.highlight')}
        description={t('path.description')}
        action={
          ready && (
            <Button
              variant="outline"
              leftIcon={<Compass aria-hidden="true" className="size-4 text-brand" />}
              onClick={onOpenKnowledgeMap}
            >{t('path.map')}</Button>
          )
        }
      />

      {!course ? (
        <Card className="space-y-4">
          <SectionState title={t('courses.chooseFirst')} />
          <Button onClick={onChooseCourse}>{t('courses.subjects')}</Button>
        </Card>
      ) : !ready ? (
        <Card className="space-y-4">
          <span className="highlight">{t('path.setup')}</span>
          <h2 className="heading text-xl font-extrabold">{t('path.where')}</h2>
          <p className="text-sm text-slatefine">{t('path.levelDescription')}</p>
          <Button onClick={onConfigure}>{t('path.start')}</Button>
        </Card>
      ) : foundation ? (
        <div className="grid items-start gap-6 lg:grid-cols-[minmax(0,1fr)_18rem]">
          <section className="min-w-0 space-y-4" aria-labelledby="foundation-title">
            <div>
              <span className="highlight mb-2">{t('path.foundation')}</span>
              <h2 id="foundation-title" className="heading text-2xl font-extrabold">{t('courses.beginner')}{' '}<span className="heading-accent">{t('path.lessons')}</span>
              </h2>
            </div>
            <ol className="learning-timeline">
              {foundationPath.map((id, index) => {
                const done = profile?.completedLessonIds.includes(id) ?? false;
                const current = id === foundation;
                return (
                  <li key={id} aria-current={current ? 'step' : undefined} style={{ animationDelay: `${index * 80}ms` }} className="fade-up">
                    <span className={'timeline-marker ' + (current ? 'timeline-current' : done ? 'bg-emerald-500! text-white! border-emerald-500!' : '')}>
                      {done ? <Check aria-hidden="true" className="size-4" /> : index + 1}
                    </span>
                    <Card
                      className={'edtech-card-hover flex min-w-0 flex-wrap items-center justify-between gap-4 ' + (current ? 'ring-2 ring-brand/30 border-brand!' : '')}
                      padding="sm"
                    >
                      <div className="space-y-1">
                        <Badge variant={done ? 'emerald' : current ? 'indigo' : 'slate'} size="sm">
                          {done ? 'Tugallangan' : current ? t('path.nextLesson') : t('path.nextStage')}
                        </Badge>
                        <h3 className="heading text-base font-extrabold">{index + 1}{t('path.foundationNumber')}</h3>
                      </div>
                      {(current || done) && (
                        <Button variant={current ? 'primary' : 'outline'} size="sm" onClick={() => onStartLesson(id)}>
                          {current ? t('path.openFoundation') : t('path.review')}
                        </Button>
                      )}
                    </Card>
                  </li>
                );
              })}
            </ol>
          </section>
          <Card className="fade-up stagger-2 space-y-3" padding="md">
            <span className="highlight">{t('path.progress')}</span>
            <h2 className="heading text-lg font-extrabold">{t('path.result')}</h2>
            <p className="text-sm text-slatefine">
              {foundationCompleted} / {foundationPath.length}{t('path.lessonsDone')}</p>
            <Progress value={(100 * foundationCompleted) / foundationPath.length} tone="emerald" ariaLabel={t('path.foundationProgress')} />
          </Card>
        </div>
      ) : error && !path ? (
        <SectionState
          kind="error"
          title={t('path.failed')}
          description={error}
          onRetry={() => void useRoadmapStore.getState().loadRoadmap(course.id)}
        />
      ) : !path ? (
        <SectionState kind="loading" title={t('path.loading')} />
      ) : (
        <>
          <section className="learning-hero fade-up stagger-1 grid items-center gap-5 rounded-3xl p-6 sm:grid-cols-[minmax(0,1fr)_auto] sm:p-8">
            <div className="min-w-0 space-y-2.5">
              <span className="inline-flex items-center gap-1.5 rounded-full bg-white/15 px-3 py-1 text-xs font-bold text-indigo-100">
                <Sparkles aria-hidden="true" className="size-3.5 text-sky-300" />{t('path.yourPlan')}</span>
              <h2 className="font-display text-2xl font-extrabold sm:text-3xl">
                {completed} / {topics.length}{t('path.topicsDone')}</h2>
              {topics.length > 0 && (
                <Progress
                  value={(100 * completed) / topics.length}
                  tone="cyan"
                  size="sm"
                  className="max-w-sm"
                  ariaLabel={t('path.stageProgress')}
                />
              )}
            </div>
            {lesson && (
              <Button
                variant="outline"
                className="w-fit border-white bg-white text-brand hover:bg-indigo-50"
                onClick={() => onStartLesson(lesson)}
                rightIcon={<ArrowRight aria-hidden="true" className="size-4" />}
              >{t('courses.continue')}</Button>
            )}
          </section>

          <div role="group" aria-label={t('path.filter')} className="fade-up stagger-2 flex flex-wrap gap-2">
            {(Object.keys(filters) as (keyof typeof filters)[]).map((key) => (
              <Button
                key={key}
                variant={filter === key ? 'primary' : 'outline'}
                aria-pressed={filter === key}
                size="sm"
                onClick={() => setFilter(key)}
              >
                {filters[key]}
              </Button>
            ))}
          </div>

          {practiceError && (
            <p role="alert" className="rounded-2xl border border-coral/20 bg-rose-50 p-3.5 text-sm text-coral">
              {practiceError}
            </p>
          )}
          {shown.length === 0 && (
            <SectionState title={nodes.length ? t('path.emptyFilter') : t('path.empty')} />
          )}

          <ol className="learning-timeline">
            {shown.map((node, index) => {
              const locked = node.status === 'locked';
              const done = node.status === 'completed';
              const isActive = node.id === path.activeNodeId;
              const target = resolveRoadmapNodeLessonId(node);
              const Icon = locked ? Lock : done ? Check : node.isReinforcement ? Sparkles : BookOpen;
              const prerequisites = node.prerequisites.flatMap((id) => {
                const previous = nodes.find((item) => item.id === id);
                return previous ? [previous.title] : [];
              });

              const iconBoxTone = done
                ? 'bg-emerald-50 text-mint'
                : locked
                ? 'bg-slate-100 text-slatefine'
                : node.isReinforcement
                ? 'bg-amber-50 text-amber-600'
                : 'bg-indigo-50 text-brand';

              return (
                <li
                  key={node.id}
                  aria-current={isActive ? 'step' : undefined}
                  style={{ animationDelay: `${index * 80}ms` }}
                  className="fade-up"
                >
                  <span
                    className={
                      'timeline-marker ' +
                      (isActive
                        ? 'timeline-current'
                        : done
                        ? 'bg-emerald-500! text-white! border-emerald-500!'
                        : '')
                    }
                  >
                    <Icon aria-hidden="true" className="size-4" />
                  </span>
                  <Card
                    className={
                      'edtech-card-hover flex min-w-0 flex-col justify-between gap-4 ' +
                      (isActive ? 'ring-2 ring-brand/30 border-brand!' : '')
                    }
                    padding="md"
                  >
                    {/* (a) Top: Icon Container + Status Badge */}
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <div className="flex items-center gap-2.5">
                        <span className={`grid size-10 shrink-0 place-items-center rounded-xl ${iconBoxTone}`}>
                          <Icon aria-hidden="true" className="size-5" />
                        </span>
                        <Badge
                          variant={done ? 'emerald' : locked ? 'slate' : node.isReinforcement ? 'amber' : 'indigo'}
                          size="sm"
                        >
                          {done
                            ? t('path.completed')
                            : locked
                            ? 'Qulflangan'
                            : node.isReinforcement
                            ? t('path.reinforce')
                            : isActive
                            ? t('lesson.nextStep')
                            : 'Ochiq'}
                        </Badge>
                      </div>
                      <span className="font-mono text-xs font-bold text-slatefine">0{index + 1}</span>
                    </div>

                    {/* (b) Middle: Title, Description & Progress */}
                    <div className="min-w-0 space-y-2">
                      <h3 className="heading break-words text-lg font-extrabold">{node.title}</h3>
                      {node.description && (
                        <p className="line-clamp-2 text-sm leading-relaxed text-slatefine">{node.description}</p>
                      )}
                      {node.score != null && (
                        <div className="max-w-md pt-1">
                          <Progress
                            value={node.score}
                            size="sm"
                            tone={node.score >= 80 ? 'emerald' : 'indigo'}
                            ariaLabel={`${node.title} o‘zlashtirish`}
                          />
                        </div>
                      )}
                      {locked && prerequisites.length > 0 && (
                        <p className="text-xs font-medium text-slatefine">{t('path.prerequisite')}{' '}{prerequisites.join(', ')}</p>
                      )}
                    </div>

                    {/* (c) Bottom: Meta Data & Action Button */}
                    <div className="flex flex-wrap items-center justify-between gap-3 border-t border-slate-100 pt-3">
                      <p className="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs font-bold text-slatefine">
                        <span className="inline-flex items-center gap-1">
                          <Clock aria-hidden="true" className="size-3.5 text-brand" />
                          {node.estimatedMinutes}{t('courses.minutes')}</span>
                        <span className="inline-flex items-center gap-1 text-amber-600">
                          <Zap aria-hidden="true" className="size-3.5" />
                          +20 XP
                        </span>
                        {node.score != null && <span>{t('tutor.mastery')}{' '}{node.score}%</span>}
                      </p>

                      {!locked && (
                        <div>
                          {node.isReinforcement && !done ? (
                            <Button
                              size="sm"
                              variant="outline"
                              isLoading={practiceLoading === node.id}
                              disabled={practiceLoading !== null}
                              onClick={() => void loadPractice(node)}
                            >{t('path.startExercise')}</Button>
                          ) : target ? (
                            <Button
                              size="sm"
                              variant={done ? 'outline' : 'primary'}
                              onClick={() => {
                                useRoadmapStore.getState().selectNode(node);
                                onStartLesson(target);
                              }}
                              leftIcon={<Play aria-hidden="true" className="size-4" />}
                            >
                              {done ? t('path.review') : t('path.startLesson')}
                            </Button>
                          ) : (
                            !done && <p className="text-xs text-slatefine">{t('path.noLesson')}</p>
                          )}
                        </div>
                      )}
                    </div>
                  </Card>
                </li>
              );
            })}
          </ol>
        </>
      )}
      {practice && (
        <ReinforcementModal
          isOpen
          question={practice}
          courseId={practice.courseId}
          skillId={practice.skillId}
          onClose={() => setPractice(null)}
          onSuccess={() => {
            setPractice(null);
            void useLearnerStore
              .getState()
              .loadProfile()
              .catch(() => setPracticeError(t('path.refreshProfile')));
          }}
        />
      )}
    </div>
  );
}
