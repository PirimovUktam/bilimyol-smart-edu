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
  Lightbulb,
  Code2,
  Clock,
  RotateCcw,
  Calculator,
  Equal,
  LineChart,
  FileText,
  Headphones,
  Cpu,
  Globe,
  Play,
} from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
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
  const { activeCourse, selectCourseById, activeCourseSkills } = useCourseStore();
  const { profile } = useLearnerStore();
  const { profile: authProfile } = useAuth();
  const { loadRoadmap, roadmap } = useRoadmapStore();
  const [recentAttempts, setRecentAttempts] = useState<AnswerAttemptRecord[]>([]);
  const [weeklyActivity, setWeeklyActivity] = useState<DailyActivitySummary[]>([]);
  const [activityError, setActivityError] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [isGeneratingAILesson, setIsGeneratingAILesson] = useState(false);
  const [aiLessonError, setAiLessonError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    setActivityError(null);
    if (activeCourse) {
      loadRoadmap(activeCourse.id);
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
  }, [activeCourse, loadRoadmap, profile]);

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

  const heroBadge1 = activeCourse?.subject === 'english'
    ? { icon: '🎧', label: 'Listening' }
    : activeCourse?.subject === 'it'
    ? { icon: '💻', label: 'Kodlash' }
    : activeCourse?.subject === 'logic'
    ? { icon: '🧩', label: 'Mantiq' }
    : { icon: '½', label: 'Funksiya' };

  const heroBadge2 = activeCourse?.subject === 'english'
    ? { icon: '🇬🇧', label: 'Interaktiv' }
    : activeCourse?.subject === 'it'
    ? { icon: '⚡', label: 'Python' }
    : activeCourse?.subject === 'logic'
    ? { icon: '🎯', label: 'Deduksiya' }
    : { icon: '📐', label: 'Interaktiv' };

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

  const subjectCategories = [
    { id: 'course_math_01', label: 'Matematika', icon: '📐', active: activeCourse?.id === 'course_math_01', pillColor: 'bg-indigo-600 text-white' },
    { id: 'course_eng_01', label: 'Ingliz tili', icon: '🇬🇧', active: activeCourse?.id === 'course_eng_01', pillColor: 'bg-rose-500 text-white' },
    { id: 'course_it', label: 'IT & Kodlash', icon: '💻', active: activeCourse?.id === 'course_it', pillColor: 'bg-cyan-500 text-white' },
    { id: 'course_logic', label: 'Mantiq', icon: '🧩', active: activeCourse?.id === 'course_logic', pillColor: 'bg-emerald-500 text-white' },
  ];

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

  // Dynamic Recommendations strictly isolated by subject
  const recommendations = activeCourse?.id === 'course_eng_01'
    ? [
        {
          id: 'rec_eng_1',
          title: 'Essential Vocabulary',
          desc: '10 dars • Lug‘at boyligi',
          icon: <BookOpen className="w-5 h-5" />,
          colorClass: 'bg-rose-50 border-rose-200/80 text-rose-600',
        },
        {
          id: 'rec_eng_2',
          title: 'Grammar & Conditionals',
          desc: '8 dars • Grammatika',
          icon: <FileText className="w-5 h-5" />,
          colorClass: 'bg-indigo-50 border-indigo-200/80 text-indigo-600',
        },
        {
          id: 'rec_eng_3',
          title: 'Listening & Pronunciation',
          desc: '12 dars • Tinglab tushunish',
          icon: <Headphones className="w-5 h-5" />,
          colorClass: 'bg-amber-50 border-amber-200/80 text-amber-600',
        },
      ]
    : activeCourse?.id === 'course_it'
    ? [
        {
          id: 'rec_it_1',
          title: 'Python asoslari',
          desc: '8 dars • Dasturlash',
          icon: <Code2 className="w-5 h-5" />,
          colorClass: 'bg-cyan-50 border-cyan-200/80 text-cyan-600',
        },
        {
          id: 'rec_it_2',
          title: 'Algoritmik mantiq',
          desc: '10 dars • Algoritmlar',
          icon: <Cpu className="w-5 h-5" />,
          colorClass: 'bg-blue-50 border-blue-200/80 text-blue-600',
        },
        {
          id: 'rec_it_3',
          title: 'Veb texnologiyalari',
          desc: '6 dars • Frontend',
          icon: <Globe className="w-5 h-5" />,
          colorClass: 'bg-emerald-50 border-emerald-200/80 text-emerald-600',
        },
      ]
    : activeCourse?.id === 'course_logic'
    ? [
        {
          id: 'rec_log_1',
          title: 'Mantiqiy fikrlash',
          desc: '12 dars • Deduksiya',
          icon: <Lightbulb className="w-5 h-5" />,
          colorClass: 'bg-amber-50 border-amber-200/80 text-amber-600',
        },
        {
          id: 'rec_log_2',
          title: 'Kombinatorika asoslari',
          desc: '8 dars • Boshqotirma',
          icon: <Sparkles className="w-5 h-5" />,
          colorClass: 'bg-purple-50 border-purple-200/80 text-purple-600',
        },
        {
          id: 'rec_log_3',
          title: 'Mantiqiy zanjirlar',
          desc: '10 dars • Tahlil',
          icon: <Compass className="w-5 h-5" />,
          colorClass: 'bg-emerald-50 border-emerald-200/80 text-emerald-600',
        },
      ]
    : [
        {
          id: 'rec_math_1',
          title: 'Algebra: Qisqa ko‘paytirish',
          desc: '8 dars • Algebra formulalari',
          icon: <Calculator className="w-5 h-5" />,
          colorClass: 'bg-blue-50 border-blue-200/80 text-blue-600',
        },
        {
          id: 'rec_math_2',
          title: 'Chiziqli tenglamalar',
          desc: '10 dars • Tenglamalar',
          icon: <Equal className="w-5 h-5" />,
          colorClass: 'bg-indigo-50 border-indigo-200/80 text-indigo-600',
        },
        {
          id: 'rec_math_3',
          title: 'Funksiyalar va grafiklar',
          desc: '12 dars • Grafik tahlili',
          icon: <LineChart className="w-5 h-5" />,
          colorClass: 'bg-emerald-50 border-emerald-200/80 text-emerald-600',
        },
      ];

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
    <div className="min-h-screen bg-[#f5f7fc] text-slate-900 flex flex-col lg:flex-row">
      {/* 1. LEFT SIDEBAR: Reference 2 Dashboard Desktop Navigation */}
      <aside className="hidden lg:flex w-64 bg-white border-r border-slate-200/80 flex-col justify-between shrink-0 p-5 sticky top-0 h-screen overflow-y-auto">
        <div className="space-y-6">
          {/* Logo at top of sidebar */}
          <div className="px-2">
            <BilimYolLogo size="md" />
          </div>

          {/* Navigation Links matching Reference */}
          <nav className="space-y-1.5">
            <button
              type="button"
              aria-current="page"
              className="w-full flex items-center gap-3 px-4 py-3 rounded-2xl text-xs font-black bg-blue-600 text-white shadow-md shadow-blue-600/25 transition-all cursor-default"
            >
              <LayoutDashboard className="w-4 h-4 text-white" />
              <span>Bosh sahifa</span>
            </button>

            <button
              onClick={onOpenRoadmap}
              className="w-full flex items-center gap-3 px-4 py-3 rounded-2xl text-xs font-bold text-slate-600 hover:text-slate-900 hover:bg-slate-100/80 transition-all cursor-pointer"
            >
              <Map className="w-4 h-4 text-slate-400" />
              <span>Ta’lim yo‘li</span>
            </button>

            <button
              onClick={onOpenKnowledgeMap}
              className="w-full flex items-center gap-3 px-4 py-3 rounded-2xl text-xs font-bold text-slate-600 hover:text-slate-900 hover:bg-slate-100/80 transition-all cursor-pointer"
            >
              <Compass className="w-4 h-4 text-slate-400" />
              <span>Bilim xaritasi</span>
            </button>

            <button
              onClick={onOpenAITutor}
              className="w-full flex items-center gap-3 px-4 py-3 rounded-2xl text-xs font-bold text-slate-600 hover:text-slate-900 hover:bg-slate-100/80 transition-all cursor-pointer"
            >
              <Bot className="w-4 h-4 text-slate-400" />
              <span>Yo‘lchi AI</span>
            </button>

            <button
              onClick={onOpenProgress}
              className="w-full flex items-center gap-3 px-4 py-3 rounded-2xl text-xs font-bold text-slate-600 hover:text-slate-900 hover:bg-slate-100/80 transition-all cursor-pointer"
            >
              <TrendingUp className="w-4 h-4 text-slate-400" />
              <span>Natijalar</span>
            </button>

            <button
              onClick={onOpenProfile || onOpenProgress}
              className="w-full flex items-center gap-3 px-4 py-3 rounded-2xl text-xs font-bold text-slate-600 hover:text-slate-900 hover:bg-slate-100/80 transition-all cursor-pointer"
            >
              <User className="w-4 h-4 text-slate-400" />
              <span>Profile</span>
            </button>

            {/* Pitch Day 3.0 & /demo links */}
            {onOpenPitch && (
              <button
                onClick={onOpenPitch}
                className="w-full flex items-center gap-3 px-4 py-2.5 rounded-2xl text-xs font-black bg-gradient-to-r from-indigo-600 via-purple-600 to-indigo-700 text-white shadow-xs hover:opacity-95 transition-all cursor-pointer mt-2"
              >
                <Sparkles className="w-4 h-4 text-amber-300" />
                <span>Pitch Day 3.0</span>
              </button>
            )}

            {onOpenDemo && (
              <button
                onClick={onOpenDemo}
                className="w-full flex items-center gap-3 px-4 py-2.5 rounded-2xl text-xs font-black bg-emerald-50 hover:bg-emerald-100 text-emerald-800 border border-emerald-300 transition-all cursor-pointer mt-1"
              >
                <Play className="w-4 h-4 text-emerald-600 fill-emerald-600" />
                <span>/demo Sahifasi</span>
              </button>
            )}
          </nav>
        </div>

        {/* Sidebar Bottom: XP Card & Settings matching Reference */}
        <div className="space-y-3 pt-4 border-t border-slate-100">
          <div className="p-4 rounded-2xl bg-gradient-to-br from-amber-50 to-orange-50/50 border border-amber-200/80 text-slate-900 space-y-2">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Crown className="w-4 h-4 text-amber-500 fill-amber-500" />
                <span className="text-xs font-black text-amber-900">{currentXP} XP</span>
              </div>
              <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-amber-100 text-amber-800 border border-amber-200">
                {Math.floor(currentXP / 100) + 1}-daraja
              </span>
            </div>
            <div className="h-1.5 w-full bg-amber-100 rounded-full overflow-hidden">
              <div
                className="h-full bg-amber-500 rounded-full transition-all"
                style={{ width: `${currentXP % 100}%` }}
              />
            </div>
            <p className="text-[10px] text-amber-800/80 font-medium">
              Keyingi darajaga {100 - (currentXP % 100)} XP
            </p>
          </div>

          <button
            onClick={onResetDemo}
            className="w-full flex items-center gap-2.5 px-3.5 py-2.5 rounded-2xl text-xs font-bold text-slate-600 hover:text-slate-900 hover:bg-slate-100/80 transition-colors cursor-pointer"
          >
            <RotateCcw className="w-4 h-4 text-slate-400" />
            <span>Kursni qayta boshlash</span>
          </button>
        </div>
      </aside>

      {/* 2. MAIN CONTENT AREA */}
      <main className="flex-1 p-4 sm:p-6 lg:p-8 max-w-7xl mx-auto w-full space-y-6">
        
        {/* TOP BAR: Search Input, Notifications & Profile Avatar */}
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
              className="w-full pl-11 pr-4 py-2.5 sm:py-3 bg-white border border-slate-200/90 rounded-2xl text-xs sm:text-sm text-slate-900 placeholder:text-slate-400 font-medium focus:outline-none focus:ring-4 focus:ring-blue-100 focus:border-blue-600 transition-all shadow-2xs"
            />
          </div>

          {/* Right side notifications & avatar */}
          <div className="flex items-center justify-end gap-3 shrink-0">
            <button
              onClick={onOpenProgress}
              className="p-2.5 sm:p-3 rounded-2xl bg-white border border-slate-200/90 text-slate-600 hover:bg-slate-50 transition-colors shadow-2xs relative cursor-pointer"
              title="Natijalar va bildirishnomalar"
              aria-label="Natijalar va bildirishnomalar"
            >
              <Bell className="w-4 h-4" />
              {(atRiskStreak || recentAttempts.length > 0) && (
                <span className="absolute top-2 right-2 w-2 h-2 rounded-full bg-rose-500 ring-2 ring-white" />
              )}
            </button>

            <button
              onClick={onOpenProfile || onOpenProgress}
              className="flex items-center gap-2.5 pl-2 pr-3 py-1.5 rounded-2xl bg-white border border-slate-200/90 hover:bg-slate-50 transition-colors shadow-2xs cursor-pointer"
            >
              <div className="w-8 h-8 rounded-xl bg-gradient-to-tr from-blue-600 to-indigo-600 flex items-center justify-center text-white font-black text-xs shadow-xs">
                {studentName.charAt(0)}
              </div>
              <div className="text-left hidden sm:block">
                <div className="text-xs font-black text-slate-900 leading-none">{studentName}</div>
                <div className="text-[10px] font-semibold text-slate-400 mt-0.5">O‘quvchi</div>
              </div>
            </button>
          </div>
        </div>

        {/* ROW 1: Greeting + Goals + Streak + XP Header matching Reference */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-white p-5 sm:p-6 rounded-3xl border border-slate-200/90 shadow-2xs">
          <div className="flex items-center gap-3.5">
            <div className="w-12 h-12 rounded-2xl bg-gradient-to-tr from-blue-600 via-indigo-600 to-cyan-400 p-0.5 shadow-md shadow-indigo-600/20 shrink-0">
              <div className="w-full h-full rounded-[14px] bg-slate-900 flex items-center justify-center text-white font-extrabold text-lg">
                {studentName.charAt(0)}
              </div>
            </div>
            <div>
              <div className="text-xs font-semibold text-slate-500">Assalomu alaykum,</div>
              <h1 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight">
                {studentName}! 👋
              </h1>
            </div>
          </div>

          {/* 3 Metric Pills matching Reference */}
          <div className="flex flex-wrap items-center gap-2.5">
            {/* Bugungi maqsad */}
            <div className="flex items-center gap-3 px-4 py-2 rounded-2xl bg-slate-50 border border-slate-200/80">
              <div className="w-7 h-7 rounded-xl bg-blue-100 flex items-center justify-center text-blue-600 shrink-0">
                🎯
              </div>
              <div>
                <div className="text-[10px] text-slate-500 font-bold uppercase">Bugungi maqsad</div>
                <div className="text-xs font-black text-slate-900">{dailyGoalDone}/{DAILY_GOAL_MINUTES} daqiqa</div>
              </div>
            </div>

            {/* Streak */}
            <div className="flex items-center gap-3 px-4 py-2 rounded-2xl bg-orange-50 border border-orange-200/80">
              <div className="w-7 h-7 rounded-xl bg-orange-100 flex items-center justify-center text-orange-600 shrink-0">
                <Flame className="w-4 h-4 fill-orange-500 text-orange-500" />
              </div>
              <div>
                <div className="text-[10px] text-orange-800 font-bold uppercase">{streakDays} kun</div>
                <div className="text-xs font-black text-orange-950">ketma-ket</div>
              </div>
            </div>

            {/* XP */}
            <div className="flex items-center gap-3 px-4 py-2 rounded-2xl bg-amber-50 border border-amber-200/80">
              <div className="w-7 h-7 rounded-xl bg-amber-100 flex items-center justify-center text-amber-600 shrink-0">
                <Award className="w-4 h-4 text-amber-600" />
              </div>
              <div>
                <div className="text-[10px] text-amber-800 font-bold uppercase">{currentXP} XP</div>
                <div className="text-xs font-black text-amber-950">Umumiy XP</div>
              </div>
            </div>
          </div>
        </div>

        {/* AT_RISK: loss-aversion streak reminder */}
        {atRiskStreak && (
          <div className="flex items-center justify-between gap-4 p-4 rounded-3xl bg-gradient-to-r from-orange-50 to-amber-50 border border-orange-200 shadow-2xs">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-2xl bg-orange-100 flex items-center justify-center shrink-0">
                <Flame className="w-5 h-5 fill-orange-500 text-orange-500" />
              </div>
              <div>
                <div className="text-xs sm:text-sm font-black text-orange-950">
                  🔥 {streakDays} kunlik seriyangiz xavf ostida!
                </div>
                <div className="text-[11px] sm:text-xs font-semibold text-orange-800">
                  Seriyani saqlab qolish uchun bugun kamida 1 ta dars yoki savol bajaring.
                </div>
              </div>
            </div>
            <button
              onClick={() => onContinueLesson(targetLessonId || undefined)}
              className="shrink-0 px-4 py-2 rounded-2xl bg-orange-500 hover:bg-orange-600 text-white font-black text-xs shadow-md shadow-orange-500/25 transition-colors cursor-pointer"
            >
              Boshlash
            </button>
          </div>
        )}

        {/* ROW 2: Subject Category Chips */}
        <div className="flex items-center justify-between gap-2 overflow-x-auto pb-1 scrollbar-none">
          <div className="flex items-center gap-2.5">
            {subjectCategories.map((cat) => (
              <button
                key={cat.id}
                onClick={() => selectCourseById(cat.id)}
                className={`flex items-center gap-2 px-4 py-2.5 rounded-2xl text-xs font-extrabold transition-all shrink-0 cursor-pointer ${
                  cat.active
                    ? 'bg-gradient-to-r from-blue-600 to-indigo-600 text-white shadow-md shadow-blue-600/30 ring-2 ring-blue-500/30'
                    : 'bg-white hover:bg-slate-50 text-slate-700 border border-slate-200/90 shadow-2xs hover:-translate-y-0.5'
                }`}
              >
                <span className="text-sm">{cat.icon}</span>
                <span>{cat.label}</span>
              </button>
            ))}
          </div>

          <button
            onClick={onOpenRoadmap}
            className="text-xs font-black text-blue-600 hover:text-blue-800 flex items-center gap-1 shrink-0 px-2 cursor-pointer transition-colors"
          >
            Barcha fanlar →
          </button>
        </div>

        {/* ROW 3: HERO CARD "DAVOM ETISH" OR EMPTY STATE WITH "DARS YARATISH" */}
        <div className="relative rounded-3xl overflow-hidden bg-gradient-to-r from-[#172554] via-[#1e1b4b] to-[#312e81] text-white p-6 sm:p-8 lg:p-10 shadow-xl shadow-indigo-950/20 border border-indigo-400/20">
          {/* Subtle cosmic glow orbs in background */}
          <div className="absolute top-0 right-1/3 w-80 h-80 bg-blue-500/20 rounded-full blur-3xl pointer-events-none" />
          <div className="absolute -bottom-10 right-0 w-80 h-80 bg-cyan-400/20 rounded-full blur-3xl pointer-events-none" />

          <div className="relative z-10 grid grid-cols-1 lg:grid-cols-12 gap-6 items-center">
            {/* Left text column */}
            <div className="lg:col-span-7 space-y-4">
              <div className="flex items-center gap-2.5">
                <span className="px-3 py-1 rounded-full bg-blue-500/30 border border-blue-400/30 text-blue-200 text-[10px] font-black uppercase tracking-wider">
                  {hasLessons ? 'DAVOM ETISH' : 'YANGI FAN'}
                </span>
                <span className="text-xs font-bold text-indigo-200">
                  {activeCourse?.title || 'Fan'} • {lessonCountLabel}
                </span>
              </div>

              <h2 className="text-2xl sm:text-3xl lg:text-4xl font-black text-white tracking-tight leading-tight">
                {heroTitle}
              </h2>

              <p className="text-xs sm:text-sm text-indigo-100/90 font-medium leading-relaxed max-w-lg">
                {heroDescription}
              </p>

              {/* Dynamic Progress bar */}
              <div className="space-y-1.5 max-w-md pt-2">
                <div className="flex items-center justify-between text-xs font-bold text-indigo-200">
                  <span>Modul progressi</span>
                  <span className="text-white font-black">{moduleProgress}%</span>
                </div>
                <div className="h-2.5 w-full bg-white/20 rounded-full overflow-hidden backdrop-blur-xs">
                  <div
                    className="h-full bg-gradient-to-r from-cyan-300 via-teal-300 to-emerald-300 rounded-full transition-all duration-500"
                    style={{ width: `${Math.max(moduleProgress, hasLessons ? 5 : 0)}%` }}
                  />
                </div>
              </div>

              {/* Action Button: Continue Lesson or Generate Lesson */}
              <div className="pt-2">
                {hasLessons ? (
                  <button
                    onClick={() => onContinueLesson(targetLessonId || undefined)}
                    className="px-6 py-3 rounded-2xl bg-white hover:bg-slate-100 text-slate-900 font-black text-xs sm:text-sm shadow-lg shadow-black/20 flex items-center gap-2 hover:scale-[1.02] active:scale-[0.98] transition-all cursor-pointer"
                  >
                    <span>Davom etish</span>
                    <ArrowRight className="w-4 h-4 text-blue-600" />
                  </button>
                ) : (
                  <button
                    onClick={handleCreateAILesson}
                    disabled={isGeneratingAILesson}
                    className="px-6 py-3 rounded-2xl bg-gradient-to-r from-cyan-400 via-teal-400 to-emerald-400 hover:brightness-105 text-slate-950 font-black text-xs sm:text-sm shadow-lg shadow-cyan-500/20 flex items-center gap-2 hover:scale-[1.02] active:scale-[0.98] transition-all cursor-pointer disabled:opacity-75"
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

                {/* Clear, recoverable Uzbek error when AI lesson generation fails */}
                {aiLessonError && !isGeneratingAILesson && (
                  <div className="mt-3 max-w-md p-3.5 bg-rose-500/15 border border-rose-300/40 rounded-xl flex items-start justify-between gap-3">
                    <span className="text-xs text-rose-100 font-semibold leading-relaxed">
                      {aiLessonError}
                    </span>
                    <button
                      type="button"
                      onClick={() => setAiLessonError(null)}
                      className="text-rose-200 hover:text-white text-xs font-black shrink-0 cursor-pointer"
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
              <div className="relative w-full max-w-sm rounded-2xl overflow-hidden border border-white/20 shadow-2xl bg-slate-950/40 group">
                <img
                  src="/images/dashboard_hero_student.jpg"
                  alt={`${activeCourse?.title || 'Dars'} qahramoni`}
                  className="w-full h-48 sm:h-56 lg:h-64 object-cover object-center group-hover:scale-105 transition-transform duration-700 ease-out"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-slate-950/70 via-transparent to-transparent pointer-events-none" />
                
                {/* Dynamic Subject Glass Badges */}
                <div className="absolute top-3 left-3 px-3 py-1.5 rounded-xl bg-white/20 backdrop-blur-md border border-white/30 text-white font-black text-xs flex items-center gap-1.5 shadow-sm">
                  <span>{heroBadge1.icon}</span>
                  <span className="text-[10px] text-cyan-200 font-semibold">{heroBadge1.label}</span>
                </div>
                <div className="absolute bottom-3 right-3 px-3 py-1.5 rounded-xl bg-blue-600/80 backdrop-blur-md border border-blue-400/40 text-white font-black text-xs flex items-center gap-1.5 shadow-sm">
                  <span>{heroBadge2.icon}</span>
                  <span className="text-[10px] text-white font-semibold">{heroBadge2.label}</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* ROW 4: "Siz uchun tavsiya" Recommendations matching Reference */}
        <div className="space-y-3">
          <div className="flex items-center justify-between">
            <h3 className="text-base font-black text-slate-900">
              Siz uchun tavsiya
            </h3>
            <button
              onClick={onOpenRoadmap}
              className="text-xs font-black text-blue-600 hover:text-blue-800 flex items-center gap-1 cursor-pointer transition-colors"
            >
              Barchasini ko‘rish →
            </button>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            {filteredRecommendations.length === 0 ? (
              <div className="sm:col-span-3 p-6 rounded-3xl bg-white border border-slate-200/90 text-center">
                <p className="text-xs font-semibold text-slate-500">
                  “{searchQuery}” bo‘yicha hech narsa topilmadi.
                </p>
              </div>
            ) : (
              filteredRecommendations.map((rec) => (
                <div
                  key={rec.id}
                  onClick={onOpenRoadmap}
                  className="bg-white p-4 rounded-3xl border border-slate-200/90 shadow-2xs hover:shadow-md hover:-translate-y-0.5 transition-all cursor-pointer flex items-center justify-between gap-3"
                >
                  <div className="flex items-center gap-3">
                    <div className={`w-11 h-11 rounded-2xl border flex items-center justify-center shrink-0 ${rec.colorClass}`}>
                      {rec.icon}
                    </div>
                    <div>
                      <h4 className="text-xs sm:text-sm font-black text-slate-900 leading-snug">
                        {rec.title}
                      </h4>
                      <p className="text-[11px] text-slate-400 font-semibold">{rec.desc}</p>
                    </div>
                  </div>
                  <ChevronRight className="w-4 h-4 text-slate-400" />
                </div>
              ))
            )}
          </div>
        </div>

        {/* ROW 5: 4-WIDGET BOTTOM GRID matching Reference */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">
          
          {/* Widget 1: Yo'lchi AI Mentor */}
          <div className="bg-white p-5 rounded-3xl border border-slate-200/90 shadow-2xs flex flex-col justify-between space-y-4">
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <h4 className="text-xs font-black text-slate-900">Yo‘lchi AI Mentor</h4>
                  <span className="text-[9px] font-black px-1.5 py-0.5 rounded-full bg-cyan-50 text-cyan-700 border border-cyan-200">
                    AI pedagog
                  </span>
                </div>
              </div>

              {/* Robot Mascot & Chat Bubble */}
              <div className="flex items-start gap-3 pt-1">
                <YolchiAIMascot size="sm" mood="explaining" />
                <div className="p-3 rounded-2xl rounded-tl-xs bg-slate-50 border border-slate-200/80 text-[11px] text-slate-700 font-semibold leading-relaxed">
                  Bugun qaysi mavzuni birga o‘rganamiz? Savollaringizga javob beraman va sizga mos tavsiyalar beraman.
                </div>
              </div>
            </div>

            <button
              onClick={onOpenAITutor}
              className="w-full py-2.5 px-4 rounded-xl bg-gradient-to-r from-blue-600 to-indigo-600 text-white font-black text-xs shadow-md shadow-blue-600/20 hover:from-blue-700 hover:to-indigo-700 transition-all flex items-center justify-center gap-1.5 cursor-pointer"
            >
              <span>Chatni ochish</span>
              <ArrowRight className="w-3.5 h-3.5" />
            </button>
          </div>

          {/* Widget 2: Bilim xaritasi */}
          <div className="bg-white p-5 rounded-3xl border border-slate-200/90 shadow-2xs flex flex-col justify-between space-y-4">
            <div className="space-y-2.5">
              <div className="flex items-center gap-2">
                <Compass className="w-4 h-4 text-blue-600" />
                <h4 className="text-xs font-black text-slate-900">Bilim xaritasi</h4>
              </div>
              <p className="text-[11px] text-slate-500 font-medium leading-relaxed">
                O‘z bilim darajangizni ko‘ring va keyingi mavzularni oching.
              </p>

              {/* Connected node graph illustration matching Reference */}
              <div className="h-20 w-full rounded-2xl bg-slate-50 border border-slate-100 flex items-center justify-center p-2 relative overflow-hidden">
                <div className="flex items-center justify-between w-4/5 relative">
                  <div className="absolute top-1/2 left-0 right-0 h-1 bg-gradient-to-r from-blue-500 via-cyan-400 to-emerald-400 -translate-y-1/2 z-0" />
                  <div className="w-6 h-6 rounded-full bg-blue-600 border-2 border-white shadow-xs z-10 flex items-center justify-center text-white text-[9px] font-black">
                    1
                  </div>
                  <div className="w-6 h-6 rounded-full bg-cyan-500 border-2 border-white shadow-xs z-10 flex items-center justify-center text-white text-[9px] font-black">
                    2
                  </div>
                  <div className="w-6 h-6 rounded-full bg-emerald-500 border-2 border-white shadow-xs z-10 flex items-center justify-center text-white text-[9px] font-black">
                    3
                  </div>
                  <div className="w-6 h-6 rounded-full bg-slate-300 border-2 border-white shadow-xs z-10 flex items-center justify-center text-white text-[9px]">
                    🔒
                  </div>
                </div>
              </div>
            </div>

            <button
              onClick={onOpenKnowledgeMap}
              className="w-full py-2.5 px-4 rounded-xl border border-slate-200 hover:border-blue-300 bg-white hover:bg-slate-50 text-slate-800 hover:text-blue-600 font-black text-xs transition-colors flex items-center justify-center gap-1.5 cursor-pointer"
            >
              <span>Xaritani ochish</span>
              <ArrowRight className="w-3.5 h-3.5" />
            </button>
          </div>

          {/* Widget 3: O'qish vaqti (Haftalik) */}
          <div className="bg-white p-5 rounded-3xl border border-slate-200/90 shadow-2xs flex flex-col justify-between space-y-3">
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-1.5">
                  <Clock className="w-4 h-4 text-slate-500" />
                  <h4 className="text-xs font-black text-slate-900">O‘qish vaqti (Haftalik)</h4>
                </div>
                <button
                  onClick={onOpenProgress}
                  className="text-[10px] font-black text-blue-600 hover:underline cursor-pointer"
                >
                  Batafsil
                </button>
              </div>

              {/* Bar chart derived from real daily activity */}
              <div className="h-24 pt-3 flex items-end justify-between gap-1 border-b border-slate-100">
                {weeklyStudyHours.length === 0 ? (
                  <div className="w-full text-center text-[10px] font-semibold text-slate-400 self-center">
                    Ma’lumot yo‘q
                  </div>
                ) : (
                  weeklyStudyHours.map((d, i) => (
                    <div key={i} className="flex-1 flex flex-col items-center gap-1 h-full justify-end">
                      <span className="text-[8px] font-bold text-slate-400">{d.hours}s</span>
                      <div
                        className={`w-full max-w-[14px] rounded-t-md transition-all ${
                          d.peak
                            ? 'bg-blue-600 shadow-xs'
                            : 'bg-cyan-400/80 hover:bg-cyan-500'
                        }`}
                        style={{ height: `${Math.max((d.hours / maxWeeklyHours) * 100, d.hours > 0 ? 8 : 2)}%` }}
                      />
                      <span className="text-[9px] font-extrabold text-slate-500">{d.day}</span>
                    </div>
                  ))
                )}
              </div>
              {activityError && (
                <p role="alert" className="text-[10px] font-semibold text-rose-600">
                  Faollik ma’lumotlari yuklanmadi: {activityError}
                </p>
              )}
            </div>

            <div className="text-[11px] text-slate-500 flex items-center justify-between pt-1">
              <span>Umumiy: <strong>{(totalMinutes / 60).toFixed(1)} soat</strong></span>
              <span className="text-emerald-600 font-black">{overallScore}%</span>
            </div>
          </div>

          {/* Widget 4: So'nggi natijalar */}
          <div className="bg-white p-5 rounded-3xl border border-slate-200/90 shadow-2xs flex flex-col justify-between space-y-3">
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <h4 className="text-xs font-black text-slate-900">So‘nggi natijalar</h4>
                <button
                  onClick={onOpenProgress}
                  className="text-[10px] font-black text-blue-600 hover:underline cursor-pointer"
                >
                  Barchasini ko‘rish →
                </button>
              </div>

              {/* Result items derived from real attempts */}
              <div className="space-y-2">
                {subjectRecentResults.length === 0 ? (
                  <p className="text-[11px] font-semibold text-slate-400 py-2">
                    Hali natijalar yo‘q. Birinchi darsni boshlang!
                  </p>
                ) : (
                  subjectRecentResults.map((item, idx) => (
                    <div key={idx} className="flex items-center justify-between text-xs">
                      <div className="flex items-center gap-1.5 truncate max-w-[150px]">
                        {item.isCorrect ? (
                          <CheckCircle2 className="w-3.5 h-3.5 text-emerald-500 shrink-0" />
                        ) : (
                          <XCircle className="w-3.5 h-3.5 text-rose-400 shrink-0" />
                        )}
                        <span className="font-bold text-slate-800 text-[11px] truncate">{item.title}</span>
                      </div>
                      <span className={`text-[11px] font-black shrink-0 ${item.isCorrect ? 'text-emerald-600' : 'text-slate-400'}`}>{item.xp}</span>
                    </div>
                  ))
                )}
              </div>
            </div>

            <div className="pt-2 border-t border-slate-100 flex items-center justify-between text-[11px] text-slate-500">
              <span>Umumiy bilim:</span>
              <strong className="text-indigo-600 font-black">{overallScore}%</strong>
            </div>
          </div>

        </div>

      </main>
    </div>
  );
};
