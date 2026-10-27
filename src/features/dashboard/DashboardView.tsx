import React, { useEffect, useState } from 'react';
import {
  LayoutDashboard,
  Map,
  Compass,
  Bot,
  TrendingUp,
  User,
  Search,
  Bell,
  Flame,
  Award,
  Crown,
  ChevronRight,
  ArrowRight,
  Sparkles,
  BookOpen,
  CheckCircle2,
  XCircle,
  Clock,
  RotateCcw,
  Play,
  Target,
  Lock,
} from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { SubjectSelector } from '@/features/course-selection/SubjectSelector';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { useLessonStore } from '@/app/store/useLessonStore';
import { useAuth } from '@/core/context/AuthContext';
import { supabaseLearnerRepository } from '@/data/repositories/SupabaseLearnerRepository';
import { AnswerAttemptRecord, DailyActivitySummary } from '@/domain/repositories/ILearnerRepository';
import { SkillScoringEngine } from '@/domain/personalization/SkillScoringEngine';
import { YolchiAIMascot } from '@/presentation/components/YolchiAIMascot';
import { BilimYolLogo } from '@/presentation/components/BilimYolLogo';

interface DashboardViewProps {
  onContinueLesson: (lessonId?: string) => void;
  onOpenRoadmap: () => void;
  onOpenKnowledgeMap: () => void;
  onOpenAITutor?: () => void;
  onOpenProgress?: () => void;
  onOpenProfile?: () => void;
  onOpenPitch?: () => void;
  onOpenDemo?: () => void;
  onResetDemo: () => void;
}

