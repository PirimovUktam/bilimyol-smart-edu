import { useEffect, useState } from 'react';
import { ArrowRight, BookOpen, CheckCircle2, ClipboardCheck, Clock, Flame, Route, Sparkles, Zap } from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { useLessonStore } from '@/app/store/useLessonStore';
import { resolveNextLearningLesson } from '@/app/router/lessonResolution';
import { useAuth } from '@/core/context/AuthContext';
import { foundationLessons, hasStartedCourse, pendingFoundationLesson } from '@/domain/personalization/learningStart';
import { Badge } from '@/presentation/components/Badge';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';
import { PageHeader } from '@/presentation/components/PageHeader';
import { Progress } from '@/presentation/components/Progress';
import { YolchiAIMascot } from '@/presentation/components/YolchiAIMascot';

interface DashboardViewProps {
  onContinueLesson: (lessonId: string) => void;
  onOpenRoadmap: () => void;
  onOpenCourses: () => void;
  onOpenOnboarding: () => void;
  onStartPlacement: () => void;
  onOpenAITutor: () => void;
  onOpenProgress: () => void;
}

export function DashboardView({ onContinueLesson, onOpenRoadmap, onOpenCourses,
  onOpenOnboarding, onStartPlacement, onOpenAITutor, onOpenProgress }: DashboardViewProps) {
  const course = useCourseStore((state) => state.activeCourse);
  const skills = useCourseStore((state) => state.activeCourseSkills);
  const profile = useLearnerStore((state) => state.profile);
  const { profile: account, isDemoMode } = useAuth();
  const roadmap = useRoadmapStore((state) => state.roadmap);
  const roadmapError = useRoadmapStore((state) => state.error);
  const roadmapLoading = useRoadmapStore((state) => state.isLoading);
  const courseId = course?.id;
  const [generating, setGenerating] = useState(false);
  const [generationError, setGenerationError] = useState('');
  const started = Boolean(course && hasStartedCourse(course, profile));

  useEffect(() => {
    if (courseId && started) void useRoadmapStore.getState().loadRoadmap(courseId);
    setGenerationError('');
  }, [courseId, started]);

  const path = roadmap?.courseId === courseId ? roadmap : null;
  const foundation = pendingFoundationLesson(course, profile);
  const nextId = resolveNextLearningLesson(course, profile, path);
  const nextTopic = path?.nodes.find((node) => node.targetLessonId === nextId);
  const required = course?.lessons ?? [];
  const completed = required.filter((id) => profile?.completedLessonIds.includes(id)).length;
  const progressPct = required.length > 0 ? Math.round((100 * completed) / required.length) : 0;
  const firstSteps = course ? foundationLessons(course) : [];
  const foundationPosition = foundation ? firstSteps.indexOf(foundation) + 1 : 0;
  const name = account?.firstName || profile?.firstName || 'O‘quvchi';
  const nextTitle = !started ? 'Birinchi faningizni tanlang' : foundation ? 'Boshlang‘ich darsingiz' : nextTopic?.title ?? 'Ta’lim yo‘lingiz';

  const generate = async () => {
    const skill = skills.find((item) => item.id === path?.nodes.find((node) => node.id === path.activeNodeId)?.skillId) ?? skills[0];
    if (!courseId || !skill || generating) return;
    setGenerating(true);
    setGenerationError('');
    try {
      const lesson = await useLessonStore.getState().generateAILesson(courseId, skill.id, skill.name);
      if (useCourseStore.getState().activeCourse?.id !== courseId) return;
      if (lesson) onContinueLesson(lesson.id);
      else setGenerationError(useLessonStore.getState().error ?? 'Dars tayyorlanmadi. Qayta urinib ko‘ring.');
    } catch {
      if (useCourseStore.getState().activeCourse?.id === courseId) setGenerationError('Dars tayyorlanmadi. Qayta urinib ko‘ring.');
    } finally {
      setGenerating(false);
    }
  };

  return (
    <div className="learning-page space-y-6 sm:space-y-8">
      <PageHeader
        title={'Assalomu alaykum, ' + name + '!'}
        highlightWord={name + '!'}
        eyebrow={isDemoMode ? 'Namuna hisobi' : 'Mening o‘qishim'}
        description="Shaxsiy ta’lim yo‘lingiz, diagnostik tahlil va Yo‘lchi AI yordamchisi bir joyda."
      />

      {/* Modern EdTech Hero & Progress Grid */}
      <div className="grid items-stretch gap-5 xl:grid-cols-[minmax(0,1fr)_20rem]">
        <section aria-labelledby="continue-heading" className="learning-hero fade-up stagger-1 rounded-3xl p-6 sm:p-8 flex flex-col justify-between">
          <div>
            <div className="mb-4 flex flex-wrap items-center gap-2">
              <span className="inline-flex items-center gap-1.5 rounded-full bg-white/15 px-3.5 py-1.5 text-xs font-bold text-indigo-100 backdrop-blur-xs">
                <Route aria-hidden="true" className="size-4 text-sky-300" />
                {started ? course?.title : 'Shu yerdan boshlang'}
              </span>
              {(profile?.streakDays ?? 0) > 0 && (
                <span className="inline-flex items-center gap-1 rounded-full bg-emerald-400/20 px-3 py-1 text-xs font-bold text-emerald-200">
                  <Flame aria-hidden="true" className="size-3.5" />
                  {profile?.streakDays} kun ketma-ket
                </span>
              )}
              {(profile?.xp ?? 0) > 0 && (
                <span className="inline-flex items-center gap-1 rounded-full bg-amber-400/20 px-3 py-1 text-xs font-bold text-amber-200">
                  <Zap aria-hidden="true" className="size-3.5" />
                  {profile?.xp} XP
                </span>
              )}
            </div>

            <h2 id="continue-heading" className="max-w-2xl break-words font-display text-3xl leading-tight font-extrabold tracking-tight sm:text-4xl">
              {nextTitle}
            </h2>
            <p className="mt-3 max-w-xl text-sm leading-relaxed text-indigo-100/95 sm:text-base">
              {!started
                ? 'Fan va darajani tanlang. Keyingi darsni BilimYo‘l ko‘rsatadi.'
                : foundation
                ? `${firstSteps.length} ta boshlang‘ich darsdan ${foundationPosition}-dars. Avval izoh va misol, keyin mashq.`
                : nextTopic?.description || 'Darslar va navbatdagi mashg‘ulotni rejangizdan ko‘ring.'}
            </p>
          </div>

          <div className="mt-7 flex flex-wrap items-center gap-3 pt-2">
            <Button
              variant="outline"
              className="border-white bg-white text-brand hover:bg-indigo-50 shadow-lg shadow-slate-950/20"
              size="lg"
              isLoading={started && !foundation && roadmapLoading && !path}
              rightIcon={<ArrowRight aria-hidden="true" className="size-5" />}
              onClick={() => (!started ? onOpenCourses() : nextId ? onContinueLesson(nextId) : onOpenRoadmap())}
            >
              {!started ? 'Fan tanlash' : nextId ? 'Davom etish' : 'Ta’lim yo‘lini ochish'}
            </Button>
            {nextTopic && (
              <span className="inline-flex items-center gap-1.5 rounded-full bg-white/12 px-3.5 py-2 text-xs font-bold text-indigo-100">
                <Clock aria-hidden="true" className="size-4 text-sky-300" />
                {nextTopic.estimatedMinutes} daqiqa
              </span>
            )}
          </div>
          {started && roadmapError && !path && (
            <p className="mt-3 text-sm text-rose-200">Ta’lim yo‘li yuklanmadi. Yo‘lni ochib qayta urinib ko‘ring.</p>
          )}
        </section>

        {/* Course Progress Card */}
        <Card className="fade-up stagger-2 flex min-w-0 flex-col justify-between gap-4" padding="md">
          <div className="space-y-3">
            <div className="flex items-center justify-between gap-2">
              <span className="grid size-11 place-items-center rounded-2xl bg-emerald-50 text-mint shadow-2xs">
                <CheckCircle2 aria-hidden="true" className="size-6" />
              </span>
              <Badge variant="emerald">{started && required.length ? `${progressPct}% bajarildi` : 'Jarayon'}</Badge>
            </div>
            <div>
              <h2 className="heading text-lg font-extrabold">Tugallangan darslar</h2>
              <p className="mt-1.5 text-sm text-slatefine">
                {started && required.length
                  ? `${completed} / ${required.length} dars`
                  : 'Natijangiz birinchi darsdan keyin shu yerda ko‘rinadi.'}
              </p>
            </div>
          </div>

          {started && required.length > 0 && (
            <Progress value={(100 * completed) / required.length} tone="emerald" ariaLabel="Fan darslari bajarilishi" />
          )}

          <div className="pt-2 border-t border-hairline flex items-center justify-between gap-2">
            <span className="text-xs font-bold text-slatefine">Kunlik maqsad: {profile?.dailyMinutes ?? 15} daq</span>
            <Button variant="ghost" size="sm" onClick={onOpenProgress} rightIcon={<ArrowRight aria-hidden="true" className="size-3.5" />}>
              Natijalarni ko‘rish
            </Button>
          </div>
        </Card>
      </div>

      {/* AI Assistant & Study Plan / Diagnostic Cards */}
      <div className="grid gap-5 lg:grid-cols-2">
        <Card className="fade-up stagger-3 flex flex-wrap items-center justify-between gap-4 bg-gradient-to-br from-white via-white to-indigo-50/40" padding="md">
          <div className="flex items-center gap-4 min-w-0">
            <div aria-hidden="true" className="hidden sm:grid size-13 shrink-0 place-items-center rounded-2xl bg-sand">
              <YolchiAIMascot size="sm" mood="happy" />
            </div>
            <div className="min-w-0">
              <div className="mb-1">
                <span className="highlight">
                  <Sparkles aria-hidden="true" className="size-3.5" />
                  AI Ustoz
                </span>
              </div>
              <h2 className="heading flex items-center gap-2 text-lg font-extrabold">
                Yo‘lchi <span className="heading-accent">AI</span>
              </h2>
              <p className="mt-1 text-sm text-slatefine">Izoh yoki boshqa misol so‘rang.</p>
            </div>
          </div>
          <Button variant="outline" size="sm" onClick={onOpenAITutor} rightIcon={<ArrowRight aria-hidden="true" className="size-4" />}>
            Savol berish
          </Button>
        </Card>

        {started && (
          <Card className="fade-up stagger-4 flex flex-col justify-between gap-4" padding="md">
            <div>
              <div className="mb-1">
                <span className="highlight">
                  <ClipboardCheck aria-hidden="true" className="size-3.5" />
                  Moslashuvchan reja
                </span>
              </div>
              <h2 className="heading flex items-center gap-2 text-lg font-extrabold">
                <BookOpen aria-hidden="true" className="size-5 text-brand" />
                O‘qish <span className="heading-accent">rejasi</span>
              </h2>
              <p className="mt-1 text-xs text-slatefine">
                Bilim darajangizni diagnostikada sinab ko‘ring yoki rejangizni yangilang.
              </p>
            </div>
            <div className="flex flex-wrap gap-2">
              <Button variant="ghost" size="sm" onClick={onOpenOnboarding}>
                Rejani sozlash
              </Button>
              <Button variant="ghost" size="sm" onClick={onStartPlacement}>
                Ixtiyoriy diagnostika
              </Button>
              {!nextId && !roadmapLoading && !roadmapError && skills.length > 0 && (
                <Button variant="outline" size="sm" isLoading={generating} onClick={() => void generate()}>
                  Yo‘lchi bilan dars tayyorlash
                </Button>
              )}
            </div>
            {generationError && (
              <p role="alert" className="text-sm text-coral">
                {generationError}
              </p>
            )}
          </Card>
        )}
      </div>
    </div>
  );
}
