import React, { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { Compass, AlertTriangle, ArrowRight, Map, ShieldCheck } from 'lucide-react';
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
        <div className="w-10 h-10 border-4 border-indigo-600 border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  const weakest = mapData.weakestSkill;
  const weakestSkillName = weakest
    ? activeCourseSkills.find((s) => s.id === weakest.skillId)?.name || 'Ko‘nikma'
    : 'Ko‘nikma';
  const overallScore = mapData.overallScore;
  const skillBandCounts = mapData.skills.reduce(
    (counts, skill) => {
      const score = mapData.scores[skill.id]?.score ?? 0;
      if (score >= 80) counts.strong += 1;
      else if (score >= 50) counts.medium += 1;
      else counts.weak += 1;
      return counts;
    },
    { strong: 0, medium: 0, weak: 0 }
  );

  return (
    <div className="max-w-5xl mx-auto px-4 py-8 space-y-7">
      {/* Header bar with View Switcher (Reference 2 style) */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-slate-200">
        <div>
          <div className="flex items-center gap-2 mb-1.5">
            <Badge variant="blue" size="sm">
              <Compass className="w-3.5 h-3.5 mr-1" />
              Bilim Xaritasi
            </Badge>
            <span className="text-xs font-semibold text-slate-500">
              {activeCourse.title} • Umumiy holat: {overallScore}%
            </span>
          </div>
          <h1 className="text-2xl sm:text-3xl font-black text-slate-900 tracking-tight">
            Bilim Holati va Ko‘nikmalar Xaritasi
          </h1>
          <p className="text-sm text-slate-600 mt-1">
            Diagnostika va darslar asosida aniqlangan bilim xaritangiz
          </p>
        </div>

        {/* View Switcher Toggle Pill */}
        <div className="flex items-center bg-slate-100 p-1.5 rounded-2xl border border-slate-200 self-start sm:self-auto">
          <button
            className="flex items-center gap-1.5 px-4 py-2 rounded-xl text-xs font-bold bg-white text-indigo-700 shadow-xs transition-all cursor-default"
          >
            <Compass className="w-3.5 h-3.5 text-indigo-600" />
            <span>Bilim xaritasi</span>
          </button>
          <button
            onClick={onProceedToRoadmap}
            className="flex items-center gap-1.5 px-4 py-2 rounded-xl text-xs font-bold text-slate-600 hover:text-slate-900 transition-all cursor-pointer"
          >
            <Map className="w-3.5 h-3.5" />
            <span>Roadmap</span>
          </button>
        </div>
      </div>

      {/* Radial Gauge Summary Card (Reference 1 Step 4: "Sizning bilim holatingiz: 64%") */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Gauge card */}
        <Card className="p-6 border-slate-200/90 shadow-md flex flex-col items-center justify-center text-center space-y-3">
          <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
            Sizning Bilim Holatingiz
          </span>

          <div className="relative w-36 h-36 flex items-center justify-center">
            <svg className="w-full h-full -rotate-90" viewBox="0 0 120 120">
              <circle
                cx="60"
                cy="60"
                r="46"
                fill="none"
                stroke="#E2E8F0"
                strokeWidth="10"
              />
              <circle
                cx="60"
                cy="60"
                r="46"
                fill="none"
                stroke="url(#mapRingGrad)"
                strokeWidth="10"
                strokeDasharray="289"
                strokeDashoffset={289 * (1 - overallScore / 100)}
                strokeLinecap="round"
                className="transition-all duration-1000 ease-out"
              />
              <defs>
                <linearGradient id="mapRingGrad" x1="0" y1="0" x2="1" y2="1">
                  <stop offset="0%" stopColor="#38BDF8" />
                  <stop offset="50%" stopColor="#4F46E5" />
                  <stop offset="100%" stopColor="#06B6D4" />
                </linearGradient>
              </defs>
            </svg>
            <div className="absolute inset-0 flex flex-col items-center justify-center">
              <span className="text-3xl font-black text-slate-900">{overallScore}%</span>
              <span className="text-[10px] font-bold text-emerald-600 uppercase">
                {SkillScoringEngine.getMasteryLabelUz(overallScore)}
              </span>
            </div>
          </div>

          <div className="flex items-center gap-2 text-xs font-semibold text-slate-500 pt-1">
            <span className="w-2.5 h-2.5 rounded-full bg-emerald-500 inline-block" />
            <span>Yaxshi o‘zlashtirish</span>
          </div>
        </Card>

        {/* Detailed Breakdown Card */}
        <Card className="p-6 border-slate-200/90 shadow-md md:col-span-2 space-y-4 flex flex-col justify-between">
          <div className="space-y-2">
            <div className="flex items-center gap-2">
              <ShieldCheck className="w-5 h-5 text-indigo-600" />
              <h3 className="text-base font-extrabold text-slate-900">
                Diagnostika xulosasi
              </h3>
            </div>
            <p className="text-xs sm:text-sm text-slate-600 leading-relaxed font-medium">
              Siz tanlagan <strong>{activeCourse.title}</strong> fani bo‘yicha ko‘nikmalaringiz tahlil qilindi.
              Har bir mavzu uchun bilim darajasi va qaysi mavzularda bo‘shliq borligi aniqlandi.
            </p>
          </div>

          <div className="grid grid-cols-3 gap-2 pt-2 border-t border-slate-100 text-center">
            <div className="p-2.5 rounded-xl bg-emerald-50 border border-emerald-200">
              <div className="text-[10px] font-bold text-emerald-800 uppercase">Yaxshi</div>
              <div className="text-lg font-black text-emerald-900">{skillBandCounts.strong} ta mavzu</div>
            </div>
            <div className="p-2.5 rounded-xl bg-amber-50 border border-amber-200">
              <div className="text-[10px] font-bold text-amber-800 uppercase">O‘rta</div>
              <div className="text-lg font-black text-amber-900">{skillBandCounts.medium} ta mavzu</div>
            </div>
            <div className="p-2.5 rounded-xl bg-rose-50 border border-rose-200">
              <div className="text-[10px] font-bold text-rose-800 uppercase">Past</div>
              <div className="text-lg font-black text-rose-900">{skillBandCounts.weak} ta mavzu</div>
            </div>
          </div>
        </Card>
      </div>

      {/* Weakest Skill Alert Banner */}
      {weakest && weakest.score < 50 && (
        <motion.div
          initial={{ opacity: 0, scale: 0.98 }}
          animate={{ opacity: 1, scale: 1 }}
          className="p-5 sm:p-6 bg-gradient-to-r from-rose-50 via-amber-50 to-orange-50 border-2 border-rose-300 rounded-3xl shadow-sm flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4"
        >
          <div className="flex items-start gap-4">
            <div className="w-12 h-12 rounded-2xl bg-rose-500 text-white flex items-center justify-center shrink-0 shadow-md shadow-rose-500/20">
              <AlertTriangle className="w-6 h-6 animate-pulse" />
            </div>
            <div className="space-y-1">
              <div className="flex items-center gap-2">
                <span className="text-[10px] font-black tracking-wider uppercase px-2 py-0.5 rounded bg-rose-200 text-rose-900">
                  Mustahkamlash talab etiladi
                </span>
                <span className="text-sm font-black text-rose-950">
                  {weakestSkillName} ({weakest.score}%)
                </span>
              </div>
              <p className="text-xs sm:text-sm text-rose-900/90 font-medium">
                Ushbu mavzu bo‘yicha tushunchalar mustahkamlangandan so‘ng keyingi qiyinroq bosqichlar ochiladi.
              </p>
            </div>
          </div>

          <Button
            variant="coral"
            size="md"
            onClick={onProceedToRoadmap}
            rightIcon={<ArrowRight className="w-4 h-4" />}
            className="shrink-0 font-extrabold"
          >
            Yo‘l xaritasiga o‘tish
          </Button>
        </motion.div>
      )}

      {/* Skills Grid */}
      <div className="space-y-3">
        <h3 className="text-base font-extrabold text-slate-900">
          Fan ko‘nikmalari reytingi
        </h3>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          {mapData.skills.map((skill) => {
            const skillScore = mapData.scores[skill.id]?.score ?? 0;
            const isWeak = skillScore < 50;
            const isStrong = skillScore >= 80;

            return (
              <Card
                key={skill.id}
                className={`p-5 transition-all ${
                  isWeak
                    ? 'border-rose-200 bg-rose-50/30'
                    : isStrong
                    ? 'border-emerald-200 bg-emerald-50/20'
                    : 'border-slate-200 bg-white'
                }`}
              >
                <div className="flex items-start justify-between gap-3 mb-2">
                  <div>
                    <h4 className="text-sm font-extrabold text-slate-900">
                      {skill.name}
                    </h4>
                    <p className="text-xs text-slate-500 font-medium">
                      {skill.description || 'Asosiy tushunchalar'}
                    </p>
                  </div>
                  <span
                    className={`text-base font-black px-2.5 py-0.5 rounded-xl border ${
                      isWeak
                        ? 'bg-rose-100 text-rose-800 border-rose-200'
                        : isStrong
                        ? 'bg-emerald-100 text-emerald-800 border-emerald-200'
                        : 'bg-indigo-50 text-indigo-800 border-indigo-200'
                    }`}
                  >
                    {skillScore}%
                  </span>
                </div>

                <div className="h-2 w-full bg-slate-100 rounded-full overflow-hidden mt-3">
                  <div
                    className={`h-full rounded-full ${
                      isWeak
                        ? 'bg-rose-500'
                        : isStrong
                        ? 'bg-emerald-500'
                        : 'bg-indigo-600'
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
          className="shadow-lg shadow-indigo-600/30"
        >
          Shaxsiy Yo‘l Xaritasiga O‘tish
        </Button>
      </div>
    </div>
  );
};
