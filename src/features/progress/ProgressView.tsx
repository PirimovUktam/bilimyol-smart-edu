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
  Brain,
  Calculator,
  Code2,
  Headphones,
  BookOpen,
  Target,
  Star,
  Bot,
  Lock,
  type LucideIcon,
} from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { SkillScoringEngine } from '@/domain/personalization/SkillScoringEngine';
import { supabaseLearnerRepository } from '@/data/repositories/SupabaseLearnerRepository';
import { DailyActivitySummary } from '@/domain/repositories/ILearnerRepository';
import { Button } from '@/presentation/components/Button';
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
  const { activeCourse, courses } = useCourseStore();
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

  // Real learner achievements
  const badgeDefs: { id: number; title: string; desc: string; icon: LucideIcon; earned: boolean }[] = [
    { id: 1, title: 'Muntazam O‘quvchi', desc: '7 kun uzluksiz o‘qish', icon: Trophy, earned: (profile?.streakDays ?? 0) >= 7 },
    { id: 2, title: 'Tushunish Chempioni', desc: '90%+ o‘zlashtirish', icon: Target, earned: overallScore >= 90 },
    { id: 3, title: 'Mavzu Master', desc: '5+ dars tugatilgan', icon: Star, earned: completedLessons >= 5 },
    { id: 4, title: 'Ilk Qadam', desc: 'Birinchi dars yakunlandi', icon: Bot, earned: completedLessons >= 1 },
  ];
  const earnedCount = badgeDefs.filter((b) => b.earned).length;

  const courseIcons: Record<string, LucideIcon> = {
    Calculator,
    Headphones,
    Code2,
    Brain,
    BookOpen,
  };
  const subjectProgress = courses.map((course) => {
    const courseScores = profile?.scoresByCourse?.[course.id];
    const score = courseScores ? SkillScoringEngine.computeOverallScore(courseScores) : null;
    return {
      id: course.id,
      name: course.title,
      icon: courseIcons[course.iconName] || BookOpen,
      color: course.primaryColorHex || course.primaryColor || '#10151f',
      score,
    };
  });

  return (
    <div className="max-w-6xl mx-auto px-4 py-8 space-y-8">
      {/* Top Header */}
      <div className="flex flex-col sm:flex-row sm:items-end justify-between gap-4 pb-6 border-b border-[#e4ddce]">
        <div className="space-y-1">
          <div className="editorial-kicker">
            <span>ANALITIK DOSYE</span>
            <span>//</span>
            <span>PROGRESS MONITORING</span>
          </div>
          <h1 className="font-display text-2xl sm:text-3xl font-extrabold text-[#10151f] tracking-tight">
            Ta’lim Ko‘rsatkichlari & Analitika
          </h1>
          <p className="text-xs text-slate-500">
            {activeCourse?.title || 'Fan tanlanmagan'} bo‘yicha individual faollik va ko‘nikmalar dinamikasi
          </p>
        </div>

        {/* Timeframe pill selector */}
        <div className="flex items-center gap-1 bg-[#f5efe4] p-1 rounded-xl border border-[#e4ddce] self-start sm:self-auto">
          <button
            onClick={() => setTimeframe('week')}
            className={`px-3 py-1.5 rounded-lg font-mono text-xs font-bold transition-all cursor-pointer ${
              timeframe === 'week' ? 'bg-[#10151f] text-white shadow-2xs' : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            HAFTALIK
          </button>
          <button
            onClick={() => setTimeframe('month')}
            className={`px-3 py-1.5 rounded-lg font-mono text-xs font-bold transition-all cursor-pointer ${
              timeframe === 'month' ? 'bg-[#10151f] text-white shadow-2xs' : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            OYLIK
          </button>
        </div>
      </div>

      {/* 4 Telemetry Tablets */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="p-5 rounded-2xl bg-white border border-[#e4ddce] shadow-xs flex items-center gap-4">
          <div className="w-11 h-11 rounded-xl bg-[#fbf9f4] border border-[#e4ddce] text-mint flex items-center justify-center shrink-0">
            <CheckCircle2 className="w-5 h-5" />
          </div>
          <div>
            <div className="font-mono-num text-2xl font-black text-[#10151f]">{completedLessons}</div>
            <div className="font-mono text-[10px] font-bold text-slate-500 uppercase tracking-wider">Tugatilgan dars</div>
          </div>
        </div>

        <div className="p-5 rounded-2xl bg-white border border-[#e4ddce] shadow-xs flex items-center gap-4">
          <div className="w-11 h-11 rounded-xl bg-[#fbf9f4] border border-[#e4ddce] text-brand-dark flex items-center justify-center shrink-0">
            <TrendingUp className="w-5 h-5" />
          </div>
          <div>
            <div className="font-mono-num text-2xl font-black text-[#10151f]">{overallScore}%</div>
            <div className="font-mono text-[10px] font-bold text-slate-500 uppercase tracking-wider">O‘zlashtirish</div>
          </div>
        </div>

        <div className="p-5 rounded-2xl bg-white border border-[#e4ddce] shadow-xs flex items-center gap-4">
          <div className="w-11 h-11 rounded-xl bg-[#fbf9f4] border border-[#e4ddce] text-amber-600 flex items-center justify-center shrink-0">
            <Flame className="w-5 h-5 fill-amber-500" />
          </div>
          <div>
            <div className="font-mono-num text-2xl font-black text-[#10151f]">
              {profile?.streakDays ?? 0} <span className="text-sm font-bold font-sans">kun</span>
            </div>
            <div className="font-mono text-[10px] font-bold text-slate-500 uppercase tracking-wider">Uzluksiz streak</div>
          </div>
        </div>

        <div className="p-5 rounded-2xl bg-white border border-[#e4ddce] shadow-xs flex items-center gap-4">
          <div className="w-11 h-11 rounded-xl bg-[#fbf9f4] border border-[#e4ddce] text-slate-800 flex items-center justify-center shrink-0">
            <Award className="w-5 h-5" />
          </div>
          <div>
            <div className="font-mono-num text-2xl font-black text-[#10151f]">
              {profile?.xp ?? 0}
            </div>
            <div className="font-mono text-[10px] font-bold text-slate-500 uppercase tracking-wider">Jamg‘arilgan XP</div>
          </div>
        </div>
      </div>

      {/* Center 2-Column: Activity Chart & Overall Gauge */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="p-6 sm:p-7 rounded-2xl border border-[#e4ddce] bg-white shadow-xs lg:col-span-2 space-y-5">
          <div className="flex items-center justify-between pb-3 border-b border-[#e4ddce]">
            <div className="flex items-center gap-2">
              <Clock className="w-4 h-4 text-slate-700" />
              <h3 className="font-display text-base font-bold text-[#10151f]">O‘quv Vaqti Xronologiyasi</h3>
            </div>
            <span className="font-mono text-[10px] font-bold px-2 py-0.5 rounded bg-[#fbf9f4] border border-[#e4ddce] text-slate-600">
              SOAT / KUN
            </span>
          </div>

          <div className="flex items-center justify-between text-xs text-slate-600">
            <span>
              {timeframe === 'week' ? 'Haftalik' : 'Oylik'} umumiy vaqt:{' '}
              <strong className="text-slate-900 font-mono-num">{totalHours} soat</strong> (o‘rtacha {avgPerDay} soat/kun)
            </span>
            <span className="font-mono text-xs font-bold text-brand-dark">Jami savollar: {totalQuestions}</span>
          </div>

          {activityError && (
            <p role="alert" className="text-xs font-mono font-bold text-coral">
              Faollik ma’lumotlari yuklanmadi: {activityError}
            </p>
          )}

          {/* Bar Chart Visualization */}
          <div className="h-48 pt-4 flex items-end justify-between gap-1.5 px-2 border-b border-[#e4ddce]">
            {isLoadingActivity ? (
              <div className="w-full h-full flex items-center justify-center">
                <div className="w-6 h-6 border-2 border-[#10151f] border-t-transparent rounded-full animate-spin" />
              </div>
            ) : chartData.length === 0 || totalMinutes === 0 ? (
              <div className="w-full h-full flex items-center justify-center font-mono text-xs text-slate-400">
                Hali o‘quv faoliyati qayd etilmagan.
              </div>
            ) : (
              chartData.map((d, i) => {
                const heightPct = Math.round((d.hours / maxHours) * 100);
                const showLabel = timeframe === 'week' || i % 5 === 0;
                return (
                  <div key={i} className="flex-1 flex flex-col items-center gap-1.5 h-full justify-end group">
                    <span className="font-mono text-[10px] font-bold text-slate-500 group-hover:text-[#10151f] transition-colors">
                      {d.hours > 0 ? d.hours : ''}
                    </span>
                    <motion.div
                      initial={{ height: 0 }}
                      animate={{ height: `${Math.max(heightPct, d.hours > 0 ? 8 : 2)}%` }}
                      transition={{ duration: 0.5, delay: Math.min(i, 10) * 0.04 }}
                      className={`w-full max-w-[32px] rounded-t-md transition-all duration-200 ${
                        d.isPeak
                          ? 'bg-[#10151f] shadow-xs'
                          : 'bg-[#cbd5e1] hover:bg-slate-700'
                      }`}
                    />
                    <span className="font-mono text-[10px] font-bold text-slate-500 pt-1">{showLabel ? d.label : ''}</span>
                  </div>
                );
              })
            )}
          </div>

          <div className="flex items-center justify-between font-mono text-[11px] text-slate-500">
            <span className="flex items-center gap-2">
              <span className="w-2.5 h-2.5 rounded-sm bg-[#10151f] inline-block" />
              Eng faol nuqta: {peakEntry ? `${peakEntry.label} (${peakEntry.hours} soat)` : '—'}
            </span>
            <span>REAL-TIME TELEMETRY</span>
          </div>
        </div>

        {/* Circular Gauge Card */}
        <div className="p-6 sm:p-7 rounded-2xl border border-[#e4ddce] bg-white shadow-xs flex flex-col items-center justify-between text-center space-y-4">
          <div className="w-full pb-3 border-b border-[#e4ddce] text-left">
            <span className="font-mono text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
              INDIVIDUAL MATRIX
            </span>
            <h3 className="font-display text-base font-bold text-[#10151f]">
              Umumiy O‘zlashtirish
            </h3>
          </div>

          <div className="relative w-40 h-40 flex items-center justify-center my-2">
            <svg className="w-full h-full -rotate-90" viewBox="0 0 120 120">
              <circle cx="60" cy="60" r="48" fill="none" stroke="#f5efe4" strokeWidth="9" />
              <circle
                cx="60"
                cy="60"
                r="48"
                fill="none"
                stroke="#10151f"
                strokeWidth="9"
                strokeDasharray="301.6"
                strokeDashoffset={301.6 * (1 - overallScore / 100)}
                strokeLinecap="round"
                className="transition-all duration-1000 ease-out"
              />
            </svg>
            <div className="absolute inset-0 flex flex-col items-center justify-center">
              <span className="font-mono-num text-4xl font-extrabold text-[#10151f] tracking-tight">
                {overallScore}%
              </span>
              <span className="font-mono text-[9px] font-bold text-slate-400 uppercase tracking-widest mt-0.5">
                BAHOLANGAN
              </span>
            </div>
          </div>

          <p className="text-xs text-slate-600 px-2 leading-relaxed font-medium">
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
            leftIcon={<Compass className="w-4 h-4 text-[#10151f]" />}
            className="w-full font-bold"
          >
            Bilim xaritasini ochish
          </Button>
        </div>
      </div>

      {/* Subject Mastery Progress Bars & Credential Stamps */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="p-6 sm:p-7 rounded-2xl border border-[#e4ddce] bg-white shadow-xs space-y-4">
          <div className="flex items-center justify-between pb-3 border-b border-[#e4ddce]">
            <h3 className="font-display text-base font-bold text-[#10151f]">
              Fanlar Bo‘yicha Natijalar
            </h3>
            <span className="font-mono text-[10px] font-bold text-slate-400 uppercase">MATRITSA</span>
          </div>

          <div className="space-y-3.5 pt-1">
            {subjectProgress.length === 0 ? (
              <p className="p-4 rounded-xl border border-[#e4ddce] bg-[#fbf9f4] font-mono text-xs text-slate-500">
                Hozircha fanlar bo‘yicha ma’lumot mavjud emas.
              </p>
            ) : subjectProgress.map((subj, idx) => {
              const Icon = subj.icon;
              return (
                <div key={subj.id} className="p-3 rounded-xl border border-[#e4ddce] bg-[#fbf9f4] space-y-2">
                  <div className="flex items-center justify-between text-xs font-bold text-slate-800">
                    <span className="flex items-center gap-2">
                      <Icon className="h-4 w-4 text-slate-700" aria-hidden="true" />
                      <span className="font-display text-sm">{subj.name}</span>
                    </span>
                    <span className="font-mono-num font-extrabold text-[#10151f]">
                      {subj.score !== null ? `${subj.score}%` : '—'}
                    </span>
                  </div>
                  <div className="h-2 w-full bg-white border border-[#e4ddce] rounded-full overflow-hidden">
                    <motion.div
                      initial={{ width: 0 }}
                      animate={{ width: `${subj.score ?? 0}%` }}
                      transition={{ duration: 0.6, delay: idx * 0.08 }}
                      className="h-full rounded-full bg-[#10151f]"
                    />
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        <div className="p-6 sm:p-7 rounded-2xl border border-[#e4ddce] bg-white shadow-xs space-y-4">
          <div className="flex items-center justify-between pb-3 border-b border-[#e4ddce]">
            <div className="flex items-center gap-2">
              <Trophy className="w-4 h-4 text-amber-500" />
              <h3 className="font-display text-base font-bold text-[#10151f]">
                Yutuqlar va Nishonlar
              </h3>
            </div>
            <span className="font-mono text-[10px] font-bold px-2 py-0.5 rounded bg-amber-50 border border-amber-200 text-amber-800">
              {earnedCount} / {badgeDefs.length} TASDIQLANGAN
            </span>
          </div>

          <div className="grid grid-cols-2 gap-3 pt-1">
            {badgeDefs.map((b) => (
              <div
                key={b.id}
                className={`p-3.5 rounded-xl border transition-colors flex items-center gap-3 ${
                  b.earned
                    ? 'bg-white border-[#10151f] shadow-xs'
                    : 'bg-[#fbf9f4] border-[#e4ddce] opacity-50'
                }`}
              >
                <div className={`w-9 h-9 rounded-lg flex items-center justify-center shrink-0 ${b.earned ? 'bg-[#10151f] text-white shadow-xs' : 'bg-[#e4ddce] text-slate-500'}`}>
                  {b.earned ? <b.icon className="w-4 h-4 text-amber-400" /> : <Lock className="w-4 h-4" />}
                </div>
                <div className="min-w-0">
                  <h4 className="font-display text-xs font-bold text-slate-900 truncate">
                    {b.title}
                  </h4>
                  <p className="font-mono text-[9px] text-slate-500 truncate">
                    {b.desc}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Floating Yo'lchi AI Encouragement Banner */}
      <div className="editorial-ink-hero p-6 sm:p-8 rounded-2xl">
        <div className="flex flex-col sm:flex-row items-center justify-between gap-6">
          <div className="flex items-center gap-5">
            <YolchiAIMascot size="lg" mood="celebrating" />
            <div className="space-y-1.5 text-center sm:text-left">
              <div className="flex items-center justify-center sm:justify-start gap-2">
                <span className="px-2 py-0.5 text-[9px] font-mono font-bold uppercase rounded bg-white text-[#10151f]">
                  YO‘LCHI AI TAVSIYASI
                </span>
                <span className="font-mono text-[10px] text-slate-400">BUGUNGI SUR’AT</span>
              </div>
              <h3 className="font-display text-xl sm:text-2xl font-bold text-white">
                {completedLessons > 0 ? 'Ajoyib sur’at bilan harakatlanyapsiz!' : 'Boshlashga tayyormisiz?'}
              </h3>
              <p className="text-xs sm:text-sm text-slate-300 max-w-lg leading-relaxed font-sans">
                {completedLessons > 0
                  ? `Siz allaqachon ${completedLessons} ta darsni yakunladingiz va jami ${profile?.xp ?? 0} XP to‘pladingiz. Keyingi darsni boshlab yangi marralarni zabt eting.`
                  : 'Birinchi darsni yakunlab, o‘z bilim xaritangizni shakllantirishni boshlang!'}
              </p>
            </div>
          </div>

          <div className="flex flex-col sm:flex-row items-center gap-3 w-full sm:w-auto shrink-0">
            <Button
              variant="outline"
              size="md"
              onClick={onOpenRoadmap}
              className="w-full sm:w-auto bg-white/10 hover:bg-white/20 text-white border-white/20 font-bold"
            >
              Ta’lim yo‘li
            </Button>
            <Button
              variant="cyan"
              size="md"
              onClick={onContinueLesson}
              rightIcon={<ArrowRight className="w-5 h-5" />}
              className="w-full sm:w-auto font-bold"
            >
              Darsni boshlash
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
};
