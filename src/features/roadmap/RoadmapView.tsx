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

const filters = { all: 'Barchasi', active: 'Ochiq bosqichlar', completed: 'Yakunlangan' } as const;

interface RoadmapViewProps {
  onStartLesson: (lessonId: string) => void;
  onOpenKnowledgeMap: () => void;
  onChooseCourse: () => void;
  onConfigure: () => void;
}

export function RoadmapView({ onStartLesson, onOpenKnowledgeMap, onChooseCourse, onConfigure }: RoadmapViewProps) {
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
        throw new Error('Bu mavzuga mos mashq topilmadi.');
      }
      setPractice(linked.reinforcementExercise);
    } catch {
      setPracticeError('Mustahkamlash mashqi yuklanmadi. Qayta urinib ko‘ring.');
    } finally {
      setPracticeLoading(null);
    }
  };

  return (
    <div className="learning-page space-y-6 sm:space-y-8">
      <PageHeader
        eyebrow={course?.title ?? 'O‘quv reja'}
        title="Mening ta’lim yo‘lim"
        highlightWord="ta’lim yo‘lim"
        description="Mavzular bog‘liqligini ko‘ring va navbatdagi bosqichni boshlang."
        action={
          ready && (
            <Button
              variant="outline"
              leftIcon={<Compass aria-hidden="true" className="size-4 text-brand" />}
              onClick={onOpenKnowledgeMap}
            >
              Bilim xaritasi
            </Button>
          )
        }
      />

      {!course ? (
        <Card className="space-y-4">
          <SectionState title="Avval fanni tanlang" />
          <Button onClick={onChooseCourse}>Fanlar katalogi</Button>
        </Card>
      ) : !ready ? (
        <Card className="space-y-4">
          <span className="highlight">Boshlang‘ich sozlama</span>
          <h2 className="heading text-xl font-extrabold">Qayerdan boshlaysiz?</h2>
          <p className="text-sm text-slatefine">Fan bo‘yicha darajangizni tanlaganingizdan keyin mos reja ochiladi.</p>
          <Button onClick={onConfigure}>O‘rganishni boshlash</Button>
        </Card>
      ) : foundation ? (
        <div className="grid items-start gap-6 lg:grid-cols-[minmax(0,1fr)_18rem]">
          <section className="min-w-0 space-y-4" aria-labelledby="foundation-title">
            <div>
              <span className="highlight mb-2">Asosiy poydevor</span>
              <h2 id="foundation-title" className="heading text-2xl font-extrabold">
                Boshlang‘ich <span className="heading-accent">darslar</span>
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
                          {done ? 'Tugallangan' : current ? 'Navbatdagi darsingiz' : 'Keyingi bosqich'}
                        </Badge>
                        <h3 className="heading text-base font-extrabold">{index + 1}-boshlang‘ich dars</h3>
                      </div>
                      {(current || done) && (
                        <Button variant={current ? 'primary' : 'outline'} size="sm" onClick={() => onStartLesson(id)}>
                          {current ? 'Boshlang‘ich darsni ochish' : 'Qayta ko‘rish'}
                        </Button>
                      )}
                    </Card>
                  </li>
                );
              })}
            </ol>
          </section>
          <Card className="fade-up stagger-2 space-y-3" padding="md">
            <span className="highlight">Progress</span>
            <h2 className="heading text-lg font-extrabold">Yo‘ldagi natijangiz</h2>
            <p className="text-sm text-slatefine">
              {foundationCompleted} / {foundationPath.length} dars tugallangan
            </p>
            <Progress value={(100 * foundationCompleted) / foundationPath.length} tone="emerald" ariaLabel="Boshlang‘ich darslar bajarilishi" />
          </Card>
        </div>
      ) : error && !path ? (
        <SectionState
          kind="error"
          title="Ta’lim yo‘li yuklanmadi"
          description={error}
          onRetry={() => void useRoadmapStore.getState().loadRoadmap(course.id)}
        />
      ) : !path ? (
        <SectionState kind="loading" title="Ta’lim yo‘li yuklanmoqda…" />
      ) : (
        <>
          <section className="learning-hero fade-up stagger-1 grid items-center gap-5 rounded-3xl p-6 sm:grid-cols-[minmax(0,1fr)_auto] sm:p-8">
            <div className="min-w-0 space-y-2.5">
              <span className="inline-flex items-center gap-1.5 rounded-full bg-white/15 px-3 py-1 text-xs font-bold text-indigo-100">
                <Sparkles aria-hidden="true" className="size-3.5 text-sky-300" />
                O‘quv rejangiz
              </span>
              <h2 className="font-display text-2xl font-extrabold sm:text-3xl">
                {completed} / {topics.length} mavzu yakunlangan
              </h2>
              {topics.length > 0 && (
                <Progress
                  value={(100 * completed) / topics.length}
                  tone="cyan"
                  size="sm"
                  className="max-w-sm"
                  ariaLabel="Yo‘l bosqichlari bajarilishi"
                />
              )}
            </div>
            {lesson && (
              <Button
                variant="outline"
                className="w-fit border-white bg-white text-brand hover:bg-indigo-50"
                onClick={() => onStartLesson(lesson)}
                rightIcon={<ArrowRight aria-hidden="true" className="size-4" />}
              >
                Davom etish
              </Button>
            )}
          </section>

          <div role="group" aria-label="Bosqichlarni filtrlash" className="fade-up stagger-2 flex flex-wrap gap-2">
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
            <SectionState title={nodes.length ? 'Bu bo‘limda bosqichlar yo‘q' : 'Bu fan uchun ta’lim yo‘li hali tuzilmagan'} />
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
                            ? 'Yakunlangan'
                            : locked
                            ? 'Qulflangan'
                            : node.isReinforcement
                            ? 'Mustahkamlash'
                            : isActive
                            ? 'Keyingi qadam'
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
                        <p className="text-xs font-medium text-slatefine">Avval yakunlang · {prerequisites.join(', ')}</p>
                      )}
                    </div>

                    {/* (c) Bottom: Meta Data & Action Button */}
                    <div className="flex flex-wrap items-center justify-between gap-3 border-t border-slate-100 pt-3">
                      <p className="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs font-bold text-slatefine">
                        <span className="inline-flex items-center gap-1">
                          <Clock aria-hidden="true" className="size-3.5 text-brand" />
                          {node.estimatedMinutes} daqiqa
                        </span>
                        <span className="inline-flex items-center gap-1 text-amber-600">
                          <Zap aria-hidden="true" className="size-3.5" />
                          +20 XP
                        </span>
                        {node.score != null && <span>O‘zlashtirish · {node.score}%</span>}
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
                            >
                              Mashqni boshlash
                            </Button>
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
                              {done ? 'Qayta ko‘rish' : 'Darsni boshlash'}
                            </Button>
                          ) : (
                            !done && <p className="text-xs text-slatefine">Bu mavzu uchun dars mavjud emas.</p>
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
              .catch(() => setPracticeError('Natija saqlandi. Profilni qayta yuklang.'));
          }}
        />
      )}
    </div>
  );
}
