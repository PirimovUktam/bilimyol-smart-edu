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
} from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
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
      weakestSkillName = sk.name;
    }
  });

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
            Assalomu alaykum, {profile?.name || 'O‘quvchi'}!
          </h1>
          <p className="text-sm text-slate-600 mt-1">
            Shaxsiy moslashuvchan ta’lim yo‘lingiz bo‘yicha real ko‘rsatkichlar
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
            <span>{profile?.streakDays || 1} kunlik faoliyat</span>
          </div>
          <span className="text-[11px] text-slate-400 font-medium">Kunlik faollik hisobi</span>
        </Card>
      </div>

      {/* Recent Performance Section */}
      {recentAttempts.length > 0 && (
        <Card className="p-5 border-slate-200 space-y-3">
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-bold text-slate-800 uppercase tracking-wider">
              Oxirgi 5 ta savol natijasi
            </h3>
            <span className="text-xs text-slate-400">Audit jurnali</span>
          </div>
          <div className="flex items-center gap-2">
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
              Yo‘lchi AI va statistik scoring tizimi orqali keyingi eng samarali mikro-darsingiz shakllantirildi.
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
