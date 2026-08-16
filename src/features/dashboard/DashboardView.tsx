import React, { useEffect } from 'react';
import {
  CheckCircle2,
  TrendingUp,
  Clock,
  Sparkles,
  ArrowRight,
  Flame,
  Bell,
  Map,
  Compass,
  RotateCcw,
} from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';
import { Badge } from '@/presentation/components/Badge';
import { ProgressEngine } from '@/domain/personalization/ProgressEngine';

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
  const { activeCourse } = useCourseStore();
  const { profile } = useLearnerStore();
  const { loadRoadmap } = useRoadmapStore();

  useEffect(() => {
    if (activeCourse) {
      loadRoadmap(activeCourse.id);
    }
  }, [activeCourse, loadRoadmap, profile]);

  const isMath = activeCourse?.subject === 'mathematics';
  const scores = (profile?.scoresByCourse && activeCourse) ? (profile.scoresByCourse[activeCourse.id] || {}) : {};
  const averageMastery = ProgressEngine.calculateCourseMastery(scores) || (isMath ? 63 : 65);

  const focusSkillScore = isMath
    ? (scores['skill_math_functions']?.score ?? 63)
    : (scores['skill_eng_listening']?.score ?? 65);

  const nextNodeTitle = isMath ? 'Grafiklar' : 'Reading';

  return (
    <div className="max-w-5xl mx-auto px-4 py-8 space-y-8">
      {/* Reminder Banner Simulation */}
      <div className="p-4 rounded-2xl bg-gradient-to-r from-blue-600 to-indigo-600 text-white shadow-md flex items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-white/20 flex items-center justify-center shrink-0">
            <Bell className="w-5 h-5 animate-pulse" />
          </div>
          <div>
            <h4 className="font-bold text-sm">Bugungi o‘quv rejangiz tayyor!</h4>
            <p className="text-xs text-blue-100">
              {activeCourse?.title} • {profile?.dailyMinutes || 15} daqiqa ajrating va ko‘nikmalaringizni mustahkamlang.
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
              Intelligence Loop Bajarildi
            </Badge>
            <span className="text-xs font-semibold text-slate-500">
              {activeCourse?.title}
            </span>
          </div>
          <h1 className="text-2xl sm:text-3xl font-extrabold text-slate-900 tracking-tight">
            Assalomu alaykum, {profile?.name || 'O‘quvchi'}!
          </h1>
          <p className="text-sm text-slate-600 mt-1">
            Siz muvaffaqiyatli adaptatsiya va mustahkamlash bosqichidan o‘tdingiz.
          </p>
        </div>

        <div className="flex items-center gap-3">
          <Button
            variant="outline"
            size="md"
            onClick={onOpenRoadmap}
            leftIcon={<Map className="w-4 h-4 text-blue-600" />}
          >
            Yo‘l Xaritasi
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
        {/* Stat 1: Subject Progress */}
        <Card className="p-5 border-slate-200/90 shadow-xs space-y-2">
          <div className="flex items-center justify-between text-slate-500 text-xs font-bold uppercase tracking-wider">
            <span>Umumiy O‘zlashtirish</span>
            <TrendingUp className="w-4 h-4 text-blue-600" />
          </div>
          <div className="text-3xl font-black text-slate-900">{averageMastery}%</div>
          <div className="h-1.5 w-full bg-slate-100 rounded-full overflow-hidden">
            <div className="h-full bg-blue-600 rounded-full" style={{ width: `${averageMastery}%` }} />
          </div>
        </Card>

        {/* Stat 2: Current Focus Skill */}
        <Card className="p-5 border-slate-200/90 shadow-xs space-y-2">
          <div className="flex items-center justify-between text-slate-500 text-xs font-bold uppercase tracking-wider">
            <span>Joriy Fokus Ko‘nikmasi</span>
            <Sparkles className="w-4 h-4 text-teal-600" />
          </div>
          <div className="text-xl font-bold text-slate-900 truncate">
            {isMath ? 'Funksiyalar' : 'Listening'}
          </div>
          <div className="text-xs font-bold text-teal-700 flex items-center gap-1">
            <span>{focusSkillScore}%</span>
            <span className="text-[10px] text-emerald-600 font-extrabold bg-emerald-50 px-1.5 py-0.5 rounded border border-emerald-200">
              +22% o‘sdi
            </span>
          </div>
        </Card>

        {/* Stat 3: Daily Commitment */}
        <Card className="p-5 border-slate-200/90 shadow-xs space-y-2">
          <div className="flex items-center justify-between text-slate-500 text-xs font-bold uppercase tracking-wider">
            <span>Bugungi Dars Vaqti</span>
            <Clock className="w-4 h-4 text-amber-500" />
          </div>
          <div className="text-3xl font-black text-slate-900">
            {profile?.dailyMinutes || 15} daqiqa
          </div>
          <span className="text-xs text-slate-500">Muntazam kunlik reja</span>
        </Card>

        {/* Stat 4: Gamification XP & Streak */}
        <Card className="p-5 border-slate-200/90 shadow-xs space-y-2">
          <div className="flex items-center justify-between text-slate-500 text-xs font-bold uppercase tracking-wider">
            <span>XP va Streak</span>
            <Flame className="w-4 h-4 text-orange-500 fill-orange-500" />
          </div>
          <div className="text-3xl font-black text-slate-900">
            {profile?.xp || 150} <span className="text-xs font-semibold text-slate-500">XP</span>
          </div>
          <div className="text-xs font-bold text-orange-600 flex items-center gap-1">
            <span>{profile?.streakDays || 3} kunlik faoliyat</span>
          </div>
        </Card>
      </div>

      {/* Next Action Journey Card */}
      <Card className="p-8 bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900 text-white rounded-3xl shadow-xl border-0">
        <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-6">
          <div className="space-y-3">
            <div className="flex items-center gap-2">
              <span className="px-2.5 py-1 rounded-md bg-blue-500/20 text-blue-400 border border-blue-500/30 text-xs font-bold uppercase tracking-wider">
                Keyingi Bosqich Ochildi
              </span>
              <span className="text-xs font-medium text-slate-400">
                {activeCourse?.title} Yo‘l Xaritasi
              </span>
            </div>

            <h3 className="text-2xl sm:text-3xl font-extrabold text-white">
              {nextNodeTitle} mavzusini o‘rganishga tayyormisiz?
            </h3>
            <p className="text-slate-300 text-sm max-w-xl leading-relaxed">
              Funksiyalar bo‘yicha mustahkamlash yakunlangani sababli, uning asosidagi navbatdagi dars qulfdan ochildi.
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
              Darsni Boshlash
            </Button>
          </div>
        </div>
      </Card>

      {/* Demo Controls Section */}
      <div className="pt-4 border-t border-slate-200 flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-slate-500">
        <div className="flex items-center gap-2">
          <span className="w-2 h-2 rounded-full bg-emerald-500" />
          <span>Checkpoint 1 Core Status: Barcha 14 ta asosiy oqim to‘liq ishladi.</span>
        </div>

        <Button
          variant="outline"
          size="sm"
          onClick={onResetDemo}
          leftIcon={<RotateCcw className="w-3.5 h-3.5 text-amber-600" />}
          className="text-xs border-slate-300 text-slate-700"
        >
          Demonstratsiyani Qayta Boshlash (Demo Reset)
        </Button>
      </div>
    </div>
  );
};
