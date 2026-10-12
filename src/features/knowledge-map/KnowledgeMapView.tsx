import React, { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { Compass, AlertTriangle, ArrowRight, Map, ShieldCheck, Zap } from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { GetKnowledgeMapUseCase, KnowledgeMapData } from '@/domain/usecases/GetKnowledgeMapUseCase';
import { inMemoryCourseRepository } from '@/data/repositories/InMemoryCourseRepository';
import { supabaseLearnerRepository } from '@/data/repositories/SupabaseLearnerRepository';
import { SkillScoringEngine } from '@/domain/personalization/SkillScoringEngine';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';
import { Badge } from '@/presentation/components/Badge';

interface KnowledgeMapViewProps {
  onProceedToRoadmap: () => void;
}

export const KnowledgeMapView: React.FC<KnowledgeMapViewProps> = ({ onProceedToRoadmap }) => {
  const { activeCourse, activeCourseSkills } = useCourseStore();
  const { profile } = useLearnerStore();
  const [mapData, setMapData] = useState<KnowledgeMapData | null>(null);

  useEffect(() => {
    if (activeCourse) {
      const useCase = new GetKnowledgeMapUseCase(inMemoryCourseRepository, supabaseLearnerRepository);
      useCase.execute(activeCourse.id).then(setMapData);
    }
  }, [activeCourse, profile]);

  if (!mapData || !activeCourse) {
    return (
      <div className="min-h-[60vh] flex items-center justify-center">
        <div className="w-12 h-12 border-4 border-cyan-400 border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  const weakest = mapData.weakestSkill;
  const weakestSkillName = weakest
    ? activeCourseSkills.find((s) => s.id === weakest.skillId)?.name || 'Ko‘nikma'
    : 'Ko‘nikma';
  const overallScore = mapData.overallScore;

  return (
    <div className="max-w-5xl mx-auto px-4 py-8 space-y-7 relative">
      {/* Header bar with View Switcher */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-white/10">
        <div>
          <div className="flex items-center gap-2 mb-1.5">
            <Badge variant="cyan" size="sm">
              <Compass className="w-3.5 h-3.5 mr-1" />
              Bilim Xaritasi
            </Badge>
            <span className="text-xs font-semibold text-slate-400">
              {activeCourse.title} • Umumiy holat: {overallScore}%
            </span>
          </div>
          <h1 className="text-2xl sm:text-4xl font-black text-white tracking-tight">
            Bilim Holati va Ko‘nikmalar Xaritasi
          </h1>
          <p className="text-sm text-slate-300 mt-1">
            Diagnostika va darslar asosida aniqlangan bilim matritsangiz
          </p>
        </div>

        {/* View Switcher Toggle Pill */}
        <div className="flex items-center bg-slate-900/90 p-1.5 rounded-2xl border border-white/10 self-start sm:self-auto backdrop-blur-xl">
          <button
            className="flex items-center gap-1.5 px-4 py-2 rounded-xl text-xs font-black bg-gradient-to-r from-cyan-500 to-indigo-600 text-white shadow-md shadow-indigo-600/30 transition-all cursor-default"
          >
            <Compass className="w-3.5 h-3.5 text-white" />
            <span>Bilim xaritasi</span>
          </button>
          <button
            onClick={onProceedToRoadmap}
            className="flex items-center gap-1.5 px-4 py-2 rounded-xl text-xs font-bold text-slate-400 hover:text-white transition-all cursor-pointer"
          >
            <Map className="w-3.5 h-3.5" />
            <span>Roadmap</span>
          </button>
        </div>
      </div>

      {/* Radial Gauge Summary Card */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Gauge card */}
        <Card className="p-6 bg-slate-900/85 border border-white/10 shadow-2xl backdrop-blur-2xl flex flex-col items-center justify-center text-center space-y-3">
          <span className="text-xs font-bold text-slate-400 uppercase tracking-wider">
            Sizning Bilim Holatingiz
          </span>

          <div className="relative w-40 h-40 flex items-center justify-center">
            <svg className="w-full h-full -rotate-90" viewBox="0 0 120 120">
              <circle
                cx="60"
                cy="60"
                r="46"
                fill="none"
                stroke="#1e293b"
                strokeWidth="10"
              />
              <circle
                cx="60"
                cy="60"
                r="46"
                fill="none"
                stroke="url(#mapRingGradDark)"
                strokeWidth="10"
                strokeDasharray="289"
                strokeDashoffset={289 * (1 - overallScore / 100)}
                strokeLinecap="round"
                className="transition-all duration-1000 ease-out"
              />
              <defs>
                <linearGradient id="mapRingGradDark" x1="0" y1="0" x2="1" y2="1">
                  <stop offset="0%" stopColor="#22d3ee" />
                  <stop offset="50%" stopColor="#6366f1" />
                  <stop offset="100%" stopColor="#a855f7" />
                </linearGradient>
              </defs>
            </svg>
            <div className="absolute inset-0 flex flex-col items-center justify-center">
              <span className="text-3xl font-black text-white">{overallScore}%</span>
              <span className="text-[10px] font-black text-cyan-300 uppercase tracking-wider">
                {SkillScoringEngine.getMasteryLabelUz(overallScore)}
              </span>
            </div>
          </div>

          <div className="flex items-center gap-2 text-xs font-semibold text-slate-400 pt-1">
            <span className="w-2.5 h-2.5 rounded-full bg-emerald-400 shadow-[0_0_8px_rgba(16,185,129,0.8)] inline-block" />
            <span className="text-slate-300">Faol diagnostik tahlil</span>
          </div>
        </Card>

        {/* Detailed Breakdown Card */}
        <Card className="p-6 bg-slate-900/85 border border-white/10 shadow-2xl backdrop-blur-2xl md:col-span-2 space-y-4 flex flex-col justify-between">
          <div className="space-y-2">
            <div className="flex items-center gap-2">
              <ShieldCheck className="w-5 h-5 text-cyan-400" />
              <h3 className="text-lg font-black text-white">
                Diagnostika xulosasi va Matritsa
              </h3>
            </div>
            <p className="text-xs sm:text-sm text-slate-300 leading-relaxed font-medium">
              Siz tanlagan <strong className="text-white">{activeCourse.title}</strong> fani bo‘yicha ko‘nikmalaringiz tahlil qilindi.
              Har bir mavzu uchun bilim darajasi va qaysi mavzularda bo‘shliq borligi aniqlandi.
            </p>
          </div>

          <div className="grid grid-cols-3 gap-3 pt-3 border-t border-white/10 text-center">
            <div className="p-3 rounded-2xl bg-emerald-950/80 border border-emerald-500/40 shadow-xs">
              <div className="text-[10px] font-bold text-emerald-300 uppercase">Yaxshi</div>
              <div className="text-xl font-black text-white">6 ta mavzu</div>
            </div>
            <div className="p-3 rounded-2xl bg-amber-950/80 border border-amber-500/40 shadow-xs">
              <div className="text-[10px] font-bold text-amber-300 uppercase">O‘rta</div>
              <div className="text-xl font-black text-white">3 ta mavzu</div>
            </div>
            <div className="p-3 rounded-2xl bg-rose-950/80 border border-rose-500/40 shadow-xs">
              <div className="text-[10px] font-bold text-rose-300 uppercase">Past</div>
              <div className="text-xl font-black text-white">1 ta mavzu</div>
            </div>
          </div>
        </Card>
      </div>

      {/* Weakest Skill Alert Banner */}
      {weakest && weakest.score < 50 && (
        <motion.div
          initial={{ opacity: 0, scale: 0.98 }}
          animate={{ opacity: 1, scale: 1 }}
          className="p-6 bg-rose-950/80 border-2 border-rose-500/50 rounded-3xl shadow-[0_0_30px_rgba(244,63,94,0.25)] backdrop-blur-2xl flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4"
        >
          <div className="flex items-start gap-4">
            <div className="w-12 h-12 rounded-2xl bg-rose-500 text-slate-950 flex items-center justify-center shrink-0 shadow-lg shadow-rose-500/30 font-black">
              <AlertTriangle className="w-6 h-6 animate-pulse" />
            </div>
            <div className="space-y-1">
              <div className="flex items-center gap-2">
                <span className="text-[10px] font-black tracking-wider uppercase px-2.5 py-0.5 rounded-full bg-rose-900 text-rose-200 border border-rose-700">
                  Mustahkamlash talab etiladi
                </span>
                <span className="text-base font-black text-white">
                  {weakestSkillName} ({weakest.score}%)
                </span>
              </div>
              <p className="text-xs sm:text-sm text-slate-300 font-medium">
                Ushbu mavzu bo‘yicha tushunchalar mustahkamlangandan so‘ng keyingi qiyinroq bosqichlar ochiladi.
              </p>
            </div>
          </div>

          <Button
            variant="coral"
            size="md"
            onClick={onProceedToRoadmap}
            rightIcon={<ArrowRight className="w-4 h-4" />}
            className="shrink-0 font-black shadow-lg"
          >
            Yo‘l xaritasiga o‘tish
          </Button>
        </motion.div>
      )}

      {/* Skills Grid */}
      <div className="space-y-4">
        <h3 className="text-lg font-black text-white flex items-center gap-2">
          <Zap className="w-4 h-4 text-cyan-400" />
          <span>Fan ko‘nikmalari reytingi</span>
        </h3>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          {mapData.skills.map((skill) => {
            const skillScore = mapData.scores[skill.id]?.score ?? 0;
            const isWeak = skillScore < 50;
            const isStrong = skillScore >= 80;

            return (
              <Card
                key={skill.id}
                className={`p-5 transition-all backdrop-blur-2xl ${
                  isWeak
                    ? 'border-rose-500/40 bg-slate-900/85'
                    : isStrong
                    ? 'border-emerald-500/40 bg-slate-900/85'
                    : 'border-white/10 bg-slate-900/80 hover:border-cyan-500/40'
                }`}
              >
                <div className="flex items-start justify-between gap-3 mb-2">
                  <div>
                    <h4 className="text-sm sm:text-base font-black text-white">
                      {skill.name}
                    </h4>
                    <p className="text-xs text-slate-400 font-medium mt-0.5">
                      {skill.description || 'Asosiy tushunchalar'}
                    </p>
                  </div>
                  <span
                    className={`text-sm font-black px-2.5 py-1 rounded-xl border ${
                      isWeak
                        ? 'bg-rose-950/80 text-rose-300 border-rose-500/40'
                        : isStrong
                        ? 'bg-emerald-950/80 text-emerald-300 border-emerald-500/40'
                        : 'bg-indigo-950/80 text-cyan-300 border-cyan-500/40'
                    }`}
                  >
                    {skillScore}%
                  </span>
                </div>

                <div className="h-2.5 w-full bg-slate-800 rounded-full overflow-hidden mt-3">
                  <div
                    className={`h-full rounded-full transition-all duration-700 ${
                      isWeak
                        ? 'bg-rose-500 shadow-[0_0_10px_rgba(244,63,94,0.7)]'
                        : isStrong
                        ? 'bg-emerald-400 shadow-[0_0_10px_rgba(16,185,129,0.7)]'
                        : 'bg-gradient-to-r from-cyan-400 to-indigo-500 shadow-[0_0_10px_rgba(6,182,212,0.7)]'
                    }`}
                    style={{ width: `${skillScore}%` }}
                  />
                </div>
              </Card>
            );
          })}
        </div>
      </div>

      {/* Bottom CTA */}
      <div className="pt-4 flex justify-end">
        <Button
          variant="gradient"
          size="lg"
          onClick={onProceedToRoadmap}
          rightIcon={<ArrowRight className="w-5 h-5" />}
          className="shadow-[0_0_30px_rgba(99,102,241,0.4)] font-black"
        >
          Shaxsiy Yo‘l Xaritasiga O‘tish
        </Button>
      </div>
    </div>
  );
};
