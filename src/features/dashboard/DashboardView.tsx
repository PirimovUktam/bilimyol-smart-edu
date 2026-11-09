import { useTranslation } from '@/core/locales/useTranslation';
import { useEffect, useMemo, useRef, useState } from 'react';
import {
  ArrowRight,
  Atom,
  Bell,
  BookOpen,
  Calculator,
  ChartNoAxesColumn,
  ChevronDown,
  Clock,
  Code2,
  Compass,
  Crown,
  Flame,
  FlaskConical,
  Languages,
  Play,
  Search,
  Sparkles,
  Star,
  Target,
  Trophy,
  Gem,
} from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { useLessonStore } from '@/app/store/useLessonStore';
import { resolveNextLearningLesson } from '@/app/router/lessonResolution';
import { useAuth } from '@/core/context/AuthContext';
import {
  foundationLessons,
  hasStartedCourse,
  pendingFoundationLesson,
} from '@/domain/personalization/learningStart';
import { SkillScoringEngine } from '@/domain/personalization/SkillScoringEngine';
import type { DailyActivitySummary } from '@/domain/repositories/ILearnerRepository';
import { supabaseLearnerRepository } from '@/data/repositories/SupabaseLearnerRepository';
import { Avatar } from '@/presentation/components/Avatar';
import { Button } from '@/presentation/components/Button';
import { WeeklyActivity } from '@/presentation/components/WeeklyActivity';

interface DashboardViewProps {
  onContinueLesson: (lessonId: string) => void;
  onOpenRoadmap: () => void;
  onOpenCourses: () => void;
  onOpenOnboarding: () => void;
  onStartPlacement: () => void;
  onOpenAITutor: () => void;
  onOpenProgress: () => void;
}

type CourseFilterTab = 'active' | 'recommended' | 'all';