export const DashboardView: React.FC<DashboardViewProps> = ({
  onContinueLesson,
  onOpenRoadmap,
  onOpenKnowledgeMap,
  onOpenAITutor,
  onOpenProgress,
  onOpenProfile,
  onOpenPitch,
  onOpenDemo,
  onResetDemo,
}) => {
  const {
    courses,
    activeCourse,
    selectCourseById,
    activeCourseSkills,
    isLoading: isCourseLoading,
    error: courseError,
  } = useCourseStore();
  const { profile } = useLearnerStore();
  const { profile: authProfile } = useAuth();
  const { loadRoadmap, roadmap } = useRoadmapStore();
  const [recentAttempts, setRecentAttempts] = useState<AnswerAttemptRecord[]>([]);
  const [weeklyActivity, setWeeklyActivity] = useState<DailyActivitySummary[]>([]);
  const [activityError, setActivityError] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [isGeneratingAILesson, setIsGeneratingAILesson] = useState(false);
  const [aiLessonError, setAiLessonError] = useState<string | null>(null);
  const activeCourseId = activeCourse?.id || null;

  useEffect(() => {
    let cancelled = false;
    setActivityError(null);
    if (activeCourseId) {
      void loadRoadmap(activeCourseId);
    }
    supabaseLearnerRepository
      .getAnswerAttempts(5)
      .then((attempts) => {
        if (cancelled) return;
        setRecentAttempts(attempts);
      })
      .catch(() => {
        if (!cancelled) setRecentAttempts([]);
      });
    supabaseLearnerRepository
      .getDailyActivity(7)
      .then((activity) => {
        if (!cancelled) setWeeklyActivity(activity);
      })
      .catch((err) => {
        if (!cancelled) {
          setWeeklyActivity([]);
          setActivityError(err instanceof Error ? err.message : 'Faollik ma’lumotlari yuklanmadi.');
        }
      });

    return () => {
      cancelled = true;
    };
  }, [activeCourseId, loadRoadmap]);

  const scores = (profile?.scoresByCourse && activeCourse) ? (profile.scoresByCourse[activeCourse.id] || {}) : {};
  const overallScore = SkillScoringEngine.computeOverallScore(scores);

  // Dynamic weak/strong skills
  let strongestScore = 0;
  let weakestSkillId = activeCourseSkills[0]?.id || `skill_${activeCourse?.id || 'gen'}_01`;
  let weakestSkillName = activeCourseSkills[0]?.name || 'Asosiy mavzu';
  let weakestScore = 100;

  activeCourseSkills.forEach((sk) => {
    const sc = scores[sk.id]?.score ?? 0;
    if (sc > strongestScore) {
      strongestScore = sc;
    }
    if (sc <= weakestScore) {
      weakestScore = sc;
      weakestSkillId = sk.id;
      weakestSkillName = sk.name;
    }
  });

  // Dynamic roadmap and lesson computation for the currently selected course
  const roadmapNodes = roadmap?.courseId === activeCourse?.id ? (roadmap?.nodes || []) : [];
  const activeNode =
    roadmapNodes.find((n) => n.status === 'reinforcement' || n.status === 'in_progress' || n.status === 'available') ||
    roadmapNodes[0] ||
    null;

  const targetLessonId = activeNode?.targetLessonId || activeCourse?.lessons?.[0] || null;
  const hasLessons = Boolean(targetLessonId || (activeCourse?.lessons && activeCourse.lessons.length > 0));

  const completedNodesCount = roadmapNodes.filter((n) => n.status === 'completed').length;
  const totalNodesCount = roadmapNodes.length;

  const moduleProgress = totalNodesCount > 0
    ? Math.round((completedNodesCount / totalNodesCount) * 100)
    : (overallScore > 0 ? overallScore : 0);
  const courseProgress = activeCourse && totalNodesCount > 0
    ? { [activeCourse.id]: moduleProgress }
    : undefined;

  const lessonCountLabel = totalNodesCount > 0
    ? `${completedNodesCount + (activeNode ? 1 : 0)}/${totalNodesCount} dars`
    : (hasLessons ? '1/1 dars' : '0 dars');

  const heroTitle = hasLessons
    ? (activeNode
        ? `${activeCourse?.title}: ${activeNode.title}`
        : `${activeCourse?.title}: Darslarni davom ettirish`)
    : `${activeCourse?.title || 'Tanlangan fan'}: Darslar tayyorlanmoqda`;

  const heroDescription = hasLessons
    ? (activeNode?.description || activeCourse?.description || 'Interaktiv darslar va amaliy mashqlar orqali oson o‘rganing.')
    : 'Ushbu fan bo‘yicha o‘quv rejasi ishlab chiqilmoqda. Yo‘lchi AI yordamida o‘zingizga mos maxsus individual dars yaratishingiz mumkin.';

  const heroBadge1 = activeCourse
    ? { icon: <BookOpen className="h-3.5 w-3.5" aria-hidden="true" />, label: activeCourse.title }
    : { icon: <BookOpen className="h-3.5 w-3.5" aria-hidden="true" />, label: 'Kurs tanlanmagan' };

  const heroBadge2 = activeCourse
    ? {
        icon: <Compass className="h-3.5 w-3.5" aria-hidden="true" />,
        label: {
          mathematics: 'Matematika',
          english: 'Ingliz tili',
          it: 'IT va kodlash',
          logic: 'Mantiq',
          other: 'Boshqa fan',
        }[activeCourse.subject],
      }
    : { icon: <Compass className="h-3.5 w-3.5" aria-hidden="true" />, label: 'Mavjud kurslar' };

  const handleCreateAILesson = async () => {
    if (!activeCourse) return;
    setAiLessonError(null);
    setIsGeneratingAILesson(true);
    try {
      const difficulty = weakestScore < 40 ? 'easy' : weakestScore > 75 ? 'hard' : 'medium';
      const createdLesson = await useLessonStore.getState().generateAILesson(
        activeCourse.id,
        weakestSkillId,
        weakestSkillName,
        difficulty
      );
      if (createdLesson) {
        onContinueLesson(createdLesson.id);
      } else {
        const storeError = useLessonStore.getState().error;
        setAiLessonError(
          storeError || 'AI dars yaratishda xatolik yuz berdi. Iltimos, qayta urinib ko‘ring.'
        );
      }
    } catch (err) {
      setAiLessonError(
        err instanceof Error && err.message
          ? err.message
          : 'AI dars yaratishda xatolik yuz berdi. Iltimos, qayta urinib ko‘ring.'
      );
    } finally {
      setIsGeneratingAILesson(false);
    }
  };

  const handleCourseSelect = (courseId: string) => {
    void selectCourseById(courseId).catch(() => undefined);
  };

  const studentName = authProfile?.firstName || profile?.firstName || profile?.name || 'O‘quvchi';
  const currentXP = profile?.xp ?? 0;
  const streakDays = profile?.streakDays ?? 0;

  // Use the daily aggregate rather than the latest in-memory attempt page.
  const DAILY_GOAL_MINUTES = profile?.dailyMinutes ?? 15;
  const todayStr = new Date().toISOString().split('T')[0];
  const todayActivity = weeklyActivity.find((d) => d.date === todayStr);
  const dailyGoalDone = Math.min(todayActivity?.activeMinutes ?? 0, DAILY_GOAL_MINUTES);

  // Loss-aversion: a streak is at risk when the learner has an active streak
  // but has not done any activity today yet.
  const didActivityToday = Boolean(todayActivity?.activeMinutes);
  const atRiskStreak = streakDays > 0 && !didActivityToday;

  // Weekly study hours derived from real daily activity (minutes → hours).
  const dayNames = ['Yak', 'Dsh', 'Ssh', 'Chor', 'Pay', 'Jum', 'Shan'];
  const totalMinutes = weeklyActivity.reduce((acc, d) => acc + d.activeMinutes, 0);
  const weeklyStudyHours = weeklyActivity.map((d) => {
    const hours = Math.round((d.activeMinutes / 60) * 10) / 10;
    return {
      day: dayNames[new Date(d.date + 'T00:00:00').getDay()] || '',
      hours,
      peak: false as boolean,
    };
  });
  const maxWeeklyHours = Math.max(...weeklyStudyHours.map((d) => d.hours), 1);
  weeklyStudyHours.forEach((d) => {
    if (d.hours === maxWeeklyHours && d.hours > 0) d.peak = true;
  });

  // Keep recommendations grounded in the loaded course catalog. Lesson counts
  // are shown only when the course relation actually provides them.
  const recommendations = activeCourse
    ? [{
        id: activeCourse.id,
        title: activeCourse.title,
        desc: activeCourse.lessons.length > 0
          ? `${activeCourse.lessons.length} ta dars mavjud`
          : 'Darslar haqida ma’lumot yo‘q',
        icon: <BookOpen className="h-5 w-5" aria-hidden="true" />,
        colorClass: 'bg-blue-50 border-blue-200/80 text-blue-600',
      }]
    : [];

  // Real recent results derived from actual answer attempts (latest first).
  const subjectRecentResults = recentAttempts
    .slice()
    .reverse()
    .slice(0, 3)
    .map((a) => ({
      title: a.questionId.replace(/_/g, ' '),
      xp: a.isCorrect ? '+2 XP' : '0 XP',
      isCorrect: a.isCorrect,
    }));

  // Search filters the recommendation cards by title.
  const filteredRecommendations = searchQuery.trim()
    ? recommendations.filter((r) =>
        r.title.toLowerCase().includes(searchQuery.trim().toLowerCase()) ||
        r.desc.toLowerCase().includes(searchQuery.trim().toLowerCase())
      )
    : recommendations;

  return (
    <div className="min-h-screen bg-[#fbf9f4] text-slate-900 flex flex-col lg:flex-row lab-grid-bg">
      {/* 1. LEFT SIDEBAR: Neo-Editorial Lab Navigation Console */}
      <aside className="hidden lg:flex w-64 bg-white border-r border-[#e4ddce] flex-col justify-between shrink-0 p-5 sticky top-0 h-screen overflow-y-auto">
        <div className="space-y-6">
          {/* Logo with clean editorial subtitle */}
          <div className="px-1 pt-1">
            <BilimYolLogo size="md" />
          </div>

          {/* Navigation Links */}
          <nav className="space-y-1">
            <div className="px-3 pb-1 text-[10px] font-mono font-bold uppercase tracking-widest text-slate-500">
              Menyu
            </div>

            <button
              type="button"
              aria-current="page"
              className="w-full flex items-center gap-3 px-3.5 py-2.5 rounded-xl text-xs font-bold bg-[#10151f] text-white shadow-xs transition-all cursor-default"
            >
              <LayoutDashboard className="w-4 h-4 text-path" />
              <span>Bosh sahifa</span>
            </button>

            <button
              onClick={onOpenRoadmap}
              className="w-full flex items-center gap-3 px-3.5 py-2.5 rounded-xl text-xs font-bold text-slate-700 hover:text-slate-950 hover:bg-[#f5efe4] transition-all cursor-pointer"
            >
              <Map className="w-4 h-4 text-slate-400" />
              <span>Ta’lim yo‘li</span>
            </button>

            <button
              onClick={onOpenKnowledgeMap}
              className="w-full flex items-center gap-3 px-3.5 py-2.5 rounded-xl text-xs font-bold text-slate-700 hover:text-slate-950 hover:bg-[#f5efe4] transition-all cursor-pointer"
            >
              <Compass className="w-4 h-4 text-slate-400" />
              <span>Bilim xaritasi</span>
            </button>

            <button
              onClick={onOpenAITutor}
              className="w-full flex items-center gap-3 px-3.5 py-2.5 rounded-xl text-xs font-bold text-slate-700 hover:text-slate-950 hover:bg-[#f5efe4] transition-all cursor-pointer"
            >
              <Bot className="w-4 h-4 text-slate-400" />
              <span>Yo‘lchi AI</span>
            </button>

            <button
              onClick={onOpenProgress}
              className="w-full flex items-center gap-3 px-3.5 py-2.5 rounded-xl text-xs font-bold text-slate-700 hover:text-slate-950 hover:bg-[#f5efe4] transition-all cursor-pointer"
            >
              <TrendingUp className="w-4 h-4 text-slate-400" />
              <span>Natijalar</span>
            </button>

            <button
              onClick={onOpenProfile || onOpenProgress}
              className="w-full flex items-center gap-3 px-3.5 py-2.5 rounded-xl text-xs font-bold text-slate-700 hover:text-slate-950 hover:bg-[#f5efe4] transition-all cursor-pointer"
            >
              <User className="w-4 h-4 text-slate-400" />
              <span>Profil</span>
            </button>

            {/* Pitch Day 3.0 & /demo links */}
            {(onOpenPitch || onOpenDemo) && (
              <div className="pt-3 mt-2 border-t border-[#f0ece3] space-y-1">
                {onOpenPitch && (
                  <button
                    onClick={onOpenPitch}
                    className="w-full flex items-center gap-2.5 px-3 py-2 rounded-xl text-xs font-bold bg-brand/8 text-brand-dark border border-brand/25 hover:bg-brand/10 transition-all cursor-pointer"
                  >
                    <Sparkles className="w-3.5 h-3.5 text-brand" />
                    <span>Pitch Day 3.0</span>
                  </button>
                )}

                {onOpenDemo && (
                  <button
                    onClick={onOpenDemo}
                    className="w-full flex items-center gap-2.5 px-3 py-2 rounded-xl text-xs font-bold bg-mint/10 hover:bg-mint/10 text-mint border border-mint/30 transition-all cursor-pointer"
                  >
                    <Play className="w-3.5 h-3.5 text-mint fill-mint" />
                    <span>/demo Sahifasi</span>
                  </button>
                )}
              </div>
            )}
          </nav>
        </div>

        {/* Sidebar Bottom: Lab Level & XP Ledger */}
        <div className="space-y-3 pt-4 border-t border-[#f0ece3]">
          <div className="p-3.5 rounded-xl bg-[#fbf9f4] border border-[#e4ddce] text-slate-900 space-y-2">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Crown className="w-4 h-4 text-amber-500 fill-amber-500" />
                <span className="font-mono text-xs font-bold text-slate-900">{currentXP} XP</span>
              </div>
              <span className="font-mono text-[9px] font-bold px-2 py-0.5 rounded bg-white text-slate-700 border border-[#e4ddce]">
                {Math.floor(currentXP / 100) + 1}-DARAJA
              </span>
            </div>
            <div className="h-1.5 w-full bg-[#ece5d8] rounded-full overflow-hidden">
              <div
                className="h-full bg-[#10151f] rounded-full transition-all"
                style={{ width: `${currentXP % 100}%` }}
              />
            </div>
            <p className="font-mono text-[10px] text-slate-500 font-medium">
              Keyingi darajaga: {100 - (currentXP % 100)} XP
            </p>
          </div>

          <button
            onClick={onResetDemo}
            className="w-full flex items-center gap-2.5 px-3 py-2 rounded-xl text-xs font-bold text-slate-600 hover:text-slate-900 hover:bg-[#f5efe4] transition-colors cursor-pointer"
          >
            <RotateCcw className="w-4 h-4 text-slate-400" />
            <span>Kursni qayta boshlash</span>
          </button>
        </div>
      </aside>

      {/* 2. MAIN CONTENT AREA */}
      <main className="flex-1 p-4 sm:p-6 lg:p-8 max-w-7xl mx-auto w-full space-y-6">
        
        {/* TOP COMMAND BAR: Search Input, Notifications & Profile Avatar */}
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-4">
          {/* Search bar */}
          <div className="relative flex-1 max-w-xl">
            <Search className="w-4 h-4 text-slate-400 absolute left-4 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Dars, mavzu yoki savolni qidirish..."
              aria-label="Kurslar va mavzularni qidirish"
              className="w-full pl-11 pr-4 py-2.5 sm:py-3 bg-white border border-[#e4ddce] rounded-xl text-xs sm:text-sm text-slate-900 placeholder:text-slate-400 font-medium focus:outline-none focus:ring-2 focus:ring-brand focus:border-brand transition-all shadow-2xs"
            />
          </div>

          {/* Right side notifications & avatar */}
          <div className="flex items-center justify-end gap-2.5 shrink-0">
            <button
              onClick={onOpenProgress}
              className="p-2.5 sm:p-3 rounded-xl bg-white border border-[#e4ddce] text-slate-700 hover:bg-[#f5efe4] transition-colors shadow-2xs relative cursor-pointer"
              title="Natijalar va bildirishnomalar"
              aria-label="Natijalar va bildirishnomalar"
            >
              <Bell className="w-4 h-4" />
              {(atRiskStreak || recentAttempts.length > 0) && (
                <span className="absolute top-2 right-2 w-2 h-2 rounded-full bg-coral ring-2 ring-white" />
              )}
            </button>

            <button
              onClick={onOpenProfile || onOpenProgress}
              className="flex items-center gap-2.5 pl-2 pr-3 py-1.5 rounded-xl bg-white border border-[#e4ddce] hover:bg-[#f5efe4] transition-colors shadow-2xs cursor-pointer"
            >
              <div className="w-7 h-7 rounded-lg bg-[#10151f] flex items-center justify-center text-white font-mono font-bold text-xs">
                {studentName.charAt(0)}
              </div>
              <div className="text-left hidden sm:block">
                <div className="text-xs font-bold text-slate-900 leading-none">{studentName}</div>
                <div className="text-[10px] font-mono text-slate-500 mt-0.5">O‘quvchi</div>
              </div>
            </button>
          </div>
        </div>

        {/* ROW 1: Learner Welcome Docket + Goals + Streak + XP Telemetry */}
        <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-5 bg-white p-6 rounded-2xl border border-[#e4ddce] shadow-sm">
          <div className="space-y-1.5">
            <div className="flex items-center gap-2">
              <span className="editorial-kicker">Laboratoriya // Shaxsiy ta’lim yo‘li</span>
              <span className="inline-block w-1.5 h-1.5 rounded-full bg-mint lab-pulse" />
            </div>
            <h1 className="font-display text-2xl sm:text-3xl font-bold text-slate-900 tracking-tight">
              Assalomu alaykum, {studentName}!
            </h1>
            <p className="text-xs sm:text-sm text-slate-600 font-medium">
              Darslik emas — shaxsiy ta’lim yo‘li. Bugungi mashg‘ulotlarni davom ettiring.
            </p>
          </div>

          {/* 3 Metric Tablets */}
          <div className="flex flex-wrap items-center gap-3">
            {/* Bugungi maqsad */}
            <div className="flex items-center gap-3 px-3.5 py-2.5 rounded-xl bg-[#fbf9f4] border border-[#e4ddce]">
              <div className="w-8 h-8 rounded-lg bg-brand/8 border border-brand/25 flex items-center justify-center text-brand shrink-0">
                <Target className="w-4 h-4" />
              </div>
              <div>
                <div className="text-[10px] font-mono font-bold uppercase tracking-wider text-slate-500">Bugungi maqsad</div>
                <div className="font-mono text-xs font-bold text-slate-900">{dailyGoalDone}/{DAILY_GOAL_MINUTES} daqiqa</div>
              </div>
            </div>

            {/* Streak */}
            <div className="flex items-center gap-3 px-3.5 py-2.5 rounded-xl bg-[#fff8ed] border border-[#f59f00]/30">
              <div className="w-8 h-8 rounded-lg bg-amber-100 flex items-center justify-center text-amber-600 shrink-0">
                <Flame className="w-4 h-4 fill-amber-500 text-amber-500" />
              </div>
              <div>
                <div className="text-[10px] font-mono font-bold uppercase tracking-wider text-amber-800">{streakDays} kun</div>
                <div className="font-mono text-xs font-bold text-amber-950">Ketma-ketlik</div>
              </div>
            </div>

            {/* XP */}
            <div className="flex items-center gap-3 px-3.5 py-2.5 rounded-xl bg-[#eef2ff] border border-[#3550d6]/30">
              <div className="w-8 h-8 rounded-lg bg-brand/10 flex items-center justify-center text-brand shrink-0">
                <Award className="w-4 h-4 text-brand" />
              </div>
              <div>
                <div className="text-[10px] font-mono font-bold uppercase tracking-wider text-brand-dark">{currentXP} XP</div>
                <div className="font-mono text-xs font-bold text-brand-dark">Umumiy Ball</div>
              </div>
            </div>
          </div>
        </div>

        {/* AT_RISK: loss-aversion streak reminder */}
        {atRiskStreak && (
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 p-4 rounded-2xl bg-[#fff8ed] border border-[#f59f00]/40 shadow-2xs">
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 rounded-xl bg-amber-100 border border-amber-300 flex items-center justify-center shrink-0">
                <Flame className="w-5 h-5 fill-amber-500 text-amber-500" />
              </div>
              <div>
                <div className="text-xs sm:text-sm font-bold text-amber-950 flex items-center gap-1.5">
                  <Flame className="w-4 h-4 fill-amber-500 text-amber-500" />
                  {streakDays} kunlik seriyangiz xavf ostida!
                </div>
                <div className="text-[11px] sm:text-xs font-medium text-amber-800">
                  Seriyani saqlab qolish uchun bugun kamida 1 ta dars yoki savol bajaring.
                </div>
              </div>
            </div>
            <button
              onClick={() => onContinueLesson(targetLessonId || undefined)}
              className="shrink-0 px-4 py-2 rounded-xl bg-[#10151f] hover:bg-[#2a3342] text-white font-bold text-xs shadow-xs transition-colors cursor-pointer"
            >
              Boshlash
            </button>
          </div>
        )}

        {/* ROW 2: Subject Dossier Selector */}
        <section className="space-y-3" aria-labelledby="dashboard-course-selector-heading">
          <div className="flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <p className="editorial-kicker">Tezkor almashtirish</p>
              <h2 id="dashboard-course-selector-heading" className="mt-0.5 font-display text-lg font-bold text-slate-950 tracking-tight">
                O‘rganish yo‘nalishi
              </h2>
            </div>
            <button
              type="button"
              onClick={onOpenRoadmap}
              className="inline-flex items-center gap-1.5 self-start rounded-lg px-2 py-1 text-xs font-bold text-brand outline-none transition-colors hover:text-brand-dark sm:self-auto"
            >
              Yo‘l xaritasini ko‘rish
              <ArrowRight className="h-3.5 w-3.5" aria-hidden="true" />
            </button>
          </div>
          <SubjectSelector
            courses={courses}
            selectedCourseId={activeCourseId}
            isLoading={isCourseLoading}
            error={courseError}
            progressByCourseId={courseProgress}
            onSelect={handleCourseSelect}
            layout="horizontal"
            ariaLabel="Yuklangan kurslar bo‘yicha tezkor tanlov"
          />
        </section>

        {/* ROW 3: HERO MISSION CARD "DAVOM ETISH" — Neo-Editorial High-Contrast Docket */}
        <div className="relative rounded-2xl overflow-hidden editorial-ink-hero text-white p-6 sm:p-8 lg:p-9 border border-white/10">
          <div className="relative z-10 grid grid-cols-1 lg:grid-cols-12 gap-6 items-center">
            {/* Left text column */}
            <div className="lg:col-span-7 space-y-4">
              <div className="flex flex-wrap items-center gap-2">
                <span className="px-2.5 py-0.5 rounded bg-white/10 border border-white/20 text-path font-mono text-[10px] font-bold uppercase tracking-wider">
                  {hasLessons ? 'DAVOM ETISH' : 'YANGI FAN'}
                </span>
                <span className="font-mono text-xs font-medium text-slate-300">
                  {activeCourse?.title || 'Fan'} • {lessonCountLabel}
                </span>
              </div>

              <h2 className="font-display text-2xl sm:text-3xl lg:text-4xl font-bold text-white tracking-tight leading-tight">
                {heroTitle}
              </h2>

              <p className="text-xs sm:text-sm text-slate-300 font-medium leading-relaxed max-w-lg">
                {heroDescription}
              </p>

              {/* Dynamic Progress bar */}
              <div className="space-y-1.5 max-w-md pt-2">
                <div className="flex items-center justify-between text-xs font-mono font-medium text-slate-300">
                  <span>Modul o‘zlashtirishi</span>
                  <span className="text-white font-bold">{moduleProgress}%</span>
                </div>
                <div className="h-2 w-full bg-white/15 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-gradient-to-r from-path via-path to-mint rounded-full transition-all duration-500"
                    style={{ width: `${Math.max(moduleProgress, hasLessons ? 5 : 0)}%` }}
                  />
                </div>
              </div>

              {/* Action Button: Continue Lesson or Generate Lesson */}
              <div className="pt-2">
                {hasLessons ? (
                  <button
                    onClick={() => onContinueLesson(targetLessonId || undefined)}
                    className="px-6 py-3 rounded-xl bg-white hover:bg-slate-100 text-slate-950 font-bold text-xs sm:text-sm shadow-md flex items-center gap-2 hover:scale-[1.02] active:scale-[0.98] transition-all cursor-pointer"
                  >
                    <span>Davom etish</span>
                    <ArrowRight className="w-4 h-4 text-brand" />
                  </button>
                ) : (
                  <button
                    onClick={handleCreateAILesson}
                    disabled={isGeneratingAILesson}
                    className="px-6 py-3 rounded-xl bg-gradient-to-r from-path via-path to-mint hover:brightness-105 text-slate-950 font-bold text-xs sm:text-sm shadow-md flex items-center gap-2 hover:scale-[1.02] active:scale-[0.98] transition-all cursor-pointer disabled:opacity-75"
                  >
                    {isGeneratingAILesson ? (
                      <>
                        <RotateCcw className="w-4 h-4 animate-spin text-slate-950" />
                        <span>AI dars yaratmoqda...</span>
                      </>
                    ) : (
                      <>
                        <Sparkles className="w-4 h-4 text-slate-950" />
                        <span>Dars yaratish (Yo‘lchi AI)</span>
                      </>
                    )}
                  </button>
                )}

                {/* Clear, recoverable error when AI lesson generation fails */}
                {aiLessonError && !isGeneratingAILesson && (
                  <div className="mt-3 max-w-md p-3.5 bg-rose-500/20 border border-rose-300/40 rounded-xl flex items-start justify-between gap-3">
                    <span className="text-xs text-coral font-medium leading-relaxed">
                      {aiLessonError}
                    </span>
                    <button
                      type="button"
                      onClick={() => setAiLessonError(null)}
                      className="text-coral hover:text-white text-xs font-bold shrink-0 cursor-pointer"
                      aria-label="Xabarni yopish"
                    >
                      ✕
                    </button>
                  </div>
                )}
              </div>
            </div>

            {/* Right Artwork column with dynamic badges */}
            <div className="lg:col-span-5 flex justify-center lg:justify-end">
              <div className="relative w-full max-w-sm rounded-xl overflow-hidden border border-white/20 shadow-xl bg-slate-950/40 group">
                <img
                  src="/images/dashboard_hero_student.jpg"
                  alt={`${activeCourse?.title || 'Dars'} qahramoni`}
                  className="w-full h-48 sm:h-56 lg:h-60 object-cover object-center group-hover:scale-105 transition-transform duration-700 ease-out"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-slate-950/80 via-transparent to-transparent pointer-events-none" />
                
                {/* Dynamic Subject Glass Badges */}
                <div className="absolute top-3 left-3 px-2.5 py-1 rounded-lg bg-black/40 backdrop-blur-md border border-white/20 text-white font-mono font-bold text-[10px] flex items-center gap-1.5 shadow-sm">
                  <span>{heroBadge1.icon}</span>
                  <span className="text-path">{heroBadge1.label}</span>
                </div>
                <div className="absolute bottom-3 right-3 px-2.5 py-1 rounded-lg bg-indigo-600/90 backdrop-blur-md border border-indigo-400/40 text-white font-mono font-bold text-[10px] flex items-center gap-1.5 shadow-sm">
                  <span>{heroBadge2.icon}</span>
                  <span className="text-white">{heroBadge2.label}</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* ROW 4: "Siz uchun tavsiya" Recommendations */}
        <div className="space-y-3">
          <div className="flex items-center justify-between">
            <h3 className="font-display text-base font-bold text-slate-900 tracking-tight">
              Siz uchun tavsiya
            </h3>
            <button
              onClick={onOpenRoadmap}
              className="text-xs font-bold text-brand hover:text-brand-dark flex items-center gap-1 cursor-pointer transition-colors"
            >
              Barchasini ko‘rish →
            </button>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            {filteredRecommendations.length === 0 ? (
              <div className="sm:col-span-3 p-6 rounded-2xl bg-white border border-[#e4ddce] text-center">
                <p className="text-xs font-medium text-slate-500">
                  {activeCourse
                    ? `“${searchQuery}” bo‘yicha hech narsa topilmadi.`
                    : 'Kurs tanlang — tavsiyalar shu yerda ko‘rinadi.'}
                </p>
              </div>
            ) : (
              filteredRecommendations.map((rec) => (
                <button
                  key={rec.id}
                  type="button"
                  onClick={onOpenRoadmap}
                  className="flex w-full items-center justify-between gap-3 rounded-2xl border border-[#e4ddce] bg-white p-4 text-left shadow-2xs outline-none transition-all hover:-translate-y-0.5 hover:border-slate-400 hover:shadow-sm"
                  aria-label={`${rec.title} yo‘l xaritasini ochish`}
                >
                  <span className="flex items-center gap-3">
                    <span className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border ${rec.colorClass}`}>
                      {rec.icon}
                    </span>
                    <span>
                      <span className="block font-display text-sm font-bold leading-snug text-slate-900">
                        {rec.title}
                      </span>
                      <span className="block font-mono text-[11px] font-medium text-slate-500">{rec.desc}</span>
                    </span>
                  </span>
                  <ChevronRight className="w-4 h-4 text-slate-400" />
                </button>
              ))
            )}
          </div>
        </div>

        {/* ROW 5: 4-WIDGET LABORATORY GRID */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          
          {/* Widget 1: Yo'lchi AI Mentor — signature ink panel */}
          <div className="ink-panel p-5 rounded-2xl flex flex-col justify-between space-y-4">
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <span className="font-mono text-[10px] font-bold uppercase tracking-widest text-path">Yo‘lchi AI</span>
                  <span className="font-mono text-[9px] font-bold px-1.5 py-0.5 rounded bg-white/10 text-white/75 border border-white/15">
                    AI Pedagog
                  </span>
                </div>
              </div>

              {/* Robot Mascot & Chat Bubble */}
              <div className="flex items-start gap-3 pt-1">
                <YolchiAIMascot size="sm" mood="explaining" />
                <div className="p-3 rounded-xl rounded-tl-none bg-white/5 border border-white/10 text-xs text-white/75 font-medium leading-relaxed">
                  Bugun qaysi mavzuni birga o‘rganamiz? Savollaringizga bosqichma-bosqich javob beraman.
                </div>
              </div>
            </div>

            <button
              onClick={onOpenAITutor}
              className="w-full py-2.5 px-4 rounded-xl bg-white hover:bg-slate-100 text-ink font-bold text-xs shadow-xs transition-all flex items-center justify-center gap-1.5 cursor-pointer"
            >
              <span>Chatni ochish</span>
              <ArrowRight className="w-3.5 h-3.5" />
            </button>
          </div>

          {/* Widget 2: Bilim xaritasi */}
          <div className="bg-white p-5 rounded-2xl border border-[#e4ddce] border-t-2 border-t-path shadow-sm flex flex-col justify-between space-y-4">
            <div className="space-y-2.5">
              <div className="flex items-center gap-2">
                <Compass className="w-4 h-4 text-brand" />
                <h4 className="font-display text-sm font-bold text-slate-900">Bilim xaritasi</h4>
              </div>
              <p className="text-xs text-slate-600 font-medium leading-relaxed">
                O‘z bilim darajangizni ko‘ring va keyingi mavzularni oching.
              </p>

              {/* Connected node graph illustration */}
              <div className="h-16 w-full rounded-xl bg-[#fbf9f4] border border-[#e4ddce] flex items-center justify-center p-2 relative overflow-hidden">
                <div className="flex items-center justify-between w-4/5 relative">
                  <div className="absolute top-1/2 left-0 right-0 h-1 bg-gradient-to-r from-blue-500 via-path to-mint -translate-y-1/2 z-0" />
                  <div className="w-6 h-6 rounded-full bg-blue-600 border-2 border-white shadow-xs z-10 flex items-center justify-center text-white font-mono text-[9px] font-bold">
                    1
                  </div>
                  <div className="w-6 h-6 rounded-full bg-path border-2 border-white shadow-xs z-10 flex items-center justify-center text-white font-mono text-[9px] font-bold">
                    2
                  </div>
                  <div className="w-6 h-6 rounded-full bg-mint border-2 border-white shadow-xs z-10 flex items-center justify-center text-white font-mono text-[9px] font-bold">
                    3
                  </div>
                  <div className="w-6 h-6 rounded-full bg-slate-300 border-2 border-white shadow-xs z-10 flex items-center justify-center text-white text-[9px]">
                    <Lock className="w-3 h-3" />
                  </div>
                </div>
              </div>
            </div>

            <button
              onClick={onOpenKnowledgeMap}
              className="w-full py-2.5 px-4 rounded-xl border border-[#e4ddce] hover:border-slate-400 bg-white hover:bg-[#fbf9f4] text-slate-900 font-bold text-xs transition-colors flex items-center justify-center gap-1.5 cursor-pointer"
            >
              <span>Xaritani ochish</span>
              <ArrowRight className="w-3.5 h-3.5" />
            </button>
          </div>

          {/* Widget 3: O'qish vaqti (Haftalik) */}
          <div className="bg-white p-5 rounded-2xl border border-[#e4ddce] border-t-2 border-t-mint shadow-sm flex flex-col justify-between space-y-3">
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-1.5">
                  <Clock className="w-4 h-4 text-slate-500" />
                  <h4 className="font-display text-sm font-bold text-slate-900">O‘qish vaqti</h4>
                </div>
                <button
                  onClick={onOpenProgress}
                  className="font-mono text-[10px] font-bold text-brand hover:underline cursor-pointer"
                >
                  Batafsil
                </button>
              </div>

              {/* Bar chart derived from real daily activity */}
              <div className="h-20 pt-2 flex items-end justify-between gap-1 border-b border-[#f0ece3]">
                {weeklyStudyHours.length === 0 ? (
                  <div className="w-full text-center font-mono text-[10px] text-slate-400 self-center">
                    Ma’lumot yo‘q
                  </div>
                ) : (
                  weeklyStudyHours.map((d, i) => (
                    <div key={i} className="flex-1 flex flex-col items-center gap-1 h-full justify-end">
                      <span className="font-mono text-[8px] text-slate-400">{d.hours}s</span>
                      <div
                        className={`w-full max-w-[12px] rounded-t-sm transition-all ${
                          d.peak
                            ? 'bg-[#10151f]'
                            : 'bg-path hover:bg-path'
                        }`}
                        style={{ height: `${Math.max((d.hours / maxWeeklyHours) * 100, d.hours > 0 ? 8 : 2)}%` }}
                      />
                      <span className="font-mono text-[9px] font-bold text-slate-600">{d.day}</span>
                    </div>
                  ))
                )}
              </div>
              {activityError && (
                <p role="alert" className="text-[10px] font-semibold text-coral">
                  Faollik ma’lumotlari yuklanmadi: {activityError}
                </p>
              )}
            </div>

            <div className="text-xs text-slate-600 flex items-center justify-between pt-1">
              <span>Umumiy: <strong className="font-mono text-slate-900">{(totalMinutes / 60).toFixed(1)} soat</strong></span>
              <span className="font-mono font-bold text-mint">{overallScore}%</span>
            </div>
          </div>

          {/* Widget 4: So'nggi natijalar */}
          <div className="bg-white p-5 rounded-2xl border border-[#e4ddce] border-t-2 border-t-amber shadow-sm flex flex-col justify-between space-y-3">
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <h4 className="font-display text-sm font-bold text-slate-900">So‘nggi natijalar</h4>
                <button
                  onClick={onOpenProgress}
                  className="font-mono text-[10px] font-bold text-brand hover:underline cursor-pointer"
                >
                  Barchasini ko‘rish →
                </button>
              </div>

              {/* Result items derived from real attempts */}
              <div className="space-y-2">
                {subjectRecentResults.length === 0 ? (
                  <p className="text-xs font-medium text-slate-400 py-2">
                    Hali natijalar yo‘q. Birinchi darsni boshlang!
                  </p>
                ) : (
                  subjectRecentResults.map((item, idx) => (
                    <div key={idx} className="flex items-center justify-between text-xs">
                      <div className="flex items-center gap-1.5 truncate max-w-[140px]">
                        {item.isCorrect ? (
                          <CheckCircle2 className="w-3.5 h-3.5 text-mint shrink-0" />
                        ) : (
                          <XCircle className="w-3.5 h-3.5 text-coral shrink-0" />
                        )}
                        <span className="font-mono text-[11px] text-slate-800 truncate">{item.title}</span>
                      </div>
                      <span className={`font-mono text-[11px] font-bold shrink-0 ${item.isCorrect ? 'text-mint' : 'text-slate-400'}`}>{item.xp}</span>
                    </div>
                  ))
                )}
              </div>
            </div>

            <div className="pt-2 border-t border-[#f0ece3] flex items-center justify-between text-xs text-slate-600">
              <span>Umumiy bilim:</span>
              <strong className="font-mono font-bold text-brand-dark">{overallScore}%</strong>
            </div>
          </div>

        </div>

      </main>
    </div>
  );
};
