import React, { useEffect, useState } from 'react';
import {
  CheckCircle2,
  TrendingUp,
  Sparkles,
  ArrowRight,
  Flame,
  Bell,
  Map,
  Compass,
  RotateCcw,
  Award,
  XCircle,
  Bot,
  Brain,
  Calendar,
  Zap,
  Target,
  Clock,
  BookOpen,
} from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { useLessonStore } from '@/app/store/useLessonStore';
import { useAuth } from '@/core/context/AuthContext';
import { supabaseLearnerRepository } from '@/data/repositories/SupabaseLearnerRepository';
import { AnswerAttemptRecord } from '@/domain/repositories/ILearnerRepository';
import { SkillScoringEngine } from '@/domain/personalization/SkillScoringEngine';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';
import { Badge } from '@/presentation/components/Badge';

interface DashboardViewProps {
  onContinueLesson: () => void;
  onOpenRoadmap: () => void;
  onOpenKnowledgeMap: () => void;
  onResetDemo: () => void;
}

export const DashboardView: React.FC<DashboardViewProps> = ({
  onContinueLesson,
  onOpenRoadmap,
  onOpenKnowledgeMap,
  onResetDemo,
}) => {
  const { activeCourse, activeCourseSkills } = useCourseStore();
  const { profile } = useLearnerStore();
  const { profile: authProfile } = useAuth();
  const { loadRoadmap } = useRoadmapStore();
  const [recentAttempts, setRecentAttempts] = useState<AnswerAttemptRecord[]>([]);

  useEffect(() => {
    if (activeCourse) {
      loadRoadmap(activeCourse.id);
    }
    supabaseLearnerRepository.getAnswerAttempts(5).then(setRecentAttempts);
  }, [activeCourse, loadRoadmap, profile]);

  const scores = (profile?.scoresByCourse && activeCourse) ? (profile.scoresByCourse[activeCourse.id] || {}) : {};
  const overallScore = SkillScoringEngine.computeOverallScore(scores);

  // Find strongest and weakest skills dynamically
  let strongestSkillName = 'Algebra';
  let strongestScore = 0;
  let weakestSkillId = 'skill_math_functions';
  let weakestSkillName = 'Funksiyalar';
  let weakestScore = 100;

  activeCourseSkills.forEach((sk) => {
    const sc = scores[sk.id]?.score ?? 0;
    if (sc > strongestScore) {
      strongestScore = sc;
      strongestSkillName = sk.name;
    }
    if (sc <= weakestScore) {
      weakestScore = sc;
      weakestSkillId = sk.id;
      weakestSkillName = sk.name;
    }
  });

  const [isGeneratingAILesson, setIsGeneratingAILesson] = useState(false);

  const handleCreateAILesson = async () => {
    if (!activeCourse) return;
    setIsGeneratingAILesson(true);
    try {
      const difficulty = weakestScore < 40 ? 'easy' : weakestScore > 75 ? 'hard' : 'medium';
      await useLessonStore.getState().generateAILesson(
        activeCourse.id,
        weakestSkillId,
        weakestSkillName,
        difficulty
      );
      onContinueLesson();
    } finally {
      setIsGeneratingAILesson(false);
    }
  };

  const streakDays = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];
  const todayIdx = 2; // For demonstration Wednesday

  const achievements = [
    { id: 1, title: 'Dars ustasi', icon: '🏆', color: 'from-amber-400 to-amber-600', earned: true },
    { id: 2, title: 'Jonboz o‘quvchi', icon: '🚀', color: 'from-blue-500 to-indigo-600', earned: true },
    { id: 3, title: 'Ketma-ketlik chempioni', icon: '🔥', color: 'from-orange-500 to-rose-600', earned: true },
    { id: 4, title: 'Bilim kashfiyotchisi', icon: '🧭', color: 'from-teal-400 to-emerald-600', earned: true },
  ];

  return (
    <div className="max-w-5xl mx-auto px-4 py-8 space-y-8">
      {/* Reminder Banner */}
      <div className="p-4 rounded-2xl bg-gradient-to-r from-blue-600 to-indigo-600 text-white shadow-md flex items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-white/20 flex items-center justify-center shrink-0">
            <Bell className="w-5 h-5 animate-pulse" />
          </div>
          <div>
            <h4 className="font-bold text-sm">Bugungi o‘quv rejangiz</h4>
            <p className="text-xs text-blue-100">
              {activeCourse?.title || 'Matematika'} • {profile?.dailyMinutes || 15} daqiqa ajrating va ko‘nikmalaringizni mustahkamlang.
            </p>
          </div>
        </div>
        <Badge variant="blue" size="sm" className="bg-white/20 text-white border-white/30 hidden sm:inline-flex">
          KUNLIK REJA
        </Badge>
      </div>

      {/* Greeting & Quick Stats */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-4 border-b border-slate-200">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <Badge variant="emerald" size="sm">
              <CheckCircle2 className="w-3.5 h-3.5 mr-1" />
              Faol O‘quvchi
            </Badge>
            <span className="text-xs font-semibold text-slate-500">
              {activeCourse?.title || 'Matematika'}
            </span>
          </div>
          <h1 className="text-2xl sm:text-3xl font-extrabold text-slate-900 tracking-tight">
            Assalomu alaykum, {authProfile?.firstName || profile?.firstName || profile?.name || 'Foydalanuvchi'}!
          </h1>
          <p className="text-sm text-slate-600 mt-1">
            Shaxsiy moslashuvchan ta’lim yo‘lingiz bo‘yicha real ko‘rsatkichlar
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <Button
            variant="outline"
            size="md"
            onClick={onOpenRoadmap}
            leftIcon={<Map className="w-4 h-4 text-blue-600" />}
          >
            Yo‘l Xaritasi
          </Button>

          <Button
            variant="outline"
            size="md"
            onClick={handleCreateAILesson}
            disabled={isGeneratingAILesson}
            leftIcon={<Sparkles className={`w-4 h-4 text-amber-500 ${isGeneratingAILesson ? 'animate-spin' : ''}`} />}
            className="border-amber-300 bg-amber-50/50 hover:bg-amber-100/60 text-amber-900 font-semibold"
          >
            {isGeneratingAILesson ? 'AI Darsi Yaratilmoqda...' : 'Gemini AI Darsi'}
          </Button>

          <Button
            variant="primary"
            size="md"
            onClick={onContinueLesson}
            rightIcon={<ArrowRight className="w-5 h-5" />}
          >
            Darsni davom ettirish
          </Button>
        </div>
      </div>

      {/* Main Stats Cards Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Stat 1: Overall Subject Knowledge */}
        <Card className="p-5 border-slate-200/90 shadow-xs space-y-2">
          <div className="flex items-center justify-between text-slate-500 text-xs font-bold uppercase tracking-wider">
            <span>Umumiy Bilim</span>
            <TrendingUp className="w-4 h-4 text-blue-600" />
          </div>
          <div className="text-3xl font-black text-slate-900">{overallScore}%</div>
          <div className="h-1.5 w-full bg-slate-100 rounded-full overflow-hidden">
            <div className="h-full bg-blue-600 rounded-full" style={{ width: `${overallScore}%` }} />
          </div>
          <span className="text-[11px] text-slate-400 font-medium">Barcha ko‘nikmalar o‘rtachasi</span>
        </Card>

        {/* Stat 2: Weakest Skill / Focus */}
        <Card className="p-5 border-slate-200/90 shadow-xs space-y-2">
          <div className="flex items-center justify-between text-slate-500 text-xs font-bold uppercase tracking-wider">
            <span>Fokus Mavzu</span>
            <Sparkles className="w-4 h-4 text-amber-500" />
          </div>
          <div className="text-xl font-bold text-slate-900 truncate">
            {weakestSkillName}
          </div>
          <div className="text-xs font-bold text-amber-700 flex items-center gap-1.5">
            <span>{weakestScore}%</span>
            <span className="text-[10px] text-amber-800 font-bold bg-amber-50 px-1.5 py-0.5 rounded border border-amber-200">
              {SkillScoringEngine.getMasteryLabelUz(weakestScore)}
            </span>
          </div>
          <span className="text-[11px] text-slate-400 font-medium">Mustahkamlash talab etiladi</span>
        </Card>

        {/* Stat 3: Strongest Skill */}
        <Card className="p-5 border-slate-200/90 shadow-xs space-y-2">
          <div className="flex items-center justify-between text-slate-500 text-xs font-bold uppercase tracking-wider">
            <span>Kuchli Mavzu</span>
            <Award className="w-4 h-4 text-emerald-600" />
          </div>
          <div className="text-xl font-bold text-slate-900 truncate">
            {strongestSkillName}
          </div>
          <div className="text-xs font-bold text-emerald-700 flex items-center gap-1.5">
            <span>{strongestScore}%</span>
            <span className="text-[10px] text-emerald-800 font-bold bg-emerald-50 px-1.5 py-0.5 rounded border border-emerald-200">
              {SkillScoringEngine.getMasteryLabelUz(strongestScore)}
            </span>
          </div>
          <span className="text-[11px] text-slate-400 font-medium">Yaxshi o‘zlashtirilgan</span>
        </Card>

        {/* Stat 4: Gamification XP & Streak */}
        <Card className="p-5 border-slate-200/90 shadow-xs space-y-2">
          <div className="flex items-center justify-between text-slate-500 text-xs font-bold uppercase tracking-wider">
            <span>XP va Streak</span>
            <Flame className="w-4 h-4 text-orange-500 fill-orange-500" />
          </div>
          <div className="text-3xl font-black text-slate-900">
            {profile?.xp || 0} <span className="text-xs font-semibold text-slate-500">XP</span>
          </div>
          <div className="text-xs font-bold text-orange-600 flex items-center gap-1">
            <span>{profile?.streakDays || 7} kunlik faoliyat</span>
          </div>
          <span className="text-[11px] text-slate-400 font-medium">Kunlik faollik hisobi</span>
        </Card>
      </div>

      {/* Infographic 3 Section: Yo‘lchi AI Assistant Card & Streak/Gamification */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Yo‘lchi AI Assistant Interactive Dialogue matching Infographic 3 Step 13 */}
        <Card className="p-6 border-blue-200 bg-gradient-to-br from-blue-50/80 via-white to-indigo-50/50 shadow-md lg:col-span-2 space-y-4">
          <div className="flex items-start justify-between">
            <div className="flex items-center gap-3">
              <div className="w-12 h-12 rounded-2xl bg-gradient-to-tr from-blue-600 to-indigo-600 text-white flex items-center justify-center shadow-md shadow-blue-500/20">
                <Bot className="w-6 h-6" />
              </div>
              <div>
                <h3 className="text-base font-extrabold text-slate-900 flex items-center gap-1.5">
                  Yo‘lchi AI
                  <span className="text-[10px] font-extrabold px-1.5 py-0.5 rounded bg-blue-100 text-blue-800">
                    AI Yordamchi
                  </span>
                </h3>
                <p className="text-xs text-slate-500">Shaxsiy ta’lim mentori</p>
              </div>
            </div>
            <Badge variant="blue" size="sm">
              Online
            </Badge>
          </div>

          {/* Dialogue bubbles matching Infographic 3 Step 13 */}
          <div className="space-y-2.5 pt-1">
            <div className="p-3.5 bg-white rounded-2xl rounded-tl-xs border border-blue-100 shadow-xs max-w-md">
              <p className="text-xs sm:text-sm text-slate-800 font-semibold">
                Bugungi mavzuni birgalikda o‘rganamiz! Qanday topshiriq tayyorlay? 🚀
              </p>
            </div>
            <div className="p-3.5 bg-blue-600 text-white rounded-2xl rounded-tr-xs shadow-xs max-w-sm ml-auto text-right">
              <p className="text-xs sm:text-sm font-medium">
                Men uchun misollar ko‘proq bo‘lsin, iltimos.
              </p>
            </div>
            <div className="p-3.5 bg-white rounded-2xl rounded-tl-xs border border-blue-100 shadow-xs max-w-md">
              <p className="text-xs sm:text-sm text-slate-800 font-semibold">
                Albatta! Sizning darajangizga mos 5 ta misol tayyorladim. 💡
              </p>
            </div>
          </div>

          {/* Quick action prompt chips matching Infographic 3 Step 13 */}
          <div className="pt-2 flex flex-wrap items-center gap-2">
            {['Tushuntirish', 'Misollar', 'Interaktiv mashq', 'Savol-javob'].map((chip, idx) => (
              <button
                key={idx}
                type="button"
                onClick={handleCreateAILesson}
                className="px-3 py-1.5 rounded-xl border border-blue-200 bg-white hover:bg-blue-50 text-xs font-bold text-blue-800 transition-colors shadow-xs cursor-pointer"
              >
                {chip}
              </button>
            ))}
          </div>
        </Card>

        {/* 7-Day Streak & Badges matching Infographic 3 Step 17 */}
        <Card className="p-6 border-slate-200/90 shadow-md space-y-4 flex flex-col justify-between">
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Flame className="w-5 h-5 text-orange-500 fill-orange-500" />
                <h3 className="text-sm font-bold text-slate-900 uppercase tracking-wider">
                  7 kun ketma-ket!
                </h3>
              </div>
              <span className="text-xs font-extrabold text-orange-600 bg-orange-50 px-2 py-0.5 rounded-full border border-orange-200">
                +50 XP
              </span>
            </div>

            {/* Streak day pills */}
            <div className="grid grid-cols-7 gap-1 pt-1">
              {streakDays.map((day, i) => (
                <div
                  key={day}
                  className={`flex flex-col items-center justify-center p-2 rounded-xl text-xs font-bold ${
                    i <= todayIdx
                      ? 'bg-orange-500 text-white shadow-xs'
                      : 'bg-slate-100 text-slate-400'
                  }`}
                >
                  <span className="text-[10px]">{day}</span>
                  <Flame className={`w-3.5 h-3.5 mt-0.5 ${i <= todayIdx ? 'fill-white' : 'text-slate-300'}`} />
                </div>
              ))}
            </div>
          </div>

          {/* Badges Grid */}
          <div className="space-y-2 pt-2 border-t border-slate-100">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider block">
              Yutuqlar:
            </span>
            <div className="grid grid-cols-2 gap-2">
              {achievements.map((ach) => (
                <div
                  key={ach.id}
                  className="flex items-center gap-2 p-2 rounded-xl bg-slate-50 border border-slate-200 text-xs font-bold text-slate-800"
                >
                  <span className="text-base">{ach.icon}</span>
                  <span className="truncate">{ach.title}</span>
                </div>
              ))}
            </div>
          </div>
        </Card>
      </div>

      {/* Infographic 3 Step 16: Spaced Repetition (Adaptiv takrorlash tizimi) & Targeted exercises */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Targeted exercises matching Infographic 3 Step 16 */}
        <Card className="p-6 border-slate-200/90 shadow-md space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Target className="w-5 h-5 text-blue-600" />
              <h3 className="text-base font-bold text-slate-900">
                Siz uchun tavsiya etilgan mashqlar
              </h3>
            </div>
            <span className="text-xs font-bold text-blue-600 bg-blue-50 px-2.5 py-1 rounded-full border border-blue-200">
              Adaptiv Reja
            </span>
          </div>

          <div className="space-y-3">
            <div className="p-3.5 rounded-2xl bg-rose-50/80 border border-rose-200 flex items-center justify-between">
              <div>
                <span className="text-[10px] font-extrabold uppercase px-1.5 py-0.5 rounded bg-rose-200 text-rose-900">
                  1. Zaif mavzu
                </span>
                <h4 className="text-sm font-bold text-slate-900 mt-1">Tenglamalar</h4>
                <p className="text-xs text-slate-600">Qo‘shimcha 5 ta mashq</p>
              </div>
              <Button variant="primary" size="sm" onClick={onContinueLesson}>
                Boshlash
              </Button>
            </div>

            <div className="p-3.5 rounded-2xl bg-blue-50/80 border border-blue-200 flex items-center justify-between">
              <div>
                <span className="text-[10px] font-extrabold uppercase px-1.5 py-0.5 rounded bg-blue-200 text-blue-900">
                  2. Aralash mashq
                </span>
                <h4 className="text-sm font-bold text-slate-900 mt-1">Algebra & Funksiyalar</h4>
                <p className="text-xs text-slate-600">Nazariya + 10 ta test</p>
              </div>
              <Button variant="outline" size="sm" onClick={onContinueLesson}>
                Boshlash
              </Button>
            </div>

            <div className="p-3.5 rounded-2xl bg-emerald-50/80 border border-emerald-200 flex items-center justify-between">
              <div>
                <span className="text-[10px] font-extrabold uppercase px-1.5 py-0.5 rounded bg-emerald-200 text-emerald-900">
                  3. Real hayotiy masala
                </span>
                <h4 className="text-sm font-bold text-slate-900 mt-1">Amaliy topshiriq</h4>
                <p className="text-xs text-slate-600">Amaliy hisob-kitoblar</p>
              </div>
              <Button variant="outline" size="sm" onClick={onContinueLesson}>
                Boshlash
              </Button>
            </div>
          </div>
        </Card>

        {/* Ebbinghaus Forgetting Curve Retention System matching Infographic 3 Step 16 */}
        <Card className="p-6 border-slate-200/90 shadow-md space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Brain className="w-5 h-5 text-indigo-600" />
              <h3 className="text-base font-bold text-slate-900">
                Adaptiv takrorlash tizimi
              </h3>
            </div>
            <span className="text-xs font-bold text-indigo-600 bg-indigo-50 px-2 py-0.5 rounded-full border border-indigo-200">
              Ebbinghaus modeli
            </span>
          </div>

          <p className="text-xs text-slate-600">
            AI sizning xotirangizga mos ravishda takrorlash vaqtini belgilaydi va bilimlarni uzoq muddat saqlaydi.
          </p>

          {/* Retention Chart visualization */}
          <div className="p-4 bg-slate-900 text-white rounded-2xl space-y-3">
            <div className="flex items-center justify-between text-xs font-bold text-slate-300">
              <span>Eslab qolish darajasi</span>
              <span className="text-teal-400">BilimYo‘l: 85%+</span>
            </div>

            {/* Retention intervals */}
            <div className="grid grid-cols-5 gap-2 text-center pt-1">
              {[
                { time: '1 kun', bilimyol: '100%', normal: '80%' },
                { time: '3 kun', bilimyol: '95%', normal: '60%' },
                { time: '7 kun', bilimyol: '90%', normal: '40%' },
                { time: '14 kun', bilimyol: '85%', normal: '25%' },
                { time: '30 kun', bilimyol: '80%', normal: '15%' },
              ].map((slot) => (
                <div key={slot.time} className="p-2 rounded-xl bg-slate-800 border border-slate-700/80">
                  <div className="text-[10px] text-slate-400 font-bold">{slot.time}</div>
                  <div className="text-xs font-black text-teal-400 mt-1">{slot.bilimyol}</div>
                  <div className="text-[9px] text-rose-400 line-through mt-0.5">{slot.normal}</div>
                </div>
              ))}
            </div>

            <div className="pt-2 border-t border-slate-800 flex items-center justify-between text-[11px] text-slate-400">
              <span className="flex items-center gap-1.5">
                <span className="w-2.5 h-2.5 rounded-full bg-teal-400 inline-block" />
                BilimYo‘l (adaptiv takrorlash)
              </span>
              <span className="flex items-center gap-1.5">
                <span className="w-2.5 h-2.5 rounded-full bg-rose-400 inline-block" />
                Oddiy takrorlash
              </span>
            </div>
          </div>
        </Card>
      </div>

      {/* Recent Performance Audit Section */}
      {recentAttempts.length > 0 && (
        <Card className="p-5 border-slate-200 space-y-3">
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-bold text-slate-800 uppercase tracking-wider">
              Oxirgi 5 ta savol natijasi (Server-side Audit)
            </h3>
            <span className="text-xs text-slate-400">PostgreSQL RPC natijasi</span>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            {recentAttempts.map((att, i) => (
              <div
                key={att.id || i}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl border text-xs font-bold ${
                  att.isCorrect
                    ? 'bg-emerald-50 text-emerald-700 border-emerald-200'
                    : 'bg-rose-50 text-rose-700 border-rose-200'
                }`}
                title={`Savol: ${att.questionId}`}
              >
                {att.isCorrect ? (
                  <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" />
                ) : (
                  <XCircle className="w-3.5 h-3.5 text-rose-600" />
                )}
                <span>{att.isCorrect ? 'To‘g‘ri' : 'Xato'}</span>
              </div>
            ))}
          </div>
        </Card>
      )}

      {/* Next Action Journey Card */}
      <Card className="p-8 bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900 text-white rounded-3xl shadow-xl border-0">
        <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-6">
          <div className="space-y-3">
            <div className="flex items-center gap-2">
              <span className="px-2.5 py-1 rounded-md bg-blue-500/20 text-blue-400 border border-blue-500/30 text-xs font-bold uppercase tracking-wider">
                Shaxsiy Yo‘l Xaritasi
              </span>
              <span className="text-xs font-medium text-slate-400">
                {activeCourse?.title || 'Matematika'}
              </span>
            </div>

            <h3 className="text-2xl sm:text-3xl font-extrabold text-white">
              O‘quv yo‘lingizni davom ettirishga tayyormisiz?
            </h3>
            <p className="text-slate-300 text-sm max-w-xl leading-relaxed">
              Yo‘lchi AI va server-side scoring tizimi orqali keyingi eng samarali mikro-darsingiz shakllantirildi.
            </p>
          </div>

          <div className="flex flex-col sm:flex-row items-center gap-3 w-full md:w-auto">
            <Button
              variant="outline"
              size="lg"
              onClick={onOpenKnowledgeMap}
              leftIcon={<Compass className="w-4 h-4 text-slate-700" />}
              className="w-full sm:w-auto"
            >
              Bilim Xaritasi
            </Button>

            <Button
              variant="primary"
              size="lg"
              onClick={onContinueLesson}
              rightIcon={<ArrowRight className="w-5 h-5" />}
              className="w-full sm:w-auto shadow-lg shadow-blue-600/30 bg-blue-600 hover:bg-blue-500"
            >
              Darsga o‘tish
            </Button>
          </div>
        </div>
      </Card>

      {/* Platform Info & Reset */}
      <div className="pt-4 border-t border-slate-200 flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-slate-500">
        <div className="flex items-center gap-2">
          <span className="w-2 h-2 rounded-full bg-emerald-500" />
          <span>Real Adaptive Engine: Natijalar real-vaqtda Supabase va Yo‘lchi AI orqali hisoblanadi.</span>
        </div>

        <Button
          variant="outline"
          size="sm"
          onClick={onResetDemo}
          leftIcon={<RotateCcw className="w-3.5 h-3.5 text-slate-600" />}
          className="text-xs border-slate-300 text-slate-700"
        >
          Kursni Qayta Boshlash
        </Button>
      </div>
    </div>
  );
};
