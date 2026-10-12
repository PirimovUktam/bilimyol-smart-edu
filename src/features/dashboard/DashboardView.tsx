import React, { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
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
  Zap,
} from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { useLessonStore } from '@/app/store/useLessonStore';
import { useAuth } from '@/core/context/AuthContext';
import { supabaseLearnerRepository } from '@/data/repositories/SupabaseLearnerRepository';
import { AnswerAttemptRecord } from '@/domain/repositories/ILearnerRepository';
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
  const [, setRecentAttempts] = useState<AnswerAttemptRecord[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [isGeneratingAILesson, setIsGeneratingAILesson] = useState(false);
  const [aiLessonError, setAiLessonError] = useState<string | null>(null);

  useEffect(() => {
    if (activeCourse) {
      loadRoadmap(activeCourse.id);
    }
    supabaseLearnerRepository.getAnswerAttempts(5).then(setRecentAttempts);
  }, [activeCourse, loadRoadmap, profile]);

  const scores = (profile?.scoresByCourse && activeCourse) ? (profile.scoresByCourse[activeCourse.id] || {}) : {};
  const overallScore = SkillScoringEngine.computeOverallScore(scores);

  // Dynamic weak/strong skills
  let weakestSkillId = activeCourseSkills[0]?.id || `skill_${activeCourse?.id || 'gen'}_01`;
  let weakestSkillName = activeCourseSkills[0]?.name || 'Asosiy mavzu';
  let weakestScore = 100;

  activeCourseSkills.forEach((sk) => {
    const sc = scores[sk.id]?.score ?? 0;
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
  const currentXP = profile?.xp || 120;
  const streakDays = profile?.streakDays || 5;

  const subjectCategories = [
    { id: 'course_math_01', label: 'Matematika', icon: '📐', active: activeCourse?.id === 'course_math_01' },
    { id: 'course_eng_01', label: 'Ingliz tili', icon: '🇬🇧', active: activeCourse?.id === 'course_eng_01' },
    { id: 'course_it', label: 'IT & Kodlash', icon: '💻', active: activeCourse?.id === 'course_it' },
    { id: 'course_logic', label: 'Mantiq', icon: '🧩', active: activeCourse?.id === 'course_logic' },
  ];

  const weeklyStudyHours = [
    { day: 'Dsh', hours: 1.2 },
    { day: 'Ssh', hours: 0.8 },
    { day: 'Chor', hours: 1.5 },
    { day: 'Pay', hours: 2.1, peak: true },
    { day: 'Jum', hours: 1.8 },
    { day: 'Shan', hours: 1.0 },
    { day: 'Yak', hours: 1.3 },
  ];

  // Dynamic Recommendations strictly isolated by subject
  const recommendations = activeCourse?.id === 'course_eng_01'
    ? [
        {
          id: 'rec_eng_1',
          title: 'Essential Vocabulary',
          desc: '10 dars • Lug‘at boyligi',
          icon: <BookOpen className="w-5 h-5 text-rose-400" />,
          colorClass: 'bg-rose-950/80 border-rose-500/40 text-rose-300',
        },
        {
          id: 'rec_eng_2',
          title: 'Grammar & Conditionals',
          desc: '8 dars • Grammatika',
          icon: <FileText className="w-5 h-5 text-indigo-400" />,
          colorClass: 'bg-indigo-950/80 border-indigo-500/40 text-indigo-300',
        },
        {
          id: 'rec_eng_3',
          title: 'Listening & Pronunciation',
          desc: '12 dars • Tinglab tushunish',
          icon: <Headphones className="w-5 h-5 text-amber-400" />,
          colorClass: 'bg-amber-950/80 border-amber-500/40 text-amber-300',
        },
      ]
    : activeCourse?.id === 'course_it'
    ? [
        {
          id: 'rec_it_1',
          title: 'Python asoslari',
          desc: '8 dars • Dasturlash',
          icon: <Code2 className="w-5 h-5 text-cyan-400" />,
          colorClass: 'bg-cyan-950/80 border-cyan-500/40 text-cyan-300',
        },
        {
          id: 'rec_it_2',
          title: 'Algoritmik mantiq',
          desc: '10 dars • Algoritmlar',
          icon: <Cpu className="w-5 h-5 text-blue-400" />,
          colorClass: 'bg-blue-950/80 border-blue-500/40 text-blue-300',
        },
        {
          id: 'rec_it_3',
          title: 'Veb texnologiyalari',
          desc: '6 dars • Frontend',
          icon: <Globe className="w-5 h-5 text-emerald-400" />,
          colorClass: 'bg-emerald-950/80 border-emerald-500/40 text-emerald-300',
        },
      ]
    : activeCourse?.id === 'course_logic'
    ? [
        {
          id: 'rec_log_1',
          title: 'Mantiqiy fikrlash',
          desc: '12 dars • Deduksiya',
          icon: <Lightbulb className="w-5 h-5 text-amber-400" />,
          colorClass: 'bg-amber-950/80 border-amber-500/40 text-amber-300',
        },
        {
          id: 'rec_log_2',
          title: 'Kombinatorika asoslari',
          desc: '8 dars • Boshqotirma',
          icon: <Sparkles className="w-5 h-5 text-purple-400" />,
          colorClass: 'bg-purple-950/80 border-purple-500/40 text-purple-300',
        },
        {
          id: 'rec_log_3',
          title: 'Mantiqiy zanjirlar',
          desc: '10 dars • Tahlil',
          icon: <Compass className="w-5 h-5 text-emerald-400" />,
          colorClass: 'bg-emerald-950/80 border-emerald-500/40 text-emerald-300',
        },
      ]
    : [
        {
          id: 'rec_math_1',
          title: 'Algebra: Qisqa ko‘paytirish',
          desc: '8 dars • Algebra formulalari',
          icon: <Calculator className="w-5 h-5 text-cyan-400" />,
          colorClass: 'bg-cyan-950/80 border-cyan-500/40 text-cyan-300',
        },
        {
          id: 'rec_math_2',
          title: 'Chiziqli tenglamalar',
          desc: '10 dars • Tenglamalar',
          icon: <Equal className="w-5 h-5 text-indigo-400" />,
          colorClass: 'bg-indigo-950/80 border-indigo-500/40 text-indigo-300',
        },
        {
          id: 'rec_math_3',
          title: 'Funksiyalar va grafiklar',
          desc: '12 dars • Grafik tahlili',
          icon: <LineChart className="w-5 h-5 text-emerald-400" />,
          colorClass: 'bg-emerald-950/80 border-emerald-500/40 text-emerald-300',
        },
      ];

  // Dynamic Recent Results strictly isolated by subject
  const subjectRecentResults = activeCourse?.id === 'course_eng_01'
    ? [
        { title: 'Listening: Audio xabarlar testi', xp: '+20 XP' },
        { title: 'Vocabulary: Oxford 3000 mashqi', xp: '+15 XP' },
        { title: 'Grammar: Second Conditional', xp: '+20 XP' },
      ]
    : activeCourse?.id === 'course_it'
    ? [
        { title: 'Python sintaksisi testi', xp: '+20 XP' },
        { title: 'O‘zgaruvchilar va tiplar', xp: '+15 XP' },
        { title: 'Algoritmik sikllar', xp: '+20 XP' },
      ]
    : activeCourse?.id === 'course_logic'
    ? [
        { title: 'Deduktiv xulosa testi', xp: '+20 XP' },
        { title: 'Mantiqiy zanjirlar tahlili', xp: '+15 XP' },
        { title: 'Boshqotirma yechish', xp: '+20 XP' },
      ]
    : [
        { title: 'Funksiya qiymatini hisoblash', xp: '+20 XP' },
        { title: 'Qisqa ko‘paytirish amallari', xp: '+15 XP' },
        { title: 'Chiziqli tenglama yechish', xp: '+20 XP' },
      ];

  return (
    <div className="min-h-screen bg-[#030712] text-slate-100 flex flex-col lg:flex-row relative">
      {/* 1. LEFT SIDEBAR: Cosmic Command Desktop Navigation */}
      <aside className="hidden lg:flex w-64 bg-[#040714]/90 border-r border-white/10 flex-col justify-between shrink-0 p-5 sticky top-0 h-screen overflow-y-auto backdrop-blur-2xl z-20">
        <div className="space-y-6">
          {/* Logo at top of sidebar */}
          <div className="px-2">
            <BilimYolLogo size="md" variant="dark" />
          </div>

          {/* Navigation Links */}
          <nav className="space-y-1.5">
            <button
              className="w-full flex items-center gap-3 px-4 py-3 rounded-2xl text-xs font-black bg-gradient-to-r from-cyan-500 to-indigo-600 text-white shadow-[0_0_20px_rgba(6,182,212,0.35)] transition-all cursor-pointer"
            >
              <LayoutDashboard className="w-4 h-4 text-white" />
              <span>Bosh sahifa</span>
            </button>

            <button
              onClick={onOpenRoadmap}
              className="w-full flex items-center gap-3 px-4 py-3 rounded-2xl text-xs font-bold text-slate-300 hover:text-white hover:bg-white/5 transition-all cursor-pointer"
            >
              <Map className="w-4 h-4 text-cyan-400" />
              <span>Ta’lim yo‘li</span>
            </button>

            <button
              onClick={onOpenKnowledgeMap}
              className="w-full flex items-center gap-3 px-4 py-3 rounded-2xl text-xs font-bold text-slate-300 hover:text-white hover:bg-white/5 transition-all cursor-pointer"
            >
              <Compass className="w-4 h-4 text-purple-400" />
              <span>Bilim xaritasi</span>
            </button>

            <button
              onClick={onOpenAITutor}
              className="w-full flex items-center gap-3 px-4 py-3 rounded-2xl text-xs font-bold text-slate-300 hover:text-white hover:bg-white/5 transition-all cursor-pointer"
            >
              <Bot className="w-4 h-4 text-emerald-400" />
              <span>Yo‘lchi AI</span>
            </button>

            <button
              onClick={onOpenProgress}
              className="w-full flex items-center gap-3 px-4 py-3 rounded-2xl text-xs font-bold text-slate-300 hover:text-white hover:bg-white/5 transition-all cursor-pointer"
            >
              <TrendingUp className="w-4 h-4 text-amber-400" />
              <span>Natijalar</span>
            </button>

            <button
              onClick={onOpenProfile || onOpenProgress}
              className="w-full flex items-center gap-3 px-4 py-3 rounded-2xl text-xs font-bold text-slate-300 hover:text-white hover:bg-white/5 transition-all cursor-pointer"
            >
              <User className="w-4 h-4 text-slate-400" />
              <span>Profile</span>
            </button>

            {/* Pitch Day 3.0 & /demo links */}
            {onOpenPitch && (
              <button
                onClick={onOpenPitch}
                className="w-full flex items-center gap-3 px-4 py-2.5 rounded-2xl text-xs font-black bg-gradient-to-r from-cyan-500 via-indigo-600 to-purple-600 text-white shadow-[0_0_20px_rgba(99,102,241,0.35)] hover:brightness-110 transition-all cursor-pointer mt-3"
              >
                <Sparkles className="w-4 h-4 text-amber-300" />
                <span>Pitch Day 3.0</span>
              </button>
            )}

            {onOpenDemo && (
              <button
                onClick={onOpenDemo}
                className="w-full flex items-center gap-3 px-4 py-2.5 rounded-2xl text-xs font-black bg-white/10 hover:bg-white/20 text-white border border-white/20 backdrop-blur-md transition-all cursor-pointer mt-1"
              >
                <Play className="w-4 h-4 text-cyan-400 fill-cyan-400" />
                <span>/demo Sahifasi</span>
              </button>
            )}
          </nav>
        </div>

        {/* Sidebar Bottom: XP Card & Settings */}
        <div className="space-y-3 pt-4 border-t border-white/10">
          <div className="p-4 rounded-2xl bg-slate-900/90 border border-amber-500/30 text-white space-y-2 shadow-[0_0_20px_rgba(245,158,11,0.15)]">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Crown className="w-4 h-4 text-amber-400 fill-amber-400 pulse-flame" />
                <span className="text-xs font-black text-amber-300">{currentXP} XP</span>
              </div>
              <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-amber-950/80 text-amber-300 border border-amber-500/40">
                3-daraja
              </span>
            </div>
            <div className="h-1.5 w-full bg-slate-800 rounded-full overflow-hidden">
              <div className="h-full bg-gradient-to-r from-amber-400 to-orange-500 rounded-full w-[65%]" />
            </div>
            <p className="text-[10px] text-slate-400 font-medium">Keyingi darajagacha +35 XP</p>
          </div>

          <button
            onClick={onResetDemo}
            className="w-full flex items-center gap-2.5 px-3.5 py-2.5 rounded-2xl text-xs font-bold text-slate-400 hover:text-white hover:bg-white/5 transition-colors cursor-pointer"
          >
            <RotateCcw className="w-4 h-4 text-slate-400" />
            <span>Kursni qayta boshlash</span>
          </button>
        </div>
      </aside>

      {/* 2. MAIN CONTENT AREA */}
      <main className="flex-1 p-4 sm:p-6 lg:p-8 max-w-7xl mx-auto w-full space-y-6 relative z-10">
        
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
              className="w-full pl-11 pr-4 py-2.5 sm:py-3 bg-slate-900/80 border border-white/10 rounded-2xl text-xs sm:text-sm text-white placeholder:text-slate-500 font-medium focus:outline-none focus:border-cyan-400 focus:ring-4 focus:ring-cyan-500/10 backdrop-blur-xl transition-all shadow-lg"
            />
          </div>

          {/* Right side notifications & avatar */}
          <div className="flex items-center justify-end gap-3 shrink-0">
            <button
              onClick={onOpenProgress}
              className="p-2.5 sm:p-3 rounded-2xl bg-slate-900/80 border border-white/10 text-slate-300 hover:text-white hover:bg-white/10 transition-colors shadow-md relative cursor-pointer"
              title="Bildirishnomalar"
            >
              <Bell className="w-4 h-4" />
              <span className="absolute top-2 right-2 w-2 h-2 rounded-full bg-cyan-400 ring-2 ring-slate-950 animate-pulse" />
            </button>

            <button
              onClick={onOpenProfile || onOpenProgress}
              className="flex items-center gap-2.5 pl-2 pr-3 py-1.5 rounded-2xl bg-slate-900/80 border border-white/10 hover:border-cyan-500/40 transition-colors shadow-md cursor-pointer"
            >
              <div className="w-8 h-8 rounded-xl bg-gradient-to-tr from-cyan-500 via-indigo-600 to-purple-600 flex items-center justify-center text-white font-black text-xs shadow-xs">
                {studentName.charAt(0)}
              </div>
              <div className="text-left hidden sm:block">
                <div className="text-xs font-black text-white leading-none">{studentName}</div>
                <div className="text-[10px] font-semibold text-cyan-400 mt-0.5">O‘quvchi</div>
              </div>
            </button>
          </div>
        </div>

        {/* ROW 1: Greeting + Goals + Streak + XP Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-slate-900/80 border border-white/10 backdrop-blur-xl p-5 sm:p-6 rounded-3xl shadow-xl">
          <div className="flex items-center gap-3.5">
            <div className="w-12 h-12 rounded-2xl bg-gradient-to-tr from-cyan-400 via-indigo-500 to-purple-600 p-0.5 shadow-lg shadow-indigo-600/30 shrink-0">
              <div className="w-full h-full rounded-[14px] bg-slate-950 flex items-center justify-center text-white font-extrabold text-lg">
                {studentName.charAt(0)}
              </div>
            </div>
            <div>
              <div className="text-xs font-semibold text-slate-400">Assalomu alaykum,</div>
              <h1 className="text-xl sm:text-2xl font-black text-white tracking-tight">
                {studentName}! 👋
              </h1>
            </div>
          </div>

          {/* 3 Metric Pills */}
          <div className="flex flex-wrap items-center gap-2.5">
            {/* Bugungi maqsad */}
            <div className="flex items-center gap-3 px-4 py-2 rounded-2xl bg-cyan-950/70 border border-cyan-500/30">
              <div className="w-7 h-7 rounded-xl bg-cyan-500/20 flex items-center justify-center text-cyan-300 shrink-0">
                🎯
              </div>
              <div>
                <div className="text-[10px] text-cyan-300 font-bold uppercase">Bugungi maqsad</div>
                <div className="text-xs font-black text-white">3/5 dars</div>
              </div>
            </div>

            {/* Streak */}
            <div className="flex items-center gap-3 px-4 py-2 rounded-2xl bg-amber-950/70 border border-amber-500/30 shadow-[0_0_15px_rgba(245,158,11,0.15)]">
              <div className="w-7 h-7 rounded-xl bg-amber-500/20 flex items-center justify-center text-amber-400 shrink-0">
                <Flame className="w-4 h-4 fill-amber-400 text-amber-400 pulse-flame" />
              </div>
              <div>
                <div className="text-[10px] text-amber-300 font-bold uppercase">{streakDays} kun</div>
                <div className="text-xs font-black text-white">ketma-ket</div>
              </div>
            </div>

            {/* XP */}
            <div className="flex items-center gap-3 px-4 py-2 rounded-2xl bg-purple-950/70 border border-purple-500/30 shadow-[0_0_15px_rgba(168,85,247,0.15)]">
              <div className="w-7 h-7 rounded-xl bg-purple-500/20 flex items-center justify-center text-purple-400 shrink-0">
                <Award className="w-4 h-4 text-purple-400" />
              </div>
              <div>
                <div className="text-[10px] text-purple-300 font-bold uppercase">{currentXP} XP</div>
                <div className="text-xs font-black text-white">Umumiy XP</div>
              </div>
            </div>
          </div>
        </div>

        {/* ROW 2: Subject Category Chips */}
        <div className="flex items-center justify-between gap-2 overflow-x-auto pb-1 scrollbar-none">
          <div className="flex items-center gap-2.5">
            {subjectCategories.map((cat) => (
              <button
                key={cat.id}
                onClick={() => selectCourseById(cat.id)}
                className={`flex items-center gap-2 px-4 py-2.5 rounded-2xl text-xs font-extrabold transition-all shrink-0 cursor-pointer ${
                  cat.active
                    ? 'bg-gradient-to-r from-cyan-500 to-indigo-600 text-white shadow-[0_0_20px_rgba(6,182,212,0.35)] ring-2 ring-cyan-400/50'
                    : 'bg-slate-900/80 hover:bg-slate-800 text-slate-300 border border-white/10 hover:text-white'
                }`}
              >
                <span className="text-sm">{cat.icon}</span>
                <span>{cat.label}</span>
              </button>
            ))}
          </div>

          <button
            onClick={onOpenRoadmap}
            className="text-xs font-black text-cyan-400 hover:text-cyan-300 flex items-center gap-1 shrink-0 px-2 cursor-pointer transition-colors"
          >
            Barcha fanlar →
          </button>
        </div>

        {/* ROW 3: HERO MISSION CARD */}
        <div className="relative rounded-3xl overflow-hidden bg-gradient-to-r from-[#0c1445] via-[#161245] to-[#20104a] text-white p-6 sm:p-8 lg:p-10 shadow-[0_0_50px_rgba(79,70,229,0.25)] border-2 border-indigo-500/40">
          {/* Subtle cosmic glow orbs in background */}
          <div className="absolute top-0 right-1/3 w-80 h-80 bg-cyan-500/20 rounded-full blur-3xl pointer-events-none" />
          <div className="absolute -bottom-10 right-0 w-80 h-80 bg-purple-500/25 rounded-full blur-3xl pointer-events-none" />

          <div className="relative z-10 grid grid-cols-1 lg:grid-cols-12 gap-6 items-center">
            {/* Left text column */}
            <div className="lg:col-span-7 space-y-4">
              <div className="flex items-center gap-2.5">
                <span className="px-3 py-1 rounded-full bg-cyan-500/25 border border-cyan-400/30 text-cyan-300 text-[10px] font-black uppercase tracking-wider">
                  {hasLessons ? 'DAVOM ETISH' : 'YANGI FAN'}
                </span>
                <span className="text-xs font-bold text-slate-300">
                  {activeCourse?.title || 'Fan'} • {lessonCountLabel}
                </span>
              </div>

              <h2 className="text-2xl sm:text-3xl lg:text-4xl font-black text-white tracking-tight leading-tight">
                {heroTitle}
              </h2>

              <p className="text-xs sm:text-sm text-slate-300 font-medium leading-relaxed max-w-lg">
                {heroDescription}
              </p>

              {/* Dynamic Progress bar */}
              <div className="space-y-1.5 max-w-md pt-2">
                <div className="flex items-center justify-between text-xs font-bold text-slate-300">
                  <span>Modul progressi</span>
                  <span className="text-cyan-300 font-black">{moduleProgress}%</span>
                </div>
                <div className="h-2.5 w-full bg-white/10 rounded-full overflow-hidden backdrop-blur-xs">
                  <div
                    className="h-full bg-gradient-to-r from-cyan-400 via-teal-400 to-emerald-400 rounded-full shadow-[0_0_12px_rgba(6,182,212,0.8)] transition-all duration-500"
                    style={{ width: `${Math.max(moduleProgress, hasLessons ? 5 : 0)}%` }}
                  />
                </div>
              </div>

              {/* Action Button: Continue Lesson or Generate Lesson */}
              <div className="pt-2 flex flex-wrap items-center gap-3">
                {hasLessons && (
                  <button
                    onClick={() => onContinueLesson(targetLessonId || undefined)}
                    className="px-7 py-3.5 rounded-2xl bg-gradient-to-r from-cyan-400 to-blue-500 hover:from-cyan-300 hover:to-blue-400 text-slate-950 font-black text-xs sm:text-sm shadow-[0_0_25px_rgba(6,182,212,0.4)] flex items-center gap-2 hover:scale-[1.02] active:scale-[0.98] transition-all cursor-pointer"
                  >
                    <span>Darsni Davom Ettirish</span>
                    <ArrowRight className="w-4 h-4 text-slate-950" />
                  </button>
                )}

                <button
                  onClick={handleCreateAILesson}
                  disabled={isGeneratingAILesson}
                  className="px-6 py-3.5 rounded-2xl bg-slate-900/90 hover:bg-slate-800 text-cyan-300 border border-cyan-500/40 font-bold text-xs sm:text-sm shadow-lg flex items-center gap-2 hover:scale-[1.02] active:scale-[0.98] transition-all cursor-pointer disabled:opacity-75"
                >
                  {isGeneratingAILesson ? (
                    <>
                      <RotateCcw className="w-4 h-4 animate-spin text-cyan-400" />
                      <span>AI dars yaratmoqda...</span>
                    </>
                  ) : (
                    <>
                      <Sparkles className="w-4 h-4 text-cyan-400" />
                      <span>Yo‘lchi AI Dars Yaratish</span>
                    </>
                  )}
                </button>

                {/* Error Banner */}
                {aiLessonError && !isGeneratingAILesson && (
                  <div className="mt-3 w-full max-w-md p-3.5 bg-rose-500/20 border border-rose-400/40 rounded-xl flex items-start justify-between gap-3">
                    <span className="text-xs text-rose-200 font-semibold leading-relaxed">
                      {aiLessonError}
                    </span>
                    <button
                      type="button"
                      onClick={() => setAiLessonError(null)}
                      className="text-rose-300 hover:text-white text-xs font-black shrink-0 cursor-pointer"
                    >
                      ✕
                    </button>
                  </div>
                )}
              </div>
            </div>

            {/* Right Artwork column */}
            <div className="lg:col-span-5 flex justify-center lg:justify-end">
              <div className="relative w-full max-w-sm rounded-2xl overflow-hidden border border-white/20 shadow-2xl bg-slate-950/40 group">
                <img
                  src="/images/dashboard_hero_student.jpg"
                  alt={`${activeCourse?.title || 'Dars'} qahramoni`}
                  className="w-full h-48 sm:h-56 lg:h-64 object-cover object-center group-hover:scale-105 transition-transform duration-700 ease-out"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-slate-950/80 via-transparent to-transparent pointer-events-none" />
                
                {/* Dynamic Subject Glass Badges */}
                <div className="absolute top-3 left-3 px-3 py-1.5 rounded-xl bg-slate-950/70 backdrop-blur-md border border-white/20 text-white font-black text-xs flex items-center gap-1.5 shadow-md">
                  <span>{heroBadge1.icon}</span>
                  <span className="text-[10px] text-cyan-300 font-semibold">{heroBadge1.label}</span>
                </div>
                <div className="absolute bottom-3 right-3 px-3 py-1.5 rounded-xl bg-cyan-950/80 backdrop-blur-md border border-cyan-500/40 text-cyan-300 font-black text-xs flex items-center gap-1.5 shadow-md">
                  <span>{heroBadge2.icon}</span>
                  <span className="text-[10px] text-white font-semibold">{heroBadge2.label}</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* ROW 4: "Siz uchun tavsiya" Recommendations */}
        <div className="space-y-3">
          <div className="flex items-center justify-between">
            <h3 className="text-base font-black text-white flex items-center gap-2">
              <Zap className="w-4 h-4 text-cyan-400" />
              <span>Siz uchun tavsiya etilgan mavzular</span>
            </h3>
            <button
              onClick={onOpenRoadmap}
              className="text-xs font-black text-cyan-400 hover:text-cyan-300 flex items-center gap-1 cursor-pointer transition-colors"
            >
              Barchasini ko‘rish →
            </button>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            {recommendations.map((rec) => (
              <div
                key={rec.id}
                onClick={onOpenRoadmap}
                className="bg-slate-900/80 p-4 rounded-3xl border border-white/10 hover:border-cyan-500/40 shadow-lg hover:shadow-[0_0_25px_rgba(6,182,212,0.2)] hover:-translate-y-1 transition-all cursor-pointer flex items-center justify-between gap-3 group backdrop-blur-xl"
              >
                <div className="flex items-center gap-3">
                  <div className={`w-11 h-11 rounded-2xl border flex items-center justify-center shrink-0 ${rec.colorClass}`}>
                    {rec.icon}
                  </div>
                  <div>
                    <h4 className="text-xs sm:text-sm font-black text-white group-hover:text-cyan-300 transition-colors leading-snug">
                      {rec.title}
                    </h4>
                    <p className="text-[11px] text-slate-400 font-semibold">{rec.desc}</p>
                  </div>
                </div>
                <ChevronRight className="w-4 h-4 text-slate-400 group-hover:text-cyan-400 group-hover:translate-x-1 transition-all" />
              </div>
            ))}
          </div>
        </div>

        {/* ROW 5: 4-WIDGET BOTTOM GRID */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">
          
          {/* Widget 1: Yo'lchi AI Mentor */}
          <div className="bg-slate-900/80 p-5 rounded-3xl border border-white/10 shadow-lg flex flex-col justify-between space-y-4 backdrop-blur-xl">
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <h4 className="text-xs font-black text-white">Yo‘lchi AI Mentor</h4>
                  <span className="text-[9px] font-black px-1.5 py-0.5 rounded-full bg-cyan-950/80 text-cyan-300 border border-cyan-500/40">
                    AI pedagog
                  </span>
                </div>
              </div>

              {/* Robot Mascot & Chat Bubble */}
              <div className="flex items-start gap-3 pt-1">
                <YolchiAIMascot size="sm" mood="explaining" variant="dark" />
                <div className="p-3 rounded-2xl rounded-tl-xs bg-slate-950/80 border border-cyan-500/30 text-[11px] text-slate-200 font-semibold leading-relaxed">
                  Bugun qaysi mavzuni birga o‘rganamiz? Savollaringizga real vaqtda javob beraman.
                </div>
              </div>
            </div>

            <button
              onClick={onOpenAITutor}
              className="w-full py-2.5 px-4 rounded-xl bg-gradient-to-r from-cyan-500 to-indigo-600 text-white font-black text-xs shadow-md shadow-indigo-600/30 hover:brightness-110 transition-all flex items-center justify-center gap-1.5 cursor-pointer"
            >
              <span>Chatni ochish</span>
              <ArrowRight className="w-3.5 h-3.5" />
            </button>
          </div>

          {/* Widget 2: Bilim xaritasi */}
          <div className="bg-slate-900/80 p-5 rounded-3xl border border-white/10 shadow-lg flex flex-col justify-between space-y-4 backdrop-blur-xl">
            <div className="space-y-2.5">
              <div className="flex items-center gap-2">
                <Compass className="w-4 h-4 text-cyan-400" />
                <h4 className="text-xs font-black text-white">Bilim xaritasi</h4>
              </div>
              <p className="text-[11px] text-slate-400 font-medium leading-relaxed">
                O‘z bilim darajangizni ko‘ring va keyingi mavzularni oching.
              </p>

              {/* Connected node graph illustration */}
              <div className="h-20 w-full rounded-2xl bg-slate-950/80 border border-white/10 flex items-center justify-center p-2 relative overflow-hidden">
                <div className="flex items-center justify-between w-4/5 relative">
                  <div className="absolute top-1/2 left-0 right-0 h-1 bg-gradient-to-r from-blue-500 via-cyan-400 to-emerald-400 -translate-y-1/2 z-0" />
                  <div className="w-6 h-6 rounded-full bg-cyan-500 border-2 border-slate-900 shadow-md z-10 flex items-center justify-center text-slate-950 text-[9px] font-black">
                    1
                  </div>
                  <div className="w-6 h-6 rounded-full bg-indigo-500 border-2 border-slate-900 shadow-md z-10 flex items-center justify-center text-white text-[9px] font-black">
                    2
                  </div>
                  <div className="w-6 h-6 rounded-full bg-emerald-500 border-2 border-slate-900 shadow-md z-10 flex items-center justify-center text-slate-950 text-[9px] font-black">
                    3
                  </div>
                  <div className="w-6 h-6 rounded-full bg-slate-800 border-2 border-slate-700 shadow-md z-10 flex items-center justify-center text-slate-400 text-[9px]">
                    🔒
                  </div>
                </div>
              </div>
            </div>

            <button
              onClick={onOpenKnowledgeMap}
              className="w-full py-2.5 px-4 rounded-xl border border-white/10 hover:border-cyan-500/40 bg-slate-900 hover:bg-slate-800 text-slate-200 hover:text-white font-black text-xs transition-colors flex items-center justify-center gap-1.5 cursor-pointer"
            >
              <span>Xaritani ochish</span>
              <ArrowRight className="w-3.5 h-3.5" />
            </button>
          </div>

          {/* Widget 3: O'qish vaqti (Haftalik) */}
          <div className="bg-slate-900/80 p-5 rounded-3xl border border-white/10 shadow-lg flex flex-col justify-between space-y-3 backdrop-blur-xl">
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-1.5">
                  <Clock className="w-4 h-4 text-cyan-400" />
                  <h4 className="text-xs font-black text-white">O‘qish vaqti (Haftalik)</h4>
                </div>
                <button
                  onClick={onOpenProgress}
                  className="text-[10px] font-black text-cyan-400 hover:underline cursor-pointer"
                >
                  Batafsil
                </button>
              </div>

              {/* Bar chart with neon glowing bars */}
              <div className="h-24 pt-3 flex items-end justify-between gap-1 border-b border-white/10">
                {weeklyStudyHours.map((d, i) => (
                  <div key={i} className="flex-1 flex flex-col items-center gap-1 h-full justify-end">
                    <span className="text-[8px] font-bold text-slate-400">{d.hours}s</span>
                    <div
                      className={`w-full max-w-[14px] rounded-t-md transition-all ${
                        d.peak
                          ? 'bg-gradient-to-t from-cyan-500 to-blue-500 shadow-[0_0_12px_rgba(6,182,212,0.8)]'
                          : 'bg-indigo-500/50 hover:bg-indigo-400'
                      }`}
                      style={{ height: `${(d.hours / 2.1) * 100}%` }}
                    />
                    <span className="text-[9px] font-extrabold text-slate-400">{d.day}</span>
                  </div>
                ))}
              </div>
            </div>

            <div className="text-[11px] text-slate-400 flex items-center justify-between pt-1">
              <span>Umumiy: <strong className="text-white">9.7 soat</strong></span>
              <span className="text-emerald-400 font-black">92%</span>
            </div>
          </div>

          {/* Widget 4: So'nggi natijalar */}
          <div className="bg-slate-900/80 p-5 rounded-3xl border border-white/10 shadow-lg flex flex-col justify-between space-y-3 backdrop-blur-xl">
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <h4 className="text-xs font-black text-white">So‘nggi natijalar</h4>
                <button
                  onClick={onOpenProgress}
                  className="text-[10px] font-black text-cyan-400 hover:underline cursor-pointer"
                >
                  Barchasini ko‘rish →
                </button>
              </div>

              {/* Result items strictly isolated by subject */}
              <div className="space-y-2">
                {subjectRecentResults.map((item, idx) => (
                  <div key={idx} className="flex items-center justify-between text-xs">
                    <div className="flex items-center gap-1.5 truncate max-w-[150px]">
                      <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400 shrink-0" />
                      <span className="font-bold text-slate-200 text-[11px] truncate">{item.title}</span>
                    </div>
                    <span className="text-[11px] font-black text-emerald-400 shrink-0">{item.xp}</span>
                  </div>
                ))}
              </div>
            </div>

            <div className="pt-2 border-t border-white/10 flex items-center justify-between text-[11px] text-slate-400">
              <span>Umumiy bilim:</span>
              <strong className="text-cyan-300 font-black">{overallScore}%</strong>
            </div>
          </div>

        </div>

      </main>
    </div>
  );
};
