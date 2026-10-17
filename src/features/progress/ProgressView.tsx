import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import {
  TrendingUp,
  Clock,
  Flame,
  Award,
  CheckCircle2,
  ArrowRight,
  Compass,
  Trophy,
} from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { SkillScoringEngine } from '@/domain/personalization/SkillScoringEngine';
import { supabaseLearnerRepository } from '@/data/repositories/SupabaseLearnerRepository';
import { DailyActivitySummary } from '@/domain/repositories/ILearnerRepository';
import { Card } from '@/presentation/components/Card';
import { Button } from '@/presentation/components/Button';
import { Badge } from '@/presentation/components/Badge';
import { YolchiAIMascot } from '@/presentation/components/YolchiAIMascot';

interface ProgressViewProps {
  onContinueLesson: () => void;
  onOpenRoadmap: () => void;
  onOpenKnowledgeMap: () => void;
}

const DAY_NAMES = ['Yak', 'Dsh', 'Ssh', 'Chor', 'Pay', 'Jum', 'Shan'];

export const ProgressView: React.FC<ProgressViewProps> = ({
  onContinueLesson,
  onOpenRoadmap,
  onOpenKnowledgeMap,
}) => {
  const { activeCourse } = useCourseStore();
  const { profile } = useLearnerStore();
  const [timeframe, setTimeframe] = useState<'week' | 'month'>('week');
  const [activity, setActivity] = useState<DailyActivitySummary[]>([]);
  const [isLoadingActivity, setIsLoadingActivity] = useState(true);
  const [activityError, setActivityError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    setIsLoadingActivity(true);
    setActivityError(null);
    const days = timeframe === 'week' ? 7 : 30;
    supabaseLearnerRepository
      .getDailyActivity(days)
      .then((data) => {
        if (!cancelled) setActivity(data);
      })
      .catch((err) => {
        if (!cancelled) {
          setActivity([]);
          setActivityError(err instanceof Error ? err.message : 'Faollik ma’lumotlari yuklanmadi.');
        }
      })
      .finally(() => {
        if (!cancelled) setIsLoadingActivity(false);
      });
    return () => {
      cancelled = true;
    };
  }, [timeframe, activeCourse?.id]);

  const scores = (profile?.scoresByCourse && activeCourse) ? (profile.scoresByCourse[activeCourse.id] || {}) : {};
  const overallScore = SkillScoringEngine.computeOverallScore(scores);
  const completedLessons = profile?.completedLessonIds?.length ?? 0;
  const totalQuestions = activity.reduce((acc, d) => acc + Math.round(d.activeMinutes / 1.5), 0);

  const chartData = activity.map((d) => {
    const date = new Date(`${d.date}T00:00:00`);
    return {
      label: timeframe === 'week' ? (DAY_NAMES[date.getDay()] || '') : String(date.getDate()),
      hours: Math.round((d.activeMinutes / 60) * 10) / 10,
      isPeak: false,
    };
  });
  const maxHours = Math.max(...chartData.map((d) => d.hours), 1);
  chartData.forEach((d) => {
    if (d.hours === maxHours && d.hours > 0) d.isPeak = true;
  });

  const totalMinutes = activity.reduce((acc, d) => acc + d.activeMinutes, 0);
  const totalHours = Math.round((totalMinutes / 60) * 10) / 10;
  const avgPerDay = activity.length > 0 ? (totalHours / activity.length).toFixed(1) : '0.0';
  const peakEntry = chartData.find((d) => d.isPeak);

  // Achievements are computed from real learner metrics — never hardcoded.
  const badgeDefs = [
    { id: 1, title: 'Muntazam O‘quvchi', desc: '7 kun uzluksiz o‘qish', icon: '🏆', earned: (profile?.streakDays ?? 0) >= 7, bg: 'from-amber-400 to-amber-600' },
    { id: 2, title: 'Tushunish Chempioni', desc: '90%+ o‘zlashtirish', icon: '🎯', earned: overallScore >= 90, bg: 'from-cyan-400 to-blue-600' },
    { id: 3, title: 'Mavzu Master', desc: '5+ dars tugatilgan', icon: '⭐', earned: completedLessons >= 5, bg: 'from-indigo-500 to-purple-600' },
    { id: 4, title: 'Ilk Qadam', desc: 'Birinchi dars yakunlandi', icon: '🤖', earned: completedLessons >= 1, bg: 'from-emerald-400 to-teal-600' },
  ];
  const earnedCount = badgeDefs.filter((b) => b.earned).length;

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

        {/* Timeframe pill selector (switches the real data window) */}
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

      {/* 4 Quick Stat Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <Card className="p-5 border-slate-200/90 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-2xl bg-emerald-50 text-emerald-600 border border-emerald-200 flex items-center justify-center shrink-0">
            <CheckCircle2 className="w-6 h-6" />
          </div>
          <div>
            <div className="text-2xl font-black text-slate-900">{completedLessons}</div>
            <div className="text-xs font-bold text-slate-500">Bajarilgan dars</div>
          </div>
        </Card>

        <Card className="p-5 border-slate-200/90 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-2xl bg-cyan-50 text-cyan-600 border border-cyan-200 flex items-center justify-center shrink-0">
            <TrendingUp className="w-6 h-6" />
          </div>
          <div>
            <div className="text-2xl font-black text-slate-900">{overallScore}%</div>
            <div className="text-xs font-bold text-slate-500">O‘zlashtirish</div>
          </div>
        </Card>

        <Card className="p-5 border-slate-200/90 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-2xl bg-amber-50 text-amber-600 border border-amber-200 flex items-center justify-center shrink-0">
            <Flame className="w-6 h-6 fill-amber-500" />
          </div>
          <div>
            <div className="text-2xl font-black text-slate-900">
              {profile?.streakDays ?? 0} kun
            </div>
            <div className="text-xs font-bold text-slate-500">Ketma-ketlik 🔥</div>
          </div>
        </Card>

        <Card className="p-5 border-slate-200/90 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-2xl bg-indigo-50 text-indigo-600 border border-indigo-200 flex items-center justify-center shrink-0">
            <Award className="w-6 h-6" />
          </div>
          <div>
            <div className="text-2xl font-black text-slate-900">
              {profile?.xp ?? 0}
            </div>
            <div className="text-xs font-bold text-slate-500">Umumiy XP ✨</div>
          </div>
        </Card>
      </div>

      {/* Center 2-Column: Activity Chart & Overall Gauge */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
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
            {timeframe === 'week' ? 'Haftalik' : 'Oylik'} umumiy faol vaqt: <strong>{totalHours} soat</strong> (o‘rtacha {avgPerDay} soat/kun)
          </p>
          {activityError && (
            <p role="alert" className="text-xs font-semibold text-rose-600">
              Faollik ma’lumotlari yuklanmadi: {activityError}
            </p>
          )}

          {/* Bar Chart Visualization from real activity */}
          <div className="h-48 pt-4 flex items-end justify-between gap-1.5 px-2 border-b border-slate-100">
            {isLoadingActivity ? (
              <div className="w-full h-full flex items-center justify-center">
                <div className="w-8 h-8 border-4 border-indigo-500 border-t-transparent rounded-full animate-spin" />
              </div>
            ) : chartData.length === 0 || totalMinutes === 0 ? (
              <div className="w-full h-full flex items-center justify-center text-xs font-semibold text-slate-400">
                Hali o‘quv faoliyati qayd etilmagan.
              </div>
            ) : (
              chartData.map((d, i) => {
                const heightPct = Math.round((d.hours / maxHours) * 100);
                const showLabel = timeframe === 'week' || i % 5 === 0;
                return (
                  <div key={i} className="flex-1 flex flex-col items-center gap-2 h-full justify-end group">
                    <span className="text-[10px] font-bold text-slate-600 opacity-90 group-hover:text-indigo-600 transition-colors">
                      {d.hours > 0 ? d.hours : ''}
                    </span>
                    <motion.div
                      initial={{ height: 0 }}
                      animate={{ height: `${Math.max(heightPct, d.hours > 0 ? 8 : 2)}%` }}
                      transition={{ duration: 0.6, delay: Math.min(i, 10) * 0.05 }}
                      className={`w-full max-w-[36px] rounded-t-xl transition-all duration-200 ${
                        d.isPeak
                          ? 'bg-gradient-to-t from-blue-600 via-indigo-600 to-cyan-400 shadow-md shadow-indigo-500/30'
                          : 'bg-gradient-to-t from-cyan-500 to-blue-500 hover:from-cyan-400 hover:to-blue-600'
                      }`}
                    />
                    <span className="text-[10px] font-extrabold text-slate-500 pt-1">{showLabel ? d.label : ''}</span>
                  </div>
                );
              })
            )}
          </div>

          <div className="flex items-center justify-between text-xs text-slate-500 pt-2">
            <span className="flex items-center gap-1.5">
              <span className="w-2.5 h-2.5 rounded-full bg-indigo-600 inline-block" />
              Eng faol kun: {peakEntry ? `${peakEntry.label} (${peakEntry.hours} soat)` : '—'}
            </span>
            <span className="text-emerald-600 font-bold">Jami savollar: {totalQuestions}</span>
          </div>
        </Card>

        {/* Circular Gauge Card */}
        <Card className="p-6 border-slate-200/90 shadow-md flex flex-col items-center justify-center text-center space-y-4">
          <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
            Umumiy Bilim Bazasi
          </span>

          <div className="relative w-40 h-40 flex items-center justify-center">
            <svg className="w-full h-full -rotate-90" viewBox="0 0 120 120">
              <circle cx="60" cy="60" r="48" fill="none" stroke="#E2E8F0" strokeWidth="10" />
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
            {overallScore >= 80
              ? 'Ajoyib natija! Bilim darajangiz yuqori darajaga yaqinlashmoqda.'
              : overallScore >= 50
              ? 'Yaxshi sur’at! Mashqlarni davom ettirib, natijani yanada oshiring.'
              : 'Har bir dars natijani yaxshilaydi. Davom eting!'}
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

        <Card className="p-6 border-slate-200/90 shadow-md space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Trophy className="w-5 h-5 text-amber-500" />
              <h3 className="text-base font-extrabold text-slate-900">
                Yutuqlar va Nishonlar
              </h3>
            </div>
            <span className="text-xs font-bold text-amber-600 bg-amber-50 px-2 py-0.5 rounded-full border border-amber-200">
              {earnedCount}/{badgeDefs.length} Olingan
            </span>
          </div>

          <div className="grid grid-cols-2 gap-3 pt-1">
            {badgeDefs.map((b) => (
              <div
                key={b.id}
                className={`p-3.5 rounded-2xl border shadow-2xs flex items-center gap-3 transition-colors ${
                  b.earned
                    ? 'bg-gradient-to-br from-slate-50 to-white border-slate-200/90 hover:border-indigo-300'
                    : 'bg-slate-50/60 border-slate-200 opacity-60'
                }`}
              >
                <div className={`w-10 h-10 rounded-xl text-white flex items-center justify-center text-lg shrink-0 shadow-sm ${b.earned ? `bg-gradient-to-tr ${b.bg}` : 'bg-slate-300'}`}>
                  {b.earned ? b.icon : '🔒'}
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
                {completedLessons > 0 ? 'Ajoyib sur’at! 🚀' : 'Boshlashga tayyormisiz? 🚀'}
              </h3>
              <p className="text-xs sm:text-sm text-indigo-100 max-w-lg leading-relaxed">
                {completedLessons > 0
                  ? `Siz allaqachon ${completedLessons} ta darsni yakunladingiz va jami ${profile?.xp ?? 0} XP to‘pladingiz. Keyingi darsni tugatib, yana bir nishonga erishing!`
                  : 'Birinchi darsni yakunlab, o‘z bilim xaritangizni shakllantirishni boshlang!'}
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
