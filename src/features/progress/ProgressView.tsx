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
      bg: 'from-amber-400 to-amber-600',
    },
    {
      id: 2,
      title: 'Tushunish Chempioni',
      desc: '90%+ to‘g‘ri javoblar',
      icon: '🎯',
      earned: true,
      bg: 'from-cyan-400 to-blue-600',
    },
    {
      id: 3,
      title: 'Mavzu Master',
      desc: 'Modul darslari 100%',
      icon: '⭐',
      earned: true,
      bg: 'from-indigo-500 to-purple-600',
    },
    {
      id: 4,
      title: 'Yo‘lchi AI Do‘sti',
      desc: 'AI bilan chuqur tahlil',
      icon: '🤖',
      earned: true,
      bg: 'from-emerald-400 to-teal-600',
    },
  ];

  const subjectProgress = [
    { id: 'course_math_01', name: 'Matematika', color: 'bg-indigo-600', icon: '📐' },
    { id: 'course_eng_01', name: 'Ingliz tili', color: 'bg-rose-500', icon: '🇬🇧' },
    { id: 'course_it', name: 'IT & Algoritmlar', color: 'bg-cyan-500', icon: '💻' },
    { id: 'course_logic', name: 'Mantiqiy fikrlash', color: 'bg-amber-500', icon: '🧩' },
  ].map((meta) => {
    const courseScores = profile?.scoresByCourse?.[meta.id];
    const score = courseScores ? SkillScoringEngine.computeOverallScore(courseScores) : null;
    return { ...meta, score };
  });

  return (
    <div className="max-w-5xl mx-auto px-4 py-8 space-y-8">
      {/* Top Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-6 border-b border-slate-200">
        <div>
          <div className="flex items-center gap-2 mb-1.5">
            <Badge variant="blue" size="sm">
              <TrendingUp className="w-3.5 h-3.5 mr-1" />
              Real Natijalar
            </Badge>
            <span className="text-xs font-semibold text-slate-500">
              {activeCourse?.title || 'Fan tanlanmagan'} • Shaxsiy statistika
            </span>
          </div>
          <h1 className="text-2xl sm:text-3xl font-black text-slate-900 tracking-tight">
            Mening Natijalarim
          </h1>
          <p className="text-sm text-slate-600 mt-1">
            Har bir dars, test va AI tahlillari bo‘yicha o‘zlashtirish monitoringi
          </p>
        </div>

        {/* Timeframe pill selector */}
        <div className="flex items-center gap-2 bg-slate-100 p-1 rounded-2xl border border-slate-200 self-start sm:self-auto">
          <button
            onClick={() => setTimeframe('week')}
            className={`px-4 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
              timeframe === 'week' ? 'bg-white text-indigo-700 shadow-xs' : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            Bu hafta
          </button>
          <button
            onClick={() => setTimeframe('month')}
            className={`px-4 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
              timeframe === 'month' ? 'bg-white text-indigo-700 shadow-xs' : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            Bu oy
          </button>
        </div>
      </div>

      {/* 4 Quick Stat Cards (Reference 2 style) */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Card 1: Completed lessons */}
        <Card className="p-5 border-slate-200/90 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-2xl bg-emerald-50 text-emerald-600 border border-emerald-200 flex items-center justify-center shrink-0">
            <CheckCircle2 className="w-6 h-6" />
          </div>
          <div>
            <div className="text-2xl font-black text-slate-900">28</div>
            <div className="text-xs font-bold text-slate-500">Bajarilgan dars</div>
          </div>
        </Card>

        {/* Card 2: Accuracy rate */}
        <Card className="p-5 border-slate-200/90 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-2xl bg-cyan-50 text-cyan-600 border border-cyan-200 flex items-center justify-center shrink-0">
            <TrendingUp className="w-6 h-6" />
          </div>
          <div>
            <div className="text-2xl font-black text-slate-900">92%</div>
            <div className="text-xs font-bold text-slate-500">To‘g‘ri javoblar</div>
          </div>
        </Card>

        {/* Card 3: Streak */}
        <Card className="p-5 border-slate-200/90 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-2xl bg-amber-50 text-amber-600 border border-amber-200 flex items-center justify-center shrink-0">
            <Flame className="w-6 h-6 fill-amber-500" />
          </div>
          <div>
            <div className="text-2xl font-black text-slate-900">
              {profile?.streakDays || 5} kun
            </div>
            <div className="text-xs font-bold text-slate-500">Ketma-ketlik 🔥</div>
          </div>
        </Card>

        {/* Card 4: XP */}
        <Card className="p-5 border-slate-200/90 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-2xl bg-indigo-50 text-indigo-600 border border-indigo-200 flex items-center justify-center shrink-0">
            <Award className="w-6 h-6" />
          </div>
          <div>
            <div className="text-2xl font-black text-slate-900">
              {profile?.xp || 1200}
            </div>
            <div className="text-xs font-bold text-slate-500">Umumiy XP ✨</div>
          </div>
        </Card>
      </div>

      {/* Center 2-Column: Weekly Time Chart & Overall Gauge */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Weekly Study Time Bar Chart (Reference 2 style) */}
        <Card className="p-6 border-slate-200/90 shadow-md lg:col-span-2 space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Clock className="w-5 h-5 text-indigo-600" />
              <h3 className="text-base font-extrabold text-slate-900">O‘qish vaqti</h3>
            </div>
            <span className="text-xs font-bold text-indigo-700 bg-indigo-50 px-2.5 py-1 rounded-xl border border-indigo-200">
              Soat / Kun
            </span>
          </div>

          <p className="text-xs text-slate-500">
            Haftalik umumiy sarflangan faol vaqt: <strong>9.7 soat</strong> (o‘rtacha 1.4 soat/kun)
          </p>

          {/* Bar Chart Visualization */}
          <div className="h-48 pt-4 flex items-end justify-between gap-3 px-2 border-b border-slate-100">
            {weeklyData.map((d, i) => {
              const heightPct = Math.round((d.hours / maxHours) * 100);
              return (
                <div key={i} className="flex-1 flex flex-col items-center gap-2 h-full justify-end group">
                  <span className="text-[11px] font-bold text-slate-600 opacity-90 group-hover:text-indigo-600 transition-colors">
                    {d.hours}
                  </span>
                  <motion.div
                    initial={{ height: 0 }}
                    animate={{ height: `${heightPct}%` }}
                    transition={{ duration: 0.6, delay: i * 0.08 }}
                    className={`w-full max-w-[36px] rounded-t-xl transition-all duration-200 ${
                      d.isPeak
                        ? 'bg-gradient-to-t from-blue-600 via-indigo-600 to-cyan-400 shadow-md shadow-indigo-500/30'
                        : 'bg-gradient-to-t from-cyan-500 to-blue-500 hover:from-cyan-400 hover:to-blue-600'
                    }`}
                  />
                  <span className="text-xs font-extrabold text-slate-500 pt-1">{d.day}</span>
                </div>
              );
            })}
          </div>

          <div className="flex items-center justify-between text-xs text-slate-500 pt-2">
            <span className="flex items-center gap-1.5">
              <span className="w-2.5 h-2.5 rounded-full bg-indigo-600 inline-block" />
              Eng faol kun: Payshanba (2.1 soat)
            </span>
            <span className="text-emerald-600 font-bold">O‘sish: +18% o‘tgan haftaga nisbatan</span>
          </div>
        </Card>

        {/* Circular Gauge Card (Reference 1 & 2: 72% Circular Gauge) */}
        <Card className="p-6 border-slate-200/90 shadow-md flex flex-col items-center justify-center text-center space-y-4">
          <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
            Umumiy Bilim Bazasi
          </span>

          {/* Circular SVG Gauge */}
          <div className="relative w-40 h-40 flex items-center justify-center">
            <svg className="w-full h-full -rotate-90" viewBox="0 0 120 120">
              <circle
                cx="60"
                cy="60"
                r="48"
                fill="none"
                stroke="#E2E8F0"
                strokeWidth="10"
              />
              <circle
                cx="60"
                cy="60"
                r="48"
                fill="none"
                stroke="url(#progressRingGrad)"
                strokeWidth="10"
                strokeDasharray="301.6"
                strokeDashoffset={301.6 * (1 - overallScore / 100)}
                strokeLinecap="round"
                className="transition-all duration-1000 ease-out"
              />
              <defs>
                <linearGradient id="progressRingGrad" x1="0" y1="0" x2="1" y2="1">
                  <stop offset="0%" stopColor="#38BDF8" />
                  <stop offset="50%" stopColor="#4F46E5" />
                  <stop offset="100%" stopColor="#A855F7" />
                </linearGradient>
              </defs>
            </svg>
            <div className="absolute inset-0 flex flex-col items-center justify-center">
              <span className="text-4xl font-black text-slate-900 tracking-tight">
                {overallScore}%
              </span>
              <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider mt-0.5">
                O‘zlashtirish
              </span>
            </div>
          </div>

          <p className="text-xs font-semibold text-slate-600 px-2 leading-relaxed">
            Siz sinfdoshlaringizdan <strong>84%</strong> yuqoriroq natija qayd etmoqdasiz!
          </p>

          <Button
            variant="outline"
            size="sm"
            onClick={onOpenKnowledgeMap}
            leftIcon={<Compass className="w-4 h-4 text-indigo-600" />}
            className="w-full"
          >
            Bilim xaritasini ochish
          </Button>
        </Card>
      </div>

      {/* Subject Mastery Progress Bars & Gamified Rewards */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Subject Mastery (Reference 2) */}
        <Card className="p-6 border-slate-200/90 shadow-md space-y-4">
          <div className="flex items-center justify-between">
            <h3 className="text-base font-extrabold text-slate-900">
              Mavzular bo‘yicha natija
            </h3>
            <span className="text-xs text-slate-400 font-semibold">Real baholash</span>
          </div>

          <div className="space-y-4 pt-1">
            {subjectProgress.map((subj, idx) => (
              <div key={idx} className="space-y-1.5">
                <div className="flex items-center justify-between text-xs font-bold text-slate-800">
                  <span className="flex items-center gap-2">
                    <span>{subj.icon}</span>
                    <span>{subj.name}</span>
                  </span>
                  <span className="font-extrabold text-slate-900">
                    {subj.score !== null ? `${subj.score}%` : '—'}
                  </span>
                </div>
                <div className="h-2.5 w-full bg-slate-100 rounded-full overflow-hidden">
                  <motion.div
                    initial={{ width: 0 }}
                    animate={{ width: `${subj.score ?? 0}%` }}
                    transition={{ duration: 0.8, delay: idx * 0.1 }}
                    className={`h-full rounded-full ${subj.color}`}
                  />
                </div>
              </div>
            ))}
          </div>
        </Card>

        {/* Gamified Rewards Badges (Reference 5) */}
        <Card className="p-6 border-slate-200/90 shadow-md space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Trophy className="w-5 h-5 text-amber-500" />
              <h3 className="text-base font-extrabold text-slate-900">
                Yutuqlar va Nishonlar
              </h3>
            </div>
            <span className="text-xs font-bold text-amber-600 bg-amber-50 px-2 py-0.5 rounded-full border border-amber-200">
              4/4 Olingan
            </span>
          </div>

          <div className="grid grid-cols-2 gap-3 pt-1">
            {badges.map((b) => (
              <div
                key={b.id}
                className="p-3.5 rounded-2xl bg-gradient-to-br from-slate-50 to-white border border-slate-200/90 shadow-2xs flex items-center gap-3 hover:border-indigo-300 transition-colors"
              >
                <div className={`w-10 h-10 rounded-xl bg-gradient-to-tr ${b.bg} text-white flex items-center justify-center text-lg shrink-0 shadow-sm`}>
                  {b.icon}
                </div>
                <div className="min-w-0">
                  <h4 className="text-xs font-extrabold text-slate-900 truncate">
                    {b.title}
                  </h4>
                  <p className="text-[10px] text-slate-500 font-medium truncate">
                    {b.desc}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </Card>
      </div>

      {/* Floating Yo'lchi AI Encouragement Banner */}
      <Card variant="hero" className="p-6 sm:p-8">
        <div className="flex flex-col sm:flex-row items-center justify-between gap-6">
          <div className="flex items-center gap-5">
            <YolchiAIMascot size="lg" mood="celebrating" />
            <div className="space-y-1.5 text-center sm:text-left">
              <div className="flex items-center justify-center sm:justify-start gap-2">
                <span className="px-2 py-0.5 text-[10px] font-extrabold uppercase rounded-full bg-cyan-400 text-slate-900">
                  Yo‘lchi AI Maslahati
                </span>
                <span className="text-xs text-blue-200 font-semibold">Bugun</span>
              </div>
              <h3 className="text-xl sm:text-2xl font-black text-white">
                Ajoyib jadallashtirish! 🚀
              </h3>
              <p className="text-xs sm:text-sm text-indigo-100 max-w-lg leading-relaxed">
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
              className="w-full sm:w-auto bg-white/10 hover:bg-white/20 text-white border-white/20"
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
