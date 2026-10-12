import React, { useState } from 'react';
import { motion } from 'framer-motion';
import {
  TrendingUp,
  Clock,
  Flame,
  Award,
  CheckCircle2,
  Calendar,
  Sparkles,
  ArrowRight,
  BookOpen,
  BarChart3,
  Compass,
  Trophy,
  Zap,
} from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { SkillScoringEngine } from '@/domain/personalization/SkillScoringEngine';
import { Card } from '@/presentation/components/Card';
import { Button } from '@/presentation/components/Button';
import { Badge } from '@/presentation/components/Badge';
import { YolchiAIMascot } from '@/presentation/components/YolchiAIMascot';

interface ProgressViewProps {
  onContinueLesson: () => void;
  onOpenRoadmap: () => void;
  onOpenKnowledgeMap: () => void;
}

export const ProgressView: React.FC<ProgressViewProps> = ({
  onContinueLesson,
  onOpenRoadmap,
  onOpenKnowledgeMap,
}) => {
  const { activeCourse, activeCourseSkills } = useCourseStore();
  const { profile } = useLearnerStore();
  const [timeframe, setTimeframe] = useState<'week' | 'month'>('week');

  const scores = (profile?.scoresByCourse && activeCourse) ? (profile.scoresByCourse[activeCourse.id] || {}) : {};
  const overallScore = SkillScoringEngine.computeOverallScore(scores);

  const weeklyData = [
    { day: 'Dsh', hours: 1.2, isPeak: false },
    { day: 'Ssh', hours: 0.8, isPeak: false },
    { day: 'Chor', hours: 1.5, isPeak: false },
    { day: 'Pay', hours: 2.1, isPeak: true },
    { day: 'Jum', hours: 1.8, isPeak: false },
    { day: 'Shan', hours: 1.0, isPeak: false },
    { day: 'Yak', hours: 1.3, isPeak: false },
  ];

  const maxHours = Math.max(...weeklyData.map((d) => d.hours));

  const badges = [
    {
      id: 1,
      title: 'Muntazam O‘quvchi',
      desc: '7 kun uzluksiz o‘qish',
      icon: '🏆',
      earned: true,
      glow: 'shadow-amber-500/20 border-amber-500/30 text-amber-300',
      bg: 'from-amber-500/30 to-amber-900/40',
    },
    {
      id: 2,
      title: 'Tushunish Chempioni',
      desc: '90%+ to‘g‘ri javoblar',
      icon: '🎯',
      earned: true,
      glow: 'shadow-cyan-500/20 border-cyan-500/30 text-cyan-300',
      bg: 'from-cyan-500/30 to-blue-900/40',
    },
    {
      id: 3,
      title: 'Mavzu Master',
      desc: 'Modul darslari 100%',
      icon: '⭐',
      earned: true,
      glow: 'shadow-purple-500/20 border-purple-500/30 text-purple-300',
      bg: 'from-purple-500/30 to-indigo-900/40',
    },
    {
      id: 4,
      title: 'Yo‘lchi AI Do‘sti',
      desc: 'AI bilan chuqur tahlil',
      icon: '🤖',
      earned: true,
      glow: 'shadow-emerald-500/20 border-emerald-500/30 text-emerald-300',
      bg: 'from-emerald-500/30 to-teal-900/40',
    },
  ];

  const subjectProgress = [
    { id: 'course_math_01', name: 'Matematika', color: 'from-indigo-500 to-cyan-400', icon: '📐' },
    { id: 'course_eng_01', name: 'Ingliz tili', color: 'from-rose-500 to-pink-400', icon: '🇬🇧' },
    { id: 'course_it', name: 'IT & Algoritmlar', color: 'from-cyan-500 to-teal-400', icon: '💻' },
    { id: 'course_logic', name: 'Mantiqiy fikrlash', color: 'from-amber-500 to-yellow-400', icon: '🧩' },
  ].map((meta) => {
    const courseScores = profile?.scoresByCourse?.[meta.id];
    const score = courseScores ? SkillScoringEngine.computeOverallScore(courseScores) : null;
    return { ...meta, score };
  });

  return (
    <div className="max-w-5xl mx-auto px-4 py-8 space-y-8">
      {/* Top Header */}
      <motion.div
        initial={{ opacity: 0, y: -10 }}
        animate={{ opacity: 1, y: 0 }}
        className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-6 border-b border-slate-800/80"
      >
        <div>
          <div className="flex items-center gap-2 mb-2">
            <Badge variant="blue" size="sm" className="bg-cyan-950/80 text-cyan-300 border-cyan-500/40 shadow-xs shadow-cyan-500/20">
              <TrendingUp className="w-3.5 h-3.5 mr-1" />
              Real Natijalar
            </Badge>
            <span className="text-xs font-semibold text-slate-400">
              {activeCourse?.title || 'Fan tanlanmagan'} • Shaxsiy statistika
            </span>
          </div>
          <h1 className="text-2xl sm:text-3xl font-black text-white tracking-tight">
            Mening Natijalarim
          </h1>
          <p className="text-sm text-slate-400 mt-1">
            Har bir dars, test va AI tahlillari bo‘yicha o‘zlashtirish monitoringi
          </p>
        </div>

        {/* Timeframe pill selector */}
        <div className="flex items-center gap-1.5 bg-slate-900/90 p-1.5 rounded-2xl border border-slate-800 self-start sm:self-auto backdrop-blur-md">
          <button
            onClick={() => setTimeframe('week')}
            className={`px-4 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
              timeframe === 'week'
                ? 'bg-gradient-to-r from-cyan-500 to-blue-600 text-white shadow-sm shadow-cyan-500/30'
                : 'text-slate-400 hover:text-white'
            }`}
          >
            Bu hafta
          </button>
          <button
            onClick={() => setTimeframe('month')}
            className={`px-4 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
              timeframe === 'month'
                ? 'bg-gradient-to-r from-cyan-500 to-blue-600 text-white shadow-sm shadow-cyan-500/30'
                : 'text-slate-400 hover:text-white'
            }`}
          >
            Bu oy
          </button>
        </div>
      </motion.div>

      {/* 4 Quick Stat Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Card 1: Completed lessons */}
        <motion.div initial={{ opacity: 0, y: 15 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.05 }}>
          <Card variant="neonEmerald" className="p-5 flex items-center gap-4 bg-slate-900/80">
            <div className="w-12 h-12 rounded-2xl bg-emerald-500/10 text-emerald-400 border border-emerald-500/30 flex items-center justify-center shrink-0 shadow-sm shadow-emerald-500/20">
              <CheckCircle2 className="w-6 h-6" />
            </div>
            <div>
              <div className="text-2xl font-black text-white">28</div>
              <div className="text-xs font-bold text-slate-400">Bajarilgan dars</div>
            </div>
          </Card>
        </motion.div>

        {/* Card 2: Accuracy rate */}
        <motion.div initial={{ opacity: 0, y: 15 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.1 }}>
          <Card variant="neonCyan" className="p-5 flex items-center gap-4 bg-slate-900/80">
            <div className="w-12 h-12 rounded-2xl bg-cyan-500/10 text-cyan-400 border border-cyan-500/30 flex items-center justify-center shrink-0 shadow-sm shadow-cyan-500/20">
              <TrendingUp className="w-6 h-6" />
            </div>
            <div>
              <div className="text-2xl font-black text-white">92%</div>
              <div className="text-xs font-bold text-slate-400">To‘g‘ri javoblar</div>
            </div>
          </Card>
        </motion.div>

        {/* Card 3: Streak */}
        <motion.div initial={{ opacity: 0, y: 15 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.15 }}>
          <Card variant="neonAmber" className="p-5 flex items-center gap-4 bg-slate-900/80">
            <div className="w-12 h-12 rounded-2xl bg-amber-500/10 text-amber-400 border border-amber-500/30 flex items-center justify-center shrink-0 shadow-sm shadow-amber-500/20">
              <Flame className="w-6 h-6 fill-amber-400" />
            </div>
            <div>
              <div className="text-2xl font-black text-white">
                {profile?.streakDays || 5} kun
              </div>
              <div className="text-xs font-bold text-slate-400">Ketma-ketlik 🔥</div>
            </div>
          </Card>
        </motion.div>

        {/* Card 4: XP */}
        <motion.div initial={{ opacity: 0, y: 15 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }}>
          <Card variant="neonPurple" className="p-5 flex items-center gap-4 bg-slate-900/80">
            <div className="w-12 h-12 rounded-2xl bg-purple-500/10 text-purple-400 border border-purple-500/30 flex items-center justify-center shrink-0 shadow-sm shadow-purple-500/20">
              <Award className="w-6 h-6" />
            </div>
            <div>
              <div className="text-2xl font-black text-white">
                {profile?.xp || 1200}
              </div>
              <div className="text-xs font-bold text-slate-400">Umumiy XP ✨</div>
            </div>
          </Card>
        </motion.div>
      </div>

      {/* Center 2-Column: Weekly Time Chart & Overall Gauge */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Weekly Study Time Bar Chart */}
        <Card variant="cosmic" className="p-6 lg:col-span-2 space-y-5 bg-slate-900/85">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2.5">
              <div className="w-9 h-9 rounded-xl bg-cyan-500/10 border border-cyan-500/30 flex items-center justify-center text-cyan-400">
                <Clock className="w-5 h-5" />
              </div>
              <div>
                <h3 className="text-base font-extrabold text-white">O‘qish vaqti dinamikasi</h3>
                <p className="text-xs text-slate-400">Haftalik umumiy faol vaqt: 9.7 soat (1.4 soat/kun)</p>
              </div>
            </div>
            <span className="text-xs font-bold text-cyan-300 bg-cyan-950/80 px-3 py-1 rounded-xl border border-cyan-500/30 shadow-xs">
              Soat / Kun
            </span>
          </div>

          {/* Bar Chart Visualization */}
          <div className="h-52 pt-6 flex items-end justify-between gap-3 px-2 border-b border-slate-800/80">
            {weeklyData.map((d, i) => {
              const heightPct = Math.round((d.hours / maxHours) * 100);
              return (
                <div key={i} className="flex-1 flex flex-col items-center gap-2 h-full justify-end group">
                  <span className="text-[11px] font-bold text-slate-400 opacity-90 group-hover:text-cyan-300 transition-colors">
                    {d.hours}s
                  </span>
                  <motion.div
                    initial={{ height: 0 }}
                    animate={{ height: `${heightPct}%` }}
                    transition={{ duration: 0.7, delay: i * 0.08 }}
                    className={`w-full max-w-[40px] rounded-t-xl transition-all duration-300 cursor-pointer ${
                      d.isPeak
                        ? 'bg-gradient-to-t from-blue-600 via-indigo-600 to-cyan-400 shadow-lg shadow-cyan-500/40 ring-1 ring-cyan-300/40'
                        : 'bg-gradient-to-t from-slate-800 to-cyan-500/60 hover:from-cyan-600 hover:to-cyan-400 hover:shadow-md hover:shadow-cyan-500/30'
                    }`}
                  />
                  <span className={`text-xs font-extrabold pt-1 ${d.isPeak ? 'text-cyan-400' : 'text-slate-400'}`}>
                    {d.day}
                  </span>
                </div>
              );
            })}
          </div>

          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between text-xs text-slate-400 pt-1 gap-2">
            <span className="flex items-center gap-1.5">
              <span className="w-2.5 h-2.5 rounded-full bg-cyan-400 inline-block shadow-xs shadow-cyan-400/50" />
              Eng faol kun: Payshanba (2.1 soat)
            </span>
            <span className="text-emerald-400 font-bold flex items-center gap-1">
              <TrendingUp className="w-3.5 h-3.5" />
              O‘sish: +18% o‘tgan haftaga nisbatan
            </span>
          </div>
        </Card>

        {/* Circular Gauge Card */}
        <Card variant="cosmicGlow" className="p-6 flex flex-col items-center justify-center text-center space-y-4 bg-slate-900/90">
          <span className="text-xs font-bold text-slate-400 uppercase tracking-wider">
            Umumiy Bilim Bazasi
          </span>

          {/* Circular SVG Gauge */}
          <div className="relative w-44 h-44 flex items-center justify-center">
            <svg className="w-full h-full -rotate-90 drop-shadow-[0_0_15px_rgba(56,189,248,0.25)]" viewBox="0 0 120 120">
              <circle
                cx="60"
                cy="60"
                r="48"
                fill="none"
                stroke="#1e293b"
                strokeWidth="10"
              />
              <circle
                cx="60"
                cy="60"
                r="48"
                fill="none"
                stroke="url(#progressRingGradCosmic)"
                strokeWidth="10"
                strokeDasharray="301.6"
                strokeDashoffset={301.6 * (1 - overallScore / 100)}
                strokeLinecap="round"
                className="transition-all duration-1000 ease-out"
              />
              <defs>
                <linearGradient id="progressRingGradCosmic" x1="0" y1="0" x2="1" y2="1">
                  <stop offset="0%" stopColor="#38BDF8" />
                  <stop offset="50%" stopColor="#818CF8" />
                  <stop offset="100%" stopColor="#C084FC" />
                </linearGradient>
              </defs>
            </svg>
            <div className="absolute inset-0 flex flex-col items-center justify-center">
              <span className="text-4xl font-black text-white tracking-tight">
                {overallScore}%
              </span>
              <span className="text-[11px] font-bold text-cyan-300 uppercase tracking-wider mt-0.5">
                O‘zlashtirish
              </span>
            </div>
          </div>

          <p className="text-xs font-medium text-slate-300 px-2 leading-relaxed">
            Siz sinfdoshlaringizdan <strong className="text-cyan-300">84%</strong> yuqoriroq natija qayd etmoqdasiz!
          </p>

          <Button
            variant="cyan"
            size="sm"
            onClick={onOpenKnowledgeMap}
            leftIcon={<Compass className="w-4 h-4" />}
            className="w-full font-bold"
          >
            Bilim xaritasini ochish
          </Button>
        </Card>
      </div>

      {/* Subject Mastery Progress Bars & Gamified Rewards */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Subject Mastery */}
        <Card variant="cosmic" className="p-6 space-y-5 bg-slate-900/85">
          <div className="flex items-center justify-between">
            <h3 className="text-base font-extrabold text-white flex items-center gap-2">
              <BookOpen className="w-5 h-5 text-indigo-400" />
              Mavzular bo‘yicha natija
            </h3>
            <span className="text-xs text-slate-400 font-semibold">Real baholash</span>
          </div>

          <div className="space-y-4 pt-1">
            {subjectProgress.map((subj, idx) => (
              <div key={idx} className="space-y-1.5">
                <div className="flex items-center justify-between text-xs font-bold text-slate-300">
                  <span className="flex items-center gap-2">
                    <span className="text-base">{subj.icon}</span>
                    <span className="text-white">{subj.name}</span>
                  </span>
                  <span className="font-extrabold text-cyan-300">
                    {subj.score !== null ? `${subj.score}%` : '—'}
                  </span>
                </div>
                <div className="h-2.5 w-full bg-slate-800/90 rounded-full overflow-hidden border border-slate-700/50">
                  <motion.div
                    initial={{ width: 0 }}
                    animate={{ width: `${subj.score ?? 0}%` }}
                    transition={{ duration: 0.8, delay: idx * 0.1 }}
                    className={`h-full rounded-full bg-gradient-to-r ${subj.color} shadow-sm shadow-cyan-500/30`}
                  />
                </div>
              </div>
            ))}
          </div>
        </Card>

        {/* Gamified Rewards Badges */}
        <Card variant="cosmic" className="p-6 space-y-5 bg-slate-900/85">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Trophy className="w-5 h-5 text-amber-400" />
              <h3 className="text-base font-extrabold text-white">
                Yutuqlar va Nishonlar
              </h3>
            </div>
            <span className="text-xs font-bold text-amber-300 bg-amber-950/80 px-2.5 py-0.5 rounded-full border border-amber-500/30 shadow-xs shadow-amber-500/20">
              4/4 Olingan
            </span>
          </div>

          <div className="grid grid-cols-2 gap-3 pt-1">
            {badges.map((b) => (
              <div
                key={b.id}
                className={`p-3.5 rounded-2xl bg-slate-900/90 border border-slate-800 flex items-center gap-3 hover:border-slate-700 transition-all ${b.glow}`}
              >
                <div className={`w-10 h-10 rounded-xl bg-gradient-to-tr ${b.bg} text-white flex items-center justify-center text-lg shrink-0 border border-white/10 shadow-sm`}>
                  {b.icon}
                </div>
                <div className="min-w-0">
                  <h4 className="text-xs font-extrabold text-white truncate">
                    {b.title}
                  </h4>
                  <p className="text-[10px] text-slate-400 font-medium truncate">
                    {b.desc}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </Card>
      </div>

      {/* Floating Yo'lchi AI Encouragement Banner */}
      <Card variant="cosmicGlow" className="p-6 sm:p-8 bg-gradient-to-r from-slate-900 via-indigo-950/90 to-slate-900 border-indigo-500/40">
        <div className="flex flex-col sm:flex-row items-center justify-between gap-6">
          <div className="flex items-center gap-5">
            <YolchiAIMascot size="lg" mood="celebrating" variant="dark" />
            <div className="space-y-1.5 text-center sm:text-left">
              <div className="flex items-center justify-center sm:justify-start gap-2">
                <span className="px-2.5 py-0.5 text-[10px] font-extrabold uppercase rounded-full bg-cyan-400 text-slate-950 shadow-xs shadow-cyan-400/40">
                  Yo‘lchi AI Maslahati
                </span>
                <span className="text-xs text-indigo-300 font-semibold">Bugun</span>
              </div>
              <h3 className="text-xl sm:text-2xl font-black text-white">
                Ajoyib jadallashtirish! 🚀
              </h3>
              <p className="text-xs sm:text-sm text-slate-300 max-w-lg leading-relaxed">
                Oxirgi 3 ta mashg‘ulotda tenglamalar bo‘yicha aniqligingiz 22% ga oshdi.
                Keyingi darsni yakunlasangiz yangi nishon qo‘lga kiritasiz!
              </p>
            </div>
          </div>

          <div className="flex flex-col sm:flex-row items-center gap-3 w-full sm:w-auto shrink-0">
            <Button
              variant="outline"
              size="md"
              onClick={onOpenRoadmap}
              className="w-full sm:w-auto bg-slate-800/80 hover:bg-slate-700 text-white border-slate-700"
            >
              Ta’lim yo‘li
            </Button>
            <Button
              variant="cyan"
              size="md"
              onClick={onContinueLesson}
              rightIcon={<ArrowRight className="w-5 h-5" />}
              className="w-full sm:w-auto font-black"
            >
              Darsni boshlash
            </Button>
          </div>
        </div>
      </Card>
    </div>
  );
};