export function DashboardView({
  onContinueLesson,
  onOpenRoadmap,
  onOpenCourses,
  onOpenOnboarding,
  onStartPlacement,
  onOpenAITutor,
  onOpenProgress,
}: DashboardViewProps) {
  const { t } = useTranslation();
  const course = useCourseStore((state) => state.activeCourse);
  const courses = useCourseStore((state) => state.courses);
  const selectCourse = useCourseStore((state) => state.selectCourseById);
  const skills = useCourseStore((state) => state.activeCourseSkills);
  const profile = useLearnerStore((state) => state.profile);
  const { profile: account, isDemoMode } = useAuth();
  const roadmap = useRoadmapStore((state) => state.roadmap);
  const roadmapError = useRoadmapStore((state) => state.error);
  const roadmapLoading = useRoadmapStore((state) => state.isLoading);
  const courseId = course?.id;

  const [generating, setGenerating] = useState(false);
  const [generationError, setGenerationError] = useState('');
  const [courseTab, setCourseTab] = useState<CourseFilterTab>('active');
  const [searchQuery, setSearchQuery] = useState('');
  const [showNotifications, setShowNotifications] = useState(false);
  const [premiumSoonOpen, setPremiumSoonOpen] = useState(false);
  const [activity, setActivity] = useState<DailyActivitySummary[] | null>(null);
  const [activityFailed, setActivityFailed] = useState(false);
  const [activityRetry, setActivityRetry] = useState(0);
  const searchInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!premiumSoonOpen) return;
    const timer = window.setTimeout(() => setPremiumSoonOpen(false), 4200);
    return () => window.clearTimeout(timer);
  }, [premiumSoonOpen]);

  const started = Boolean(course && hasStartedCourse(course, profile));

  useEffect(() => {
    if (courseId && started) {
      void useRoadmapStore.getState().loadRoadmap(courseId);
    }
    setGenerationError('');
  }, [courseId, started]);

  useEffect(() => {
    let mounted = true;
    setActivityFailed(false);
    void supabaseLearnerRepository.getDailyActivity(7).then(
      (days) => {
        if (mounted) setActivity(days);
      },
      () => {
        if (mounted) setActivityFailed(true);
      },
    );
    return () => {
      mounted = false;
    };
  }, [account?.id, profile?.completedLessonIds.length, activityRetry]);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k') {
        event.preventDefault();
        searchInputRef.current?.focus();
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, []);

  const path = roadmap?.courseId === courseId ? roadmap : null;
  const foundation = pendingFoundationLesson(course, profile);
  const nextId = resolveNextLearningLesson(course, profile, path);
  const nextTopic = path?.nodes.find((node) => node.targetLessonId === nextId);
  const required = course?.lessons ?? [];
  const completed = required.filter((id) =>
    profile?.completedLessonIds.includes(id),
  ).length;
  const progressPct =
    required.length > 0 ? Math.round((100 * completed) / required.length) : 0;
  const firstSteps = course ? foundationLessons(course) : [];
  const foundationPosition = foundation
    ? firstSteps.indexOf(foundation) + 1
    : 0;
  const name = account?.firstName || profile?.firstName || t('courses.student');
  const nextTitle = !started
    ? t('dashboard.firstSubject')
    : foundation
    ? t('dashboard.foundation')
    : nextTopic?.title ?? t('dashboard.yourPath');

  const courseScores = courseId ? profile?.scoresByCourse[courseId] ?? {} : {};
  const scoreValues = Object.values(courseScores);
  const overallMastery =
    scoreValues.length > 0
      ? SkillScoringEngine.computeOverallScore(courseScores)
      : progressPct;
  const masteredSkillsCount = scoreValues.filter((s) => s.score >= 70).length;
  const totalCompletedAllCourses = profile?.completedLessonIds.length ?? 0;
  const earnedBadgesCount =
    (totalCompletedAllCourses > 0 ? 1 : 0) +
    ((profile?.streakDays ?? 0) > 0 ? 1 : 0) +
    (masteredSkillsCount > 0 ? 1 : 0) +
    ((profile?.xp ?? 0) >= 50 ? 1 : 0) +
    (progressPct >= 50 ? 1 : 0);

  const generate = async () => {
    const skill =
      skills.find(
        (item) =>
          item.id ===
          path?.nodes.find((node) => node.id === path.activeNodeId)?.skillId,
      ) ?? skills[0];
    if (!courseId || !skill || generating) return;
    setGenerating(true);
    setGenerationError('');
    try {
      const lesson = await useLessonStore
        .getState()
        .generateAILesson(courseId, skill.id, skill.name);
      if (useCourseStore.getState().activeCourse?.id !== courseId) return;
      if (lesson) onContinueLesson(lesson.id);
      else {
        setGenerationError(
          useLessonStore.getState().error ??
            t('dashboard.lessonFailed'),
        );
      }
    } catch {
      if (useCourseStore.getState().activeCourse?.id === courseId) {
        setGenerationError(t('dashboard.lessonFailed'));
      }
    } finally {
      setGenerating(false);
    }
  };

  // Real course cards with real completion metrics
  const enrichedCourses = useMemo(() => {
    return courses.map((item) => {
      const total = item.lessons.length;
      const done = item.lessons.filter((id) =>
        profile?.completedLessonIds.includes(id),
      ).length;
      const pct = total > 0 ? Math.round((100 * done) / total) : 0;
      const isItemStarted = hasStartedCourse(item, profile);
      const isCurrent = item.id === course?.id;
      return {
        course: item,
        total,
        done,
        pct,
        isItemStarted,
        isCurrent,
      };
    });
  }, [courses, profile, course?.id]);

  const displayedCourses = useMemo(() => {
    if (courseTab === 'active') {
      const activeList = enrichedCourses.filter(
        (c) => c.isCurrent || c.isItemStarted || c.done > 0,
      );
      return (activeList.length >= 3 ? activeList : enrichedCourses).slice(0, 3);
    }
    if (courseTab === 'recommended') {
      const rec = enrichedCourses.filter((c) => c.pct < 100);
      return (rec.length > 0 ? rec : enrichedCourses).slice(0, 3);
    }
    return enrichedCourses;
  }, [enrichedCourses, courseTab]);

  // Search filtering across courses and roadmap nodes
  const searchResults = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    if (!q) return [];
    const results: Array<{
      id: string;
      title: string;
      subtitle: string;
      onSelect: () => void;
    }> = [];

    for (const c of courses) {
      if (
        c.title.toLowerCase().includes(q) ||
        c.description.toLowerCase().includes(q)
      ) {
        results.push({
          id: 'course_' + c.id,
          title: c.title,
          subtitle: t('dynamic.courseSummary', { count: c.lessons.length }),
          onSelect: () => {
            setSearchQuery('');
            void selectCourse(c.id);
          },
        });
      }
    }

    for (const node of path?.nodes ?? []) {
      if (
        node.title.toLowerCase().includes(q) ||
        (node.description ?? '').toLowerCase().includes(q)
      ) {
        results.push({
          id: 'node_' + node.id,
          title: node.title,
          subtitle: (course?.title ?? t('courses.topic')) + ' · ' + t('dynamic.minutes', { count: node.estimatedMinutes }),
          onSelect: () => {
            setSearchQuery('');
            if (node.targetLessonId) onContinueLesson(node.targetLessonId);
            else onOpenRoadmap();
          },
        });
      }
    }
    return results.slice(0, 5);
  }, [searchQuery, courses, path?.nodes, course?.title, selectCourse, onContinueLesson, onOpenRoadmap, t]);

  const handleCourseAction = async (targetCourseId: string) => {
    if (targetCourseId === course?.id) {
      if (!started) onOpenOnboarding();
      else if (nextId) onContinueLesson(nextId);
      else onOpenRoadmap();
      return;
    }
    await selectCourse(targetCourseId);
    const chosen = useCourseStore.getState().activeCourse;
    if (chosen && !hasStartedCourse(chosen, useLearnerStore.getState().profile)) {
      onOpenOnboarding();
    }
  };

  return (
    <div className="learning-page space-y-6 text-ink">
      {/* =====================================================================
          TOP NAVBAR ROW: Search (Ctrl+K), Notifications, Streak, User Profile
         ===================================================================== */}
      <div className="fade-up flex flex-wrap items-center justify-between gap-3">
        {/* Search Bar */}
        <div className="relative min-w-0 flex-1 sm:max-w-md lg:max-w-lg">
          <div className="flex h-11 items-center gap-2.5 rounded-2xl border border-hairline bg-paper px-3.5 shadow-inner backdrop-blur-md focus-within:border-hairline">
            <Search aria-hidden="true" className="size-4 shrink-0 text-slatefine" />
            <input
              ref={searchInputRef}
              type="search"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder={t('dashboard.searchPlaceholder')}
              aria-label={t('dashboard.searchLabel')}
              className="min-w-0 flex-1 bg-transparent text-xs sm:text-sm text-ink placeholder:text-slatefine focus:outline-none"
            />
            <kbd className="hidden rounded-lg border border-hairline bg-paper px-2 py-0.5 font-mono text-[10px] font-semibold text-slatefine sm:inline-block">
              Ctrl K
            </kbd>
          </div>

          {searchQuery.trim().length > 0 && (
            <div className="absolute top-13 right-0 left-0 z-30 rounded-2xl border border-hairline bg-paper p-2 shadow-2xl backdrop-blur-xl">
              {searchResults.length > 0 ? (
                <ul className="space-y-1">
                  {searchResults.map((item) => (
                    <li key={item.id}>
                      <button
                        type="button"
                        onClick={item.onSelect}
                        className="flex w-full cursor-pointer items-center justify-between rounded-xl px-3 py-2 text-left transition-colors hover:bg-purple-500/20"
                      >
                        <div className="min-w-0">
                          <p className="truncate text-xs font-bold text-ink">
                            {item.title}
                          </p>
                          <p className="truncate text-[11px] text-slatefine">
                            {item.subtitle}
                          </p>
                        </div>
                        <ArrowRight
                          aria-hidden="true"
                          className="size-3.5 shrink-0 text-brand-dark"
                        />
                      </button>
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="px-3 py-2 text-xs text-slatefine">{t('dashboard.nothingFound')}</p>
              )}
            </div>
          )}
        </div>

        {/* Right Cluster: Bell, Streak, Profile */}
        <div className="flex items-center gap-2.5 sm:gap-3">
          <div className="relative">
            <button
              type="button"
              aria-label={t('dashboard.notifications')}
              onClick={() => setShowNotifications((prev) => !prev)}
              className="relative grid size-11 cursor-pointer place-items-center rounded-2xl border border-hairline bg-paper text-slatefine transition-all hover:border-hairline hover:text-ink"
            >
              <Bell aria-hidden="true" className="size-4.5" />
              <span
                aria-hidden="true"
                className="absolute top-2.5 right-2.5 size-2 rounded-full bg-pink-500 ring-2 ring-[#151A42]"
              />
            </button>

            {showNotifications && (
              <div className="absolute right-0 z-30 mt-2 w-72 rounded-2xl border border-hairline bg-paper p-4 shadow-2xl backdrop-blur-xl">
                <p className="text-xs font-extrabold text-ink">{t('dashboard.reminders')}</p>
                <p className="mt-1.5 text-xs leading-relaxed text-slatefine">{t('dashboard.dailyGoal')}{' '}<strong>{profile?.dailyMinutes ?? 15}{t('courses.minutes')}</strong>.{' '}
                  {started
                    ? t('dynamic.currentSubject', { title: course?.title ?? '', progress: progressPct })
                    : t('dashboard.chooseToStart')}
                </p>
                <div className="mt-3 flex gap-2">
                  <button
                    type="button"
                    onClick={() => {
                      setShowNotifications(false);
                      onOpenOnboarding();
                    }}
                    className="cursor-pointer rounded-xl bg-purple-500/25 px-3 py-1.5 text-xs font-bold text-brand-dark hover:bg-purple-500/35"
                  >{t('dashboard.configure')}</button>
                  <button
                    type="button"
                    onClick={() => setShowNotifications(false)}
                    className="cursor-pointer rounded-xl px-2.5 py-1.5 text-xs font-semibold text-slatefine hover:text-ink"
                  >{t('courses.close')}</button>
                </div>
              </div>
            )}
          </div>

          {/* Streak Pill */}
          <div className="flex h-11 items-center gap-2 rounded-2xl border border-hairline bg-paper px-3.5">
            <span className="grid size-7 place-items-center rounded-xl bg-gradient-to-br from-amber-400/25 to-orange-500/25 text-amber-400">
              <Flame aria-hidden="true" className="size-4 fill-amber-400" />
            </span>
            <div className="leading-tight">
              <p className="text-xs font-extrabold text-ink">
                {profile?.streakDays ?? 0}{t('courses.day')}</p>
              <p className="text-[10px] font-medium text-slatefine">{t('dashboard.consecutive')}</p>
            </div>
          </div>

          {/* Profile Pill */}
          <button
            type="button"
            onClick={onOpenCourses}
            className="hidden cursor-pointer items-center gap-2.5 rounded-2xl border border-hairline bg-paper py-1.5 pr-3 pl-2 transition-all hover:border-hairline sm:flex"
          >
            <Avatar
              name={name}
              className="size-8! bg-gradient-to-br! from-purple-500! to-pink-500! text-white!"
            />
            <div className="text-left leading-tight">
              <p className="max-w-28 truncate text-xs font-extrabold text-ink">
                {name}
              </p>
              <p className="max-w-28 truncate text-[10px] font-medium text-slatefine">
                {isDemoMode ? t('profile.demo') : course?.title ?? t('courses.student')}
              </p>
            </div>
            <ChevronDown aria-hidden="true" className="size-3.5 text-slatefine" />
          </button>
        </div>
      </div>

      {/* =====================================================================
          MAIN 12-COLUMN GRID: Left (Hero + Courses + Subjects) | Right (Goal + AI + Achievements)
         ===================================================================== */}
      <div className="grid items-start gap-5 xl:grid-cols-12">
        {/* LEFT 8 COLUMNS */}
        <div className="min-w-0 space-y-6 xl:col-span-8">
          {/* HERO BANNER */}
          <section
            aria-labelledby="continue-heading"
            className="fade-up stagger-1 relative overflow-hidden rounded-3xl border border-purple-400/35 bg-gradient-to-r from-[#141A4E] via-[#261C69] to-[#3B1D7E] p-6 sm:p-8 shadow-[0_24px_60px_-12px_rgba(124,58,237,0.45)]"
          >
            {/* Cosmic Illustration Backdrop (Mountain Peak + Glowing Winding Path + Sunburst) */}
            <svg
              aria-hidden="true"
              viewBox="0 0 800 340"
              preserveAspectRatio="xMidYMid slice"
              className="pointer-events-none absolute inset-0 h-full w-full object-cover opacity-90"
            >
              <defs>
                <radialGradient id="heroSunGlow" cx="72%" cy="38%" r="48%">
                  <stop offset="0%" stopColor="#FBBF24" stopOpacity="0.85" />
                  <stop offset="35%" stopColor="#EC4899" stopOpacity="0.55" />
                  <stop offset="70%" stopColor="#7C3AED" stopOpacity="0.25" />
                  <stop offset="100%" stopColor="#141A4E" stopOpacity="0" />
                </radialGradient>
                <linearGradient id="heroMountain" x1="0%" y1="0%" x2="100%" y2="100%">
                  <stop offset="0%" stopColor="#4C1D95" />
                  <stop offset="50%" stopColor="#311068" />
                  <stop offset="100%" stopColor="#150D3A" />
                </linearGradient>
                <linearGradient id="heroRoad" x1="0%" y1="100%" x2="100%" y2="0%">
                  <stop offset="0%" stopColor="#22D3EE" />
                  <stop offset="35%" stopColor="#EC4899" />
                  <stop offset="75%" stopColor="#F59E0B" />
                  <stop offset="100%" stopColor="#FEF08A" />
                </linearGradient>
              </defs>

              {/* Ambient Sunburst & Rays */}
              <circle cx="585" cy="135" r="240" fill="url(#heroSunGlow)" />
              <circle cx="585" cy="135" r="38" fill="#FDE047" opacity="0.55" />
              <g stroke="#FDE047" strokeOpacity="0.22" strokeWidth="2">
                <line x1="585" y1="135" x2="460" y2="25" />
                <line x1="585" y1="135" x2="520" y2="10" />
                <line x1="585" y1="135" x2="650" y2="15" />
                <line x1="585" y1="135" x2="735" y2="45" />
                <line x1="585" y1="135" x2="780" y2="110" />
              </g>

              {/* Stars */}
              <circle cx="420" cy="48" r="1.5" fill="#FFF" opacity="0.7" />
              <circle cx="485" cy="32" r="2" fill="#22D3EE" opacity="0.8" />
              <circle cx="690" cy="52" r="1.8" fill="#F472B6" opacity="0.8" />
              <circle cx="740" cy="88" r="1.2" fill="#FFF" opacity="0.6" />
              <circle cx="530" cy="75" r="1.5" fill="#FDE047" opacity="0.7" />

              {/* Distant Mountains */}
              <path
                d="M360 340 L490 165 L595 265 L695 110 L800 245 L800 340 Z"
                fill="url(#heroMountain)"
                opacity="0.75"
              />
              {/* Main Summit Peak */}
              <path
                d="M460 340 L635 92 L795 340 Z"
                fill="url(#heroMountain)"
              />
              {/* Flag on Summit */}
              <path
                d="M635 92 L635 64 L658 73 L635 82"
                stroke="#F59E0B"
                strokeWidth="2.5"
                fill="#EF4444"
              />

              {/* Glowing Winding Learning Road */}
              <path
                d="M635 95 C615 140, 670 165, 620 205 C570 245, 650 280, 520 340 L615 340 C705 280, 610 245, 645 205 C685 165, 630 140, 640 95 Z"
                fill="url(#heroRoad)"
                opacity="0.92"
              />

              {/* Stylized Explorer Learner Silhouette looking toward the Summit */}
              <g transform="translate(432, 185)">
                {/* Backpack */}
                <rect
                  x="6"
                  y="56"
                  width="34"
                  height="48"
                  rx="12"
                  fill="#312E81"
                  stroke="#F472B6"
                  strokeWidth="1.5"
                />
                {/* Torso / Jacket */}
                <path
                  d="M24 52 C44 52, 56 72, 60 115 L14 115 C16 78, 18 58, 24 52 Z"
                  fill="#1E1B4B"
                  stroke="#A855F7"
                  strokeWidth="1.5"
                />
                {/* Head & Hair rim-lit by the golden sun */}
                <circle
                  cx="38"
                  cy="28"
                  r="16"
                  fill="#1E1B4B"
                  stroke="#FBBF24"
                  strokeWidth="1.8"
                />
              </g>
            </svg>

            {/* Dark left vignette for crisp text readability */}
            <div
              aria-hidden="true"
              className="pointer-events-none absolute inset-0 bg-gradient-to-r from-[#121642]/95 via-[#1B1852]/80 to-transparent"
            />

            <div className="relative z-10 max-w-xl space-y-4">
              <div className="flex flex-wrap items-center gap-2">
                <span className="inline-flex items-center gap-1.5 rounded-full border border-cyan-300/30 bg-cyan-400/15 px-3 py-1 text-xs font-bold text-cyan-200 backdrop-blur-xs">
                  <Compass aria-hidden="true" className="size-3.5" />
                  {started ? course?.title : t('dashboard.startingPath')}
                </span>
                {(profile?.xp ?? 0) > 0 && (
                  <span className="inline-flex items-center gap-1 rounded-full border border-amber-300/30 bg-amber-400/15 px-3 py-1 text-xs font-bold text-amber-200">
                    <Sparkles aria-hidden="true" className="size-3.5" />
                    {profile?.xp} XP
                  </span>
                )}
              </div>

              <h1 id="continue-heading" className="space-y-1">
                <span className="block text-base font-bold text-indigo-100 sm:text-lg">{t('dashboard.greeting')}{' '}{name}! 👋
                </span>
                <span className="block font-display text-2xl leading-tight font-extrabold tracking-tight text-white sm:text-4xl">{t('dashboard.continuePath')}</span>
              </h1>

              <p className="max-w-md text-xs leading-relaxed text-indigo-100/90 sm:text-sm">
                {!started
                  ? t('dashboard.chooseLevel')
                  : foundation
                  ? t('dynamic.foundationPosition', { total: firstSteps.length, position: foundationPosition, title: nextTitle })
                  : `${nextTitle} — ${
                      nextTopic?.description ||
                      t('dashboard.dailyDescription')
                    }`}
              </p>

              <div className="flex flex-wrap items-center gap-3 pt-2">
                <Button
                  variant="gradient"
                  size="lg"
                  className="cosmos-cta-btn border-0! px-6! py-3! text-sm! font-extrabold! text-white!"
                  isLoading={started && !foundation && roadmapLoading && !path}
                  rightIcon={<ArrowRight aria-hidden="true" className="size-4.5" />}
                  onClick={() =>
                    !started
                      ? onOpenCourses()
                      : nextId
                      ? onContinueLesson(nextId)
                      : onOpenRoadmap()
                  }
                >
                  {!started
                    ? t('courses.choose')
                    : nextId
                    ? t('courses.continue')
                    : t('courses.openPath')}
                </Button>

                {started && (
                  <button
                    type="button"
                    onClick={onOpenRoadmap}
                    className="cursor-pointer rounded-full border border-white/20 bg-white/10 px-4 py-2.5 text-xs font-bold text-indigo-100 backdrop-blur-xs transition-colors hover:bg-white/20"
                  >{t('dashboard.pathCount')}{' '}{completed}/{required.length || 1})
                  </button>
                )}
              </div>

              {started && roadmapError && !path && (
                <p className="text-xs text-rose-200">{t('dashboard.pathFailed')}</p>
              )}
            </div>
          </section>

          {/* MENING KURSLARIM SECTION */}
          <section aria-labelledby="my-courses-heading" className="fade-up stagger-2 space-y-3.5">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <h2
                id="my-courses-heading"
                className="font-display text-lg font-extrabold tracking-tight text-ink sm:text-xl"
              >{t('dashboard.myCourses')}</h2>

              <div
                role="tablist"
                aria-label={t('dashboard.courseFilter')}
                className="inline-flex rounded-full border border-hairline bg-paper p-1"
              >
                {(
                  [
                    ['active', t('courses.active')],
                    ['recommended', t('dashboard.recommended')],
                    ['all', t('courses.all')],
                  ] as const
                ).map(([key, label]) => (
                  <button
                    key={key}
                    type="button"
                    role="tab"
                    aria-selected={courseTab === key}
                    onClick={() => setCourseTab(key)}
                    className={`cursor-pointer rounded-full px-3.5 py-1 text-xs font-bold transition-all ${
                      courseTab === key
                        ? 'bg-gradient-to-r from-[#8B5CF6] to-[#6366F1] text-white shadow-md shadow-purple-500/30'
                        : 'text-slatefine hover:bg-sand hover:text-ink'
                    }`}
                  >
                    {label}
                  </button>
                ))}
              </div>
            </div>

            <div className="grid gap-3.5 sm:grid-cols-2 lg:grid-cols-3">
              {displayedCourses.map(({ course: c, total, done, pct, isCurrent }) => {
                const isMath = c.subject === 'mathematics';
                const isEng = c.subject === 'english';
                const isIt = c.subject === 'it';

                const iconBoxClass = isMath
                  ? 'from-blue-500 to-indigo-600 shadow-blue-500/30'
                  : isEng
                  ? 'from-rose-500 to-pink-600 shadow-rose-500/30'
                  : isIt
                  ? 'from-cyan-500 to-blue-600 shadow-cyan-500/30'
                  : 'from-purple-500 to-indigo-600 shadow-purple-500/30';

                const barClass = isMath
                  ? 'from-emerald-400 to-cyan-400'
                  : isEng
                  ? 'from-amber-400 to-orange-500'
                  : 'from-cyan-400 to-purple-500';

                const IconComp = isMath
                  ? Calculator
                  : isEng
                  ? Languages
                  : isIt
                  ? Code2
                  : Atom;

                return (
                  <article
                    key={c.id}
                    className={`cosmos-card cosmos-card-hover flex flex-col justify-between p-4 ${
                      isCurrent ? 'ring-1 ring-purple-400/50' : ''
                    }`}
                  >
                    <div className="flex items-start gap-3">
                      <span
                        className={`grid size-11 shrink-0 place-items-center rounded-2xl bg-gradient-to-br ${iconBoxClass} text-white shadow-lg`}
                      >
                        <IconComp aria-hidden="true" className="size-5.5" />
                      </span>
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center justify-between gap-1">
                          <h3 className="truncate font-display text-sm font-extrabold text-ink">
                            {c.title}
                          </h3>
                          <span className="shrink-0 font-mono text-xs font-extrabold text-slatefine">
                            {pct}%
                          </span>
                        </div>
                        <p className="mt-0.5 truncate text-[11px] font-medium text-slatefine">
                          {done}/{total}{' '}{t('dashboard.lessonCount')}{' '}{isCurrent ? t('dashboard.activeCourse') : t('dashboard.mainCourse')}
                        </p>
                      </div>
                    </div>

                    <div className="mt-4 flex items-center gap-3">
                      <div className="h-2 flex-1 overflow-hidden rounded-full bg-sand">
                        <div
                          className={`h-full rounded-full bg-gradient-to-r ${barClass} transition-all duration-500`}
                          style={{ width: `${pct}%` }}
                        />
                      </div>
                      <button
                        type="button"
                        aria-label={t('dynamic.openCourse', { title: c.title })}
                        onClick={() => void handleCourseAction(c.id)}
                        className="grid size-8 shrink-0 cursor-pointer place-items-center rounded-full bg-gradient-to-br from-[#8B5CF6] to-[#6366F1] text-white shadow-md shadow-purple-500/35 transition-transform hover:scale-105"
                      >
                        <Play aria-hidden="true" className="size-3.5 fill-white" />
                      </button>
                    </div>
                  </article>
                );
              })}
            </div>
          </section>

          {/* FANLAR SECTION */}
          <section aria-labelledby="subjects-heading" className="fade-up stagger-3 space-y-3.5">
            <div className="flex items-center justify-between gap-2">
              <h2
                id="subjects-heading"
                className="font-display text-lg font-extrabold tracking-tight text-ink sm:text-xl"
              >{t('dashboard.subjects')}</h2>
              <button
                type="button"
                onClick={onOpenCourses}
                className="inline-flex cursor-pointer items-center gap-1.5 rounded-full border border-hairline bg-paper px-3.5 py-1.5 text-xs font-bold text-slatefine transition-colors hover:border-hairline hover:text-ink"
              >{t('dashboard.allSubjects')}<ArrowRight aria-hidden="true" className="size-3.5" />
              </button>
            </div>

            <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-6">
              {[
                {
                  id: 'sub_math',
                  label: t('admin.mathematics'),
                  symbol: 'π',
                  gradient: 'from-[#2E3888]/90 to-[#1D245B]/95 border-indigo-400/35',
                  badgeBg: 'bg-indigo-500/30 text-slatefine',
                  onClick: () => {
                    const target = courses.find((c) => c.subject === 'mathematics');
                    if (target) void handleCourseAction(target.id);
                    else onOpenCourses();
                  },
                },
                {
                  id: 'sub_eng',
                  label: t('dashboard.english'),
                  symbol: 'Aa',
                  gradient: 'from-[#6B2B5C]/90 to-[#3D1B44]/95 border-pink-400/35',
                  badgeBg: 'bg-rose-500/30 text-rose-200',
                  onClick: () => {
                    const target = courses.find((c) => c.subject === 'english');
                    if (target) void handleCourseAction(target.id);
                    else onOpenCourses();
                  },
                },
                {
                  id: 'sub_it',
                  label: 'IT',
                  symbol: '</>',
                  gradient: 'from-[#243B82]/90 to-[#172556]/95 border-sky-400/35',
                  badgeBg: 'bg-sky-500/30 text-sky-200',
                  onClick: () => {
                    const target = courses.find((c) => c.subject === 'it');
                    if (target) void handleCourseAction(target.id);
                    else onOpenCourses();
                  },
                },
                {
                  id: 'sub_logic',
                  label: t('admin.logic'),
                  icon: Atom,
                  gradient: 'from-[#1D4E6E]/90 to-[#14324A]/95 border-cyan-400/35',
                  badgeBg: 'bg-cyan-500/30 text-path',
                  onClick: () => {
                    const target = courses.find((c) => c.subject === 'logic');
                    if (target) void handleCourseAction(target.id);
                    else onOpenCourses();
                  },
                },
                {
                  id: 'sub_diag',
                  label: t('auth.diagnostics'),
                  icon: FlaskConical,
                  gradient: 'from-[#4B2882]/90 to-[#2B1954]/95 border-hairline',
                  badgeBg: 'bg-purple-500/30 text-brand-dark',
                  onClick: onStartPlacement,
                },
                {
                  id: 'sub_map',
                  label: t('path.map'),
                  icon: Compass,
                  gradient: 'from-[#1A5E4E]/90 to-[#123D35]/95 border-emerald-400/35',
                  badgeBg: 'bg-emerald-500/30 text-emerald-200',
                  onClick: onOpenRoadmap,
                },
              ].map((tile) => {
                const TileIcon = tile.icon;
                return (
                  <button
                    key={tile.id}
                    type="button"
                    onClick={tile.onClick}
                    className={`group flex cursor-pointer flex-col items-center justify-center gap-2 rounded-2xl border bg-gradient-to-b p-3.5 text-center shadow-lg transition-all hover:-translate-y-1 ${tile.gradient}`}
                  >
                    <span
                      className={`grid size-10 place-items-center rounded-full text-base font-extrabold shadow-inner transition-transform group-hover:scale-110 ${tile.badgeBg}`}
                    >
                      {TileIcon ? (
                        <TileIcon aria-hidden="true" className="size-5" />
                      ) : (
                        tile.symbol
                      )}
                    </span>
                    <span className="truncate text-xs font-bold text-white">
                      {tile.label}
                    </span>
                  </button>
                );
              })}
            </div>
          </section>
        </div>

        {/* RIGHT 4 COLUMNS */}
        <div className="min-w-0 space-y-5 xl:col-span-4">
          {/* CARD 1: BUGUNGI MAQSAD */}
          <section
            aria-labelledby="daily-goal-heading"
            className="cosmos-card fade-up stagger-2 p-5"
          >
            <div className="flex items-center gap-3.5">
              <span className="grid size-12 shrink-0 place-items-center rounded-2xl bg-gradient-to-br from-pink-500/25 via-purple-500/25 to-indigo-500/25 text-pink-300 ring-1 ring-pink-400/30">
                <Target aria-hidden="true" className="size-6" />
              </span>
              <div className="min-w-0 flex-1">
                <h2
                  id="daily-goal-heading"
                  className="font-display text-base font-extrabold text-ink"
                >{t('dashboard.todayGoal')}</h2>
                <div className="mt-1 flex items-center justify-between gap-2">
                  <p className="text-sm font-extrabold text-slatefine">
                    {started && required.length
                      ? t('dynamic.lessonCompletion', { done: completed, total: required.length })
                      : t('dynamic.lessonCount', { count: 0 })}
                  </p>
                  <span className="rounded-lg bg-purple-500/25 px-2 py-0.5 font-mono text-xs font-extrabold text-brand-dark">
                    {progressPct}%
                  </span>
                </div>
              </div>
            </div>

            <div className="mt-4 h-2.5 w-full overflow-hidden rounded-full bg-sand">
              <div
                className="h-full rounded-full bg-gradient-to-r from-[#EC4899] via-[#A855F7] to-[#22D3EE] transition-all duration-500"
                style={{ width: `${progressPct}%` }}
              />
            </div>

            <div className="mt-3.5 flex flex-wrap items-center justify-between gap-2 border-t border-hairline pt-3 text-[11px] text-slatefine">
              <span>{t('dashboard.dailyPlan')}{' '}{profile?.dailyMinutes ?? 15}{t('dashboard.min')}</span>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={onOpenOnboarding}
                  className="cursor-pointer font-bold text-brand-dark hover:text-ink"
                >{t('dashboard.configure')}</button>
                {started && (
                  <>
                    <span>·</span>
                    <button
                      type="button"
                      onClick={onStartPlacement}
                      className="cursor-pointer font-bold text-path hover:text-ink"
                    >{t('courses.optionalDiagnostic')}</button>
                  </>
                )}
              </div>
            </div>
          </section>

          {/* CARD 2: AI TUTOR (YO'LCHI AI) */}
          <section
            aria-labelledby="ai-tutor-card-heading"
            className="fade-up stagger-3 relative overflow-hidden rounded-3xl border border-cyan-400/35 bg-gradient-to-br from-[#232A72] via-[#34217D] to-[#4C1D8F] p-5 shadow-[0_18px_40px_-10px_rgba(139,92,246,0.45)]"
          >
            <div
              aria-hidden="true"
              className="pointer-events-none absolute -right-6 -bottom-6 size-32 rounded-full bg-pink-500/25 blur-2xl"
            />
            <div className="relative z-10 flex items-center gap-4">
              <div className="grid size-13 shrink-0 place-items-center rounded-2xl bg-white/12 text-cyan-300 shadow-inner backdrop-blur-xs">
                <Sparkles aria-hidden="true" className="size-7" />
              </div>
              <div className="min-w-0 flex-1">
                <h2
                  id="ai-tutor-card-heading"
                  className="font-display text-lg font-extrabold text-white"
                >{t('dashboard.tutorTitle')}</h2>
                <p className="mt-1 text-xs leading-relaxed text-indigo-100/90">{t('dashboard.tutorDescription')}</p>
              </div>
              <button
                type="button"
                aria-label={t('dashboard.ask')}
                onClick={onOpenAITutor}
                className="grid size-10 shrink-0 cursor-pointer place-items-center rounded-full bg-gradient-to-br from-[#A855F7] to-[#6366F1] text-white shadow-lg shadow-purple-500/40 transition-transform hover:scale-105"
              >
                <ArrowRight aria-hidden="true" className="size-4.5" />
              </button>
            </div>
          </section>

          {/* CARD 3: MENING YUTUQLARIM */}
          <section
            aria-labelledby="achievements-heading"
            className="cosmos-card fade-up stagger-4 p-5"
          >
            <div className="flex items-center justify-between gap-2">
              <div className="flex items-center gap-2.5">
                <Trophy aria-hidden="true" className="size-5 text-amber-400" />
                <h2
                  id="achievements-heading"
                  className="font-display text-base font-extrabold text-ink"
                >{t('dashboard.myAchievements')}</h2>
              </div>
              <button
                type="button"
                aria-label={t('dashboard.viewResults')}
                onClick={onOpenProgress}
                className="grid size-8 cursor-pointer place-items-center rounded-full border border-hairline bg-sand text-slatefine transition-colors hover:bg-sand hover:text-ink"
              >
                <ArrowRight aria-hidden="true" className="size-4" />
              </button>
            </div>

            <div className="mt-4 grid grid-cols-3 gap-2.5 text-center">
              {/* Badge 1: Streak */}
              <div className="flex flex-col items-center rounded-2xl border border-hairline bg-sand p-2.5">
                <div className="grid size-13 place-items-center rounded-2xl bg-gradient-to-br from-amber-300 via-amber-500 to-orange-600 text-white shadow-lg shadow-amber-500/30">
                  <Star aria-hidden="true" className="size-6 fill-white" />
                </div>
                <p className="mt-2 text-xs font-extrabold text-ink">
                  {profile?.streakDays ?? 0}{t('courses.day')}</p>
                <p className="text-[10px] text-slatefine">{t('dashboard.consecutiveLower')}</p>
              </div>

              {/* Badge 2: Completed Lessons */}
              <div className="flex flex-col items-center rounded-2xl border border-hairline bg-sand p-2.5">
                <div className="grid size-13 place-items-center rounded-2xl bg-gradient-to-br from-indigo-400 via-purple-500 to-amber-500 text-white shadow-lg shadow-purple-500/30">
                  <BookOpen aria-hidden="true" className="size-6" />
                </div>
                <p className="mt-2 text-xs font-extrabold text-ink">
                  {totalCompletedAllCourses}{' '}{t('courses.lesson')}</p>
                <p className="text-[10px] text-slatefine">{t('dashboard.completed')}</p>
              </div>

              {/* Badge 3: Mastery / XP */}
              <div className="flex flex-col items-center rounded-2xl border border-hairline bg-sand p-2.5">
                <div className="grid size-13 place-items-center rounded-2xl bg-gradient-to-br from-fuchsia-400 via-purple-600 to-indigo-700 text-white shadow-lg shadow-fuchsia-500/30">
                  <Gem aria-hidden="true" className="size-6" />
                </div>
                <p className="mt-2 text-xs font-extrabold text-ink">
                  {masteredSkillsCount > 0
                    ? t('dynamic.masteredTopics', { count: masteredSkillsCount })
                    : `${profile?.xp ?? 0} XP`}
                </p>
                <p className="text-[10px] text-slatefine">{t('dashboard.excellent')}</p>
              </div>
            </div>
          </section>
        </div>
      </div>

      {/* =====================================================================
          BOTTOM ROW: Davom eting | Umumiy rivojlanish | Haftalik natija
         ===================================================================== */}
      <div className="grid items-stretch gap-5 lg:grid-cols-12">
        {/* BOTTOM 1: DAVOM ETING */}
        <section
          aria-labelledby="continue-card-heading"
          className="fade-up stagger-4 flex flex-col justify-between space-y-3 lg:col-span-5"
        >
          <h2
            id="continue-card-heading"
            className="font-display text-lg font-extrabold tracking-tight text-ink"
          >{t('dashboard.continue')}</h2>

          <div className="cosmos-card flex flex-1 items-center gap-4 p-4">
            {/* Lesson Media Thumbnail */}
            <div className="relative grid h-24 w-28 shrink-0 place-items-center overflow-hidden rounded-2xl border border-purple-300/25 bg-gradient-to-br from-[#312E81] via-[#4C1D95] to-[#1E1B4B] sm:w-32">
              <div
                aria-hidden="true"
                className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_30%_25%,rgba(56,189,248,0.35),transparent_60%)]"
              />
              <button
                type="button"
                aria-label={t('dashboard.currentLesson')}
                onClick={() =>
                  !started
                    ? onOpenCourses()
                    : nextId
                    ? onContinueLesson(nextId)
                    : onOpenRoadmap()
                }
                className="relative z-10 grid size-10 cursor-pointer place-items-center rounded-full bg-white/90 text-[#4F46E5] shadow-lg transition-transform hover:scale-105"
              >
                <Play aria-hidden="true" className="size-4 fill-[#4F46E5]" />
              </button>
              <span className="absolute right-1.5 bottom-1.5 rounded-md bg-slate-950/75 px-1.5 py-0.5 font-mono text-[10px] font-bold text-white">
                {nextTopic?.estimatedMinutes ?? 12}:00
              </span>
            </div>

            <div className="min-w-0 flex-1 space-y-2">
              <h3 className="line-clamp-2 font-display text-sm font-extrabold leading-snug text-ink sm:text-base">
                {nextTitle}
              </h3>
              <p className="truncate text-xs font-medium text-slatefine">
                {course?.title ?? t('dashboard.mainSubject')} · {completed + 1}{t('path.topicNumber')}</p>

              <div className="flex items-center gap-2.5 pt-1">
                <div className="h-2 flex-1 overflow-hidden rounded-full bg-sand">
                  <div
                    className="h-full rounded-full bg-gradient-to-r from-emerald-400 to-cyan-400"
                    style={{ width: `${progressPct}%` }}
                  />
                </div>
                <span className="font-mono text-xs font-extrabold text-slatefine">
                  {progressPct}%
                </span>
                <button
                  type="button"
                  aria-label={t('tutor.lesson')}
                  onClick={() =>
                    !started
                      ? onOpenCourses()
                      : nextId
                      ? onContinueLesson(nextId)
                      : onOpenRoadmap()
                  }
                  className="grid size-8 shrink-0 cursor-pointer place-items-center rounded-full bg-gradient-to-br from-[#8B5CF6] to-[#6366F1] text-white shadow-md shadow-purple-500/35"
                >
                  <Play aria-hidden="true" className="size-3.5 fill-white" />
                </button>
              </div>

              {!nextId && !roadmapLoading && !roadmapError && skills.length > 0 && (
                <div className="pt-1">
                  <button
                    type="button"
                    disabled={generating}
                    onClick={() => void generate()}
                    className="cursor-pointer text-xs font-bold text-path hover:text-ink disabled:opacity-50"
                  >
                    {generating
                      ? t('dashboard.generating')
                      : t('dashboard.generate')}
                  </button>
                </div>
              )}
              {generationError && (
                <p role="alert" className="text-xs text-rose-300">
                  {generationError}
                </p>
              )}
            </div>
          </div>
        </section>

        {/* BOTTOM 2: UMUMIY RIVOJLANISH */}
        <section
          aria-labelledby="overall-progress-heading"
          className="cosmos-card fade-up stagger-5 flex flex-col justify-between p-5 lg:col-span-4"
        >
          <div className="flex items-center gap-2">
            <ChartNoAxesColumn aria-hidden="true" className="size-4.5 text-path" />
            <h2
              id="overall-progress-heading"
              className="font-display text-base font-extrabold text-ink"
            >{t('dashboard.overall')}</h2>
          </div>

          <div className="mt-4 flex items-center gap-5">
            {/* Glowing SVG Donut */}
            <div className="relative grid size-26 shrink-0 place-items-center">
              <svg viewBox="0 0 100 100" aria-hidden="true" className="-rotate-90 size-full">
                <defs>
                  <linearGradient id="cosmosDonutGrad" x1="0%" y1="0%" x2="100%" y2="100%">
                    <stop offset="0%" stopColor="#10B981" />
                    <stop offset="50%" stopColor="#22D3EE" />
                    <stop offset="100%" stopColor="#A855F7" />
                  </linearGradient>
                </defs>
                <circle
                  cx="50"
                  cy="50"
                  r="40"
                  fill="none"
                  stroke="rgba(255,255,255,0.08)"
                  strokeWidth="10"
                />
                <circle
                  cx="50"
                  cy="50"
                  r="40"
                  fill="none"
                  stroke="url(#cosmosDonutGrad)"
                  strokeWidth="10"
                  strokeLinecap="round"
                  pathLength="100"
                  strokeDasharray={`${overallMastery} 100`}
                />
              </svg>
              <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
                <span className="font-display text-xl font-extrabold text-ink">
                  {overallMastery}%
                </span>
                <span className="text-[10px] font-semibold text-slatefine">{t('dashboard.total')}</span>
              </div>
            </div>

            <div className="min-w-0 flex-1 space-y-2.5 text-xs">
              <div className="flex items-center justify-between gap-2">
                <span className="flex items-center gap-2 text-slatefine">
                  <span className="size-2.5 rounded-full bg-emerald-400 shadow-[0_0_8px_#34D399]" />{t('dashboard.completedLessons')}</span>
                <strong className="font-mono font-extrabold text-ink">
                  {totalCompletedAllCourses}
                </strong>
              </div>
              <div className="flex items-center justify-between gap-2">
                <span className="flex items-center gap-2 text-slatefine">
                  <span className="size-2.5 rounded-full bg-purple-400 shadow-[0_0_8px_#C084FC]" />{t('path.evaluatedTopics')}</span>
                <strong className="font-mono font-extrabold text-ink">
                  {scoreValues.length}
                </strong>
              </div>
              <div className="flex items-center justify-between gap-2">
                <span className="flex items-center gap-2 text-slatefine">
                  <span className="size-2.5 rounded-full bg-cyan-400 shadow-[0_0_8px_#22D3EE]" />{t('progress.achievements')}</span>
                <strong className="font-mono font-extrabold text-ink">
                  {earnedBadgesCount}
                </strong>
              </div>
            </div>
          </div>
        </section>

        {/* BOTTOM 3: HAFTALIK NATIJA */}
        <section
          aria-labelledby="weekly-result-heading"
          className="cosmos-card fade-up stagger-6 flex flex-col justify-between p-5 lg:col-span-3"
        >
          <div className="flex items-center gap-2">
            <ChartNoAxesColumn aria-hidden="true" className="size-4.5 text-brand-dark" />
            <h2
              id="weekly-result-heading"
              className="font-display text-base font-extrabold text-ink"
            >{t('dashboard.weekly')}</h2>
          </div>

          <div className="mt-4">
            {activityFailed ? (
              <div role="alert" className="space-y-2 text-sm text-slatefine">
                <p>{t('progress.activityFailed')}</p>
                <Button variant="outline" size="sm" onClick={() => setActivityRetry((count) => count + 1)}>
                  {t('courses.retry')}
                </Button>
              </div>
            ) : activity === null ? (
              <p role="status" className="text-sm text-slatefine">{t('common.loading')}</p>
            ) : <WeeklyActivity days={activity} />}
          </div>
        </section>
      </div>

      {/* MOBILE PREMIUM TA'LIM CARD (shown on <1024px where sidebar is hidden) */}
      <section
        aria-label={t('dashboard.premium')}
        className="fade-up relative overflow-hidden rounded-3xl border border-purple-400/30 bg-gradient-to-b from-[#231B59]/90 via-[#1A1545]/95 to-[#141138] p-5 shadow-[0_14px_34px_-8px_rgba(124,58,237,0.35)] lg:hidden"
      >
        <div
          aria-hidden="true"
          className="pointer-events-none absolute -top-8 -right-8 size-28 rounded-full bg-purple-500/25 blur-2xl"
        />
        <div className="flex items-center justify-between gap-2">
          <span className="inline-flex size-10 items-center justify-center rounded-xl bg-amber-400/15 text-amber-300 shadow-inner">
            <Crown aria-hidden="true" className="size-5" />
          </span>
          <span className="inline-flex items-center gap-1 rounded-full border border-amber-400/35 bg-amber-400/15 px-3 py-1 text-xs font-extrabold text-amber-200">
            <Clock aria-hidden="true" className="size-3.5" />{t('dashboard.soon')}</span>
        </div>
        <h2 className="mt-3 font-display text-lg font-extrabold text-white">{t('dashboard.premium')}</h2>
        <p className="mt-1 text-xs leading-relaxed text-indigo-200/80">{t('dashboard.premiumDescription')}</p>
        <button
          type="button"
          onClick={() => setPremiumSoonOpen(true)}
          className="cosmos-cta-btn mt-4 w-full py-3 px-4 text-xs"
        >{t('dashboard.subscribe')}<ArrowRight aria-hidden="true" className="size-4" />
        </button>
        {premiumSoonOpen && (
          <p
            role="status"
            aria-live="polite"
            className="fade-up mt-3 flex items-center justify-center gap-1.5 rounded-xl border border-cyan-400/35 bg-cyan-500/15 px-3 py-2.5 text-center text-xs font-bold text-cyan-200"
          >
            <Sparkles aria-hidden="true" className="size-4 shrink-0 text-cyan-300" />{t('dashboard.comingSoon')}</p>
        )}
      </section>
    </div>
  );
}
